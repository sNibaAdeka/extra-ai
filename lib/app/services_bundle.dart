import 'package:hive_flutter/hive_flutter.dart';

import '../services/azure_openai_client.dart';
import '../services/favorites_service.dart';
import '../services/gemini_service.dart';
import '../services/health_check_service.dart';
import '../services/history_service.dart';
import '../services/knowledge_base_service.dart';
import '../services/notifications_service.dart';
import '../services/profile_service.dart';
import '../services/project_context_service.dart';
import '../services/settings_service.dart';
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
    required String azureEndpoint,
    required String azureKey,
    required String azureDeployment,
    required bool demoFallbackEnabled,
  }) async {
    // User-scoped boxes: suffixing the box name isolates each account's data
    // on the device (per the auth prompt — data is scoped to the user id, not
    // global). Falls back to a shared box name when userId is empty.
    String scoped(String base) => userId.isEmpty ? base : '${base}_$userId';

    final profileBox = await Hive.openBox(scoped(ProfileService.boxName));
    final projectBox =
        await Hive.openBox(scoped(ProjectContextService.boxName));
    final historyBox = await Hive.openBox(scoped(HiveHistoryStore.boxName));
    final settingsBox = await Hive.openBox(scoped(SettingsService.boxName));
    final notificationsBox =
        await Hive.openBox(scoped(NotificationsService.boxName));
    final favoritesBox = await Hive.openBox(scoped(FavoritesService.boxName));
    final bindingsBox =
        await Hive.openBox(scoped(TemplateBindingsService.boxName));

    await KnowledgeBaseService.loadAll();

    final geminiModel = GeminiPromptModel(apiKey: geminiApiKey);
    final critic = AzureOpenAIClient(
      endpoint: azureEndpoint,
      apiKey: azureKey,
      deployment: azureDeployment,
    );
    final notifications = NotificationsService(notificationsBox);
    await notifications.seedIfNeeded();

    final state = AppState(
      profileService: ProfileService(profileBox),
      projectService: ProjectContextService(projectBox),
      historyService: HistoryService(store: HiveHistoryStore(historyBox)),
      geminiService: GeminiService(model: geminiModel),
      verificationService: VerificationService(critic: critic),
      healthCheckService: HealthCheckService(
        generatorProbe: geminiApiKey.isEmpty ? null : geminiModel.healthCheck,
        criticProbe: critic.isConfigured ? critic.healthCheck : null,
      ),
      demoFallbackEnabled: demoFallbackEnabled,
      settings: SettingsService(settingsBox),
      notifications: notifications,
      favorites: FavoritesService(favoritesBox),
      templateBindings: TemplateBindingsService(bindingsBox),
    );

    return AppServices._(state);
  }
}
