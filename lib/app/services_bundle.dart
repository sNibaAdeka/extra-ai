import 'package:hive_flutter/hive_flutter.dart';

import '../models/prompt_history_entry.dart';
import '../models/user_profile.dart';
import '../services/azure_openai_client.dart';
import '../services/backend_sync_service.dart';
import '../services/favorites_service.dart';
import '../services/gemini_service.dart';
import '../services/health_check_service.dart';
import '../services/history_service.dart';
import '../services/knowledge_base_service.dart';
import '../services/mock_prompt_model.dart';
import '../services/notifications_service.dart';
import '../services/profile_service.dart';
import '../services/project_context_service.dart';
import '../services/settings_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_outbox_service.dart';
import '../services/template_bindings_service.dart';
import '../services/verification_service.dart';
import 'app_state.dart';

/// Builds an [AppState] with all per-user services wired, opening Hive boxes
/// scoped to [userId]. Shared by both window entrypoints so the overlay and
/// the main app operate on the same user's data.
///
/// Pass `demoFallbackEnabled` / credentials through from --dart-define.
class AppServices {
  AppServices._(this.state);

  final AppState state;

  static Future<AppServices> create({
    required String userId,
    required String geminiApiKey,
    required String geminiModelName,
    required String azureEndpoint,
    required String azureKey,
    required String azureDeployment,
    required bool demoFallbackEnabled,
    required bool mockDataEnabled,
    required String mockProjectPath,
  }) async {
    // User-scoped boxes: suffixing the box name isolates each account's data
    // on the device (per the auth prompt — data is scoped to the user id, not
    // global). Falls back to a shared box name when userId is empty.
    String scoped(String base) => userId.isEmpty ? base : '${base}_$userId';

    final profileBox = await Hive.openBox(scoped(ProfileService.boxName));
    final projectBox = await Hive.openBox(
      scoped(ProjectContextService.boxName),
    );
    final historyBox = await Hive.openBox(scoped(HiveHistoryStore.boxName));
    final settingsBox = await Hive.openBox(scoped(SettingsService.boxName));
    final subscriptionBox = await Hive.openBox(
      scoped(LocalSubscriptionService.boxName),
    );
    final syncOutboxBox = await Hive.openBox(
      scoped(LocalSyncOutboxService.boxName),
    );
    final notificationsBox = await Hive.openBox(
      scoped(NotificationsService.boxName),
    );
    final favoritesBox = await Hive.openBox(scoped(FavoritesService.boxName));
    final bindingsBox = await Hive.openBox(
      scoped(TemplateBindingsService.boxName),
    );

    await KnowledgeBaseService.loadAll();

    final PromptModel promptModel;
    HealthProbe? generatorProbe;
    if (mockDataEnabled) {
      promptModel = const MockPromptModel();
      generatorProbe = () async => true;
    } else {
      final geminiModel = GeminiPromptModel(
        apiKey: geminiApiKey,
        modelName: geminiModelName,
      );
      promptModel = geminiModel;
      generatorProbe = geminiApiKey.isEmpty ? null : geminiModel.healthCheck;
    }
    final critic = AzureOpenAIClient(
      endpoint: azureEndpoint,
      apiKey: azureKey,
      deployment: azureDeployment,
    );
    final notifications = NotificationsService(notificationsBox);
    await notifications.seedIfNeeded();
    final profiles = ProfileService(profileBox);
    final projects = ProjectContextService(projectBox);
    final history = HistoryService(store: HiveHistoryStore(historyBox));
    final settings = SettingsService(settingsBox);
    final subscription = LocalSubscriptionService(subscriptionBox);
    final syncOutbox = LocalSyncOutboxService(syncOutboxBox);
    const backendSync = LocalBackendSyncService();
    if (mockDataEnabled) {
      await _seedMockData(
        profiles: profiles,
        projects: projects,
        history: history,
        settings: settings,
        projectPath: mockProjectPath,
      );
    }

    final state = AppState(
      profileService: profiles,
      projectService: projects,
      historyService: history,
      geminiService: GeminiService(
        model: promptModel,
        modelLabel: mockDataEnabled ? 'Mock local model' : geminiModelName,
      ),
      verificationService: VerificationService(critic: critic),
      healthCheckService: HealthCheckService(
        generatorProbe: generatorProbe,
        criticProbe: critic.isConfigured ? critic.healthCheck : null,
      ),
      demoFallbackEnabled: demoFallbackEnabled,
      settings: settings,
      subscription: subscription,
      backendSync: backendSync,
      syncOutbox: syncOutbox,
      notifications: notifications,
      favorites: FavoritesService(favoritesBox),
      templateBindings: TemplateBindingsService(bindingsBox),
    );

    return AppServices._(state);
  }

  static Future<void> _seedMockData({
    required ProfileService profiles,
    required ProjectContextService projects,
    required HistoryService history,
    required SettingsService settings,
    required String projectPath,
  }) async {
    final now = DateTime.now();
    if (!profiles.hasProfile) {
      await profiles.save(
        UserProfile(
          experienceLevel: ExperienceLevel.promptFirst,
          primaryTools: const ['Codex', 'Cursor', 'Claude Code'],
          projectFocus: ProjectFocus.saas,
          tonePreference: ToneLevel.explained,
          createdAt: now,
        ),
      );
    }

    await settings.setLinkingComplete(true);
    if (settings.firstName.isEmpty && settings.lastName.isEmpty) {
      await settings.setName('Extra', 'AI');
    }

    final linked = await projects.link(
      projectPath: projectPath,
      detectedStack: 'Flutter + macOS',
      fileNames: const [
        'lib/features/prompt_input.dart',
        'lib/app/overlay_window_app.dart',
        'macos/Runner/MainFlutterWindow.swift',
      ],
      atOnboarding: true,
    );
    await settings.setSelectedProjectHash(linked.pathHash);

    if (history.allFor(linked.pathHash).isNotEmpty) return;
    await history.add(
      PromptHistoryEntry(
        projectPathHash: linked.pathHash,
        roughPrompt: 'убери черный квадрат у overlay',
        improvedPrompt:
            'In @macos/Runner/MainFlutterWindow.swift, make the overlay '
            'sub-window transparent by setting FlutterViewController '
            'backgroundColor and the NSWindow background to clear.',
        issuesFound: const [
          'FlutterViewController defaults to a black background if not cleared.',
        ],
        timestamp: now.subtract(const Duration(days: 2)),
      ),
    );
    await history.add(
      PromptHistoryEntry(
        projectPathHash: linked.pathHash,
        roughPrompt: 'сделай мини чат меньше',
        improvedPrompt:
            'In @lib/features/prompt_input.dart, reduce composer width and '
            'icon sizing while keeping the Extra AI dark glass style.',
        issuesFound: const [
          'Overlay controls can feel oversized on laptop screens.',
        ],
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
    );
  }
}
