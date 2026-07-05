import 'package:flutter/foundation.dart';

import '../models/analysis_trace.dart';
import '../models/analysis_preferences.dart';
import '../models/backend_sync_state.dart';
import '../models/extra_ai_response.dart';
import '../models/project_context.dart';
import '../models/project_audit_report.dart';
import '../models/project_intelligence.dart';
import '../models/product_health_report.dart';
import '../models/prompt_history_entry.dart';
import '../models/response_quality_report.dart';
import '../models/subscription_state.dart';
import '../models/sync_outbox_event.dart';
import '../models/user_profile.dart';
import '../security/rate_limiter.dart';
import '../security/request_validator.dart';
import '../services/demo_fallback.dart';
import '../services/extra_ai_request_builder.dart';
import '../services/favorites_service.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/health_check_service.dart';
import '../services/history_service.dart';
import '../services/notifications_service.dart';
import '../services/profile_service.dart';
import '../services/project_detection_service.dart';
import '../services/project_context_service.dart';
import '../services/project_audit_service.dart';
import '../services/product_health_service.dart';
import '../services/project_intelligence_service.dart';
import '../services/response_quality_service.dart';
import '../services/response_freshness_service.dart';
import '../services/settings_service.dart';
import '../services/backend_sync_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_outbox_service.dart';
import '../services/template_bindings_service.dart';
import '../services/verification_service.dart';
import '../understanding/error_messages.dart';
import '../understanding/frustration_detector.dart';

/// Which surface the overlay is showing: the compact analysis window
/// (input/loading/results), the large app shell (home), or onboarding.
enum OverlayView { onboarding, home, input, loading, results }

/// Sidebar sections inside the app shell.
enum ShellSection { home, history, templates }

/// Settings modal tabs (Screens 8–13).
enum SettingsTab { general, shortcuts, profile, plans, privacy, updates }

/// How the current result relates to the two-model quality gate.
enum VerificationStatus {
  /// Critic not configured — verification is off, nothing to report.
  skipped,

  /// The critic checked the draft and it passed as-is.
  verified,

  /// The critic flagged the draft; the corrective pass fixed it.
  corrected,

  /// The critic was unreachable or the corrective pass failed — the best
  /// available draft is shown with an honest note, never blocked.
  unavailable,

  /// DEMO-ONLY pre-recorded response (see demo_fallback.dart).
  demoFallback,
}

/// Central app state + orchestrator. Holds the current view, the loaded
/// project, and runs the analyze pipeline end to end:
///   validate → rate-limit → (files already redacted) → build context →
///   Gemini → validate response → persist history → show results.
///
/// UI-agnostic and window-agnostic: window show/hide is delegated so this is
/// unit-testable without a real macOS window.
class AppState extends ChangeNotifier {
  AppState({
    required ProfileService profileService,
    required ProjectContextService projectService,
    required HistoryService historyService,
    required GeminiService geminiService,
    VerificationService? verificationService,
    HealthCheckService? healthCheckService,
    RateLimiter? rateLimiter,
    bool demoFallbackEnabled = false,
    this.settings,
    SubscriptionGateway? subscription,
    BackendSyncGateway? backendSync,
    SyncOutboxGateway? syncOutbox,
    this.notifications,
    this.favorites,
    this.templateBindings,
  }) : _profiles = profileService,
       _projects = projectService,
       _history = historyService,
       _gemini = geminiService,
       _verifier = verificationService,
       _healthChecker = healthCheckService,
       // ignore: prefer_initializing_formals
       _subscription = subscription,
       // ignore: prefer_initializing_formals
       _backendSync = backendSync,
       // ignore: prefer_initializing_formals
       _syncOutbox = syncOutbox,
       _rateLimiter = rateLimiter ?? RateLimiter(),
       // ignore: prefer_initializing_formals
       _demoFallbackEnabled = demoFallbackEnabled {
    _view = _profiles.hasProfile ? OverlayView.input : OverlayView.onboarding;
  }

  final ProfileService _profiles;
  final ProjectContextService _projects;
  final HistoryService _history;
  final GeminiService _gemini;
  final VerificationService? _verifier;
  final HealthCheckService? _healthChecker;
  final SubscriptionGateway? _subscription;
  final BackendSyncGateway? _backendSync;
  final SyncOutboxGateway? _syncOutbox;
  final RateLimiter _rateLimiter;

  /// Shell-surface services (dashboard/history/templates/settings). Nullable
  /// so the compact analysis flow stays constructible in isolation.
  final SettingsService? settings;
  final NotificationsService? notifications;
  final FavoritesService? favorites;
  final TemplateBindingsService? templateBindings;

  HistoryService get history => _history;
  ProfileService get profiles => _profiles;
  ProjectContextService get projectService => _projects;

  SubscriptionState get subscriptionState {
    final gateway = _subscription;
    if (gateway == null) {
      return SubscriptionState(
        tier: PlanTier.free,
        usageThisMonth: _profiles.usageThisMonth,
      );
    }
    return gateway.current(usageThisMonth: _profiles.usageThisMonth);
  }

  BackendSyncState _backendSyncState = BackendSyncState(
    mode: BackendSyncMode.localOnly,
    lastCheckedAt: DateTime.fromMillisecondsSinceEpoch(0),
    adaptersReady: const [],
  );
  BackendSyncState get backendSyncState => _backendSyncState;
  SyncOutboxSummary get syncOutboxSummary =>
      _syncOutbox?.summary() ??
      const SyncOutboxSummary(pending: 0, flushed: 0, failed: 0);

  Future<void> refreshBackendSync() async {
    final gateway = _backendSync;
    if (gateway == null) return;
    _backendSyncState = await gateway.status(syncOutboxSummary);
    notifyListeners();
  }

  Future<void> selectPlan(PlanTier tier) async {
    await _subscription?.selectPlan(tier);
    await _enqueueSyncEvent(SyncEventType.planChanged, {
      'tier': tier.name,
      'usageThisMonth': _profiles.usageThisMonth,
    });
    await refreshBackendSync();
    notifyListeners();
  }

  /// Redeems a promo code (e.g. AD2011AD for unlimited admin mode). Returns the
  /// redemption result so the UI can show success/failure inline.
  Future<PromoRedemption> redeemPromoCode(String code) async {
    final gateway = _subscription;
    if (gateway == null) return PromoRedemption.invalid;
    final result = await gateway.redeemPromoCode(code);
    if (result.accepted && result.tier != null) {
      await _enqueueSyncEvent(SyncEventType.planChanged, {
        'tier': result.tier!.name,
        'usageThisMonth': _profiles.usageThisMonth,
        'promo': PromoCodes.normalize(code),
      });
      await refreshBackendSync();
    }
    notifyListeners();
    return result;
  }

  Future<void> _enqueueSyncEvent(
    SyncEventType type,
    Map<String, dynamic> payload,
  ) async {
    await _syncOutbox?.enqueue(type, payload);
  }

  Future<int> flushSyncOutbox() async {
    final count = await _syncOutbox?.flushPending() ?? 0;
    await refreshBackendSync();
    notifyListeners();
    return count;
  }

  /// DEMO-ONLY: see demo_fallback.dart. Off in all normal builds.
  final bool _demoFallbackEnabled;

  // ---- View state -----------------------------------------------------------
  late OverlayView _view;
  OverlayView get view => _view;

  ShellSection _shellSection = ShellSection.home;
  ShellSection get shellSection => _shellSection;

  bool _settingsOpen = false;
  bool get settingsOpen => _settingsOpen;
  SettingsTab _settingsTab = SettingsTab.general;
  SettingsTab get settingsTab => _settingsTab;

  /// Rough prompt pre-filled into the input view (quick-template hotkeys).
  String? _prefillPrompt;
  String? _lastRoughPrompt;
  String? get prefillPrompt => _prefillPrompt;

  void markPrefillPromptApplied() {
    if (_prefillPrompt == null) return;
    _prefillPrompt = null;
    notifyListeners();
  }

  String? takePrefillPrompt() {
    final p = _prefillPrompt;
    _prefillPrompt = null;
    return p;
  }

  // ---- Loaded project -------------------------------------------------------
  LoadedProject? _project;
  LoadedProject? get project => _project;
  ProjectIntelligence? _projectIntelligence;
  ProjectIntelligence? get projectIntelligence => _projectIntelligence;
  int get fileCount => _project?.fileNames.length ?? 0;

  /// Raw (unredacted) map is used only to detect the stack + build context; it
  /// never leaves the device — the request uses the redacted concatenation.
  Map<String, String> _rawFiles = const {};
  String _projectPath = 'untitled';

  // ---- Linked projects (overlay picker) -------------------------------------
  /// IPC snapshot pushed by the main window. When present it overrides the
  /// local Hive read — the overlay runs in a separate engine whose Hive box
  /// copy never sees the main window's later writes.
  List<ProjectContext>? _projectsSnapshot;
  String? _selectedHashSnapshot;
  bool _snapshotApplied = false;

  /// Overlay engine: forwards a picker selection to the main window (the
  /// single Hive writer) instead of persisting locally. Null in the main
  /// window, which persists to its own settings box.
  Future<void> Function(String pathHash)? remoteSelectionSink;

  /// Overlay engine: called after an analysis is persisted so the main
  /// window's dashboards can merge the new entry (their Hive instance is a
  /// separate in-memory copy).
  Future<void> Function(PromptHistoryEntry entry)? onAnalysisPersisted;

  /// Main window: wired to [MainFlowController.signOut] at bootstrap so the
  /// settings modal's Sign out button can return the app to the auth gate.
  /// Null in the overlay engine (no auth surface there).
  Future<void> Function()? onSignOut;

  /// All linked projects, for the overlay's "Working on:" picker.
  List<ProjectContext> get linkedProjects =>
      _projectsSnapshot ?? _projects.all();

  /// The project the overlay is currently scoped to (its pathHash), persisted
  /// as the default for next time. Null = none selected.
  String? get selectedProjectHash =>
      _snapshotApplied ? _selectedHashSnapshot : settings?.selectedProjectHash;

  ProjectContext? get selectedProject {
    final hash = selectedProjectHash;
    if (hash == null) return null;
    for (final p in linkedProjects) {
      if (p.pathHash == hash || p.legacyPathHash == hash) return p;
    }
    return null;
  }

  /// Applies the authoritative state pushed/pulled over IPC (overlay engine).
  void applyProjectsSnapshot(
    List<ProjectContext> projects,
    String? selectedHash,
  ) {
    _projectsSnapshot = projects;
    _selectedHashSnapshot = selectedHash;
    _snapshotApplied = true;
    final p = selectedProject;
    if (p != null) _projectPath = p.projectPath;
    _prewarmSelectedProject();
    notifyListeners();
  }

  Future<void> normalizeSelectedProject() async {
    final selected = selectedProject;
    if (selected == null || selectedProjectHash == selected.pathHash) return;
    if (_snapshotApplied) {
      _selectedHashSnapshot = selected.pathHash;
    } else {
      await settings?.setSelectedProjectHash(selected.pathHash);
    }
    notifyListeners();
  }

  void _prewarmSelectedProject() {
    final p = selectedProject;
    if (p == null) return;
    _loadProjectSnapshot(p).then((_) => notifyListeners());
  }

  /// Selects the active project for the overlay and remembers it. In the
  /// overlay engine the write is delegated to the main window over IPC.
  Future<void> selectProject(String pathHash) async {
    final chosen = _projects.getByHash(pathHash);
    final stableHash = chosen?.pathHash ?? pathHash;
    _clearAnalysisArtifacts();
    final sink = remoteSelectionSink;
    if (sink != null) {
      _selectedHashSnapshot = stableHash;
      _snapshotApplied = true;
      await sink(stableHash);
    } else {
      await settings?.setSelectedProjectHash(stableHash);
    }
    final p = selectedProject;
    if (p != null) await _loadProjectSnapshot(p);
    notifyListeners();
  }

  Future<ProjectContext> linkProject(String projectPath) async {
    final linked = await _projects.link(
      projectPath: projectPath,
      fileNames: const [],
      detectedStack: 'Unknown',
    );
    await _enqueueSyncEvent(SyncEventType.projectLinked, {
      'projectPathHash': linked.pathHash,
      'detectedStack': linked.detectedStack,
      'linkedAtOnboarding': linked.linkedAtOnboarding,
    });
    await selectProject(linked.pathHash);
    await refreshBackendSync();
    return linked;
  }

  // ---- External history (entries persisted by the other engine) -------------
  final List<PromptHistoryEntry> _externalEntries = [];

  /// Merge an entry persisted by the overlay engine into this window's view.
  void noteExternalAnalysis(PromptHistoryEntry entry) {
    _externalEntries.add(entry);
    notifyListeners();
  }

  /// Every visible analysis: this engine's Hive box + entries reported over
  /// IPC by the other engine, newest first. Dashboards read this, never the
  /// raw box, so both windows stay consistent within a session.
  List<PromptHistoryEntry> allHistory() {
    final own = _history.allEntries();
    final ownKeys = {
      for (final e in own)
        '${e.projectPathHash}:${e.timestamp.toIso8601String()}',
    };
    final merged = [
      ...own,
      ..._externalEntries.where(
        (e) => !ownKeys.contains(
          '${e.projectPathHash}:${e.timestamp.toIso8601String()}',
        ),
      ),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  /// Imports projects detected from Codex, Claude Code, Cursor, and VS Code into
  /// the local project memory. The app never sends this list anywhere.
  Future<int> syncDetectedProjects() async {
    final detected = await ProjectDetectionService.detectAll();
    ProjectContext? firstLinked;
    for (final project in detected) {
      final linked = await _projects.link(
        projectPath: project.path,
        fileNames: const [],
        detectedStack: project.stack,
        atOnboarding: true,
      );
      await _enqueueSyncEvent(SyncEventType.projectLinked, {
        'projectPathHash': linked.pathHash,
        'detectedStack': linked.detectedStack,
        'linkedAtOnboarding': linked.linkedAtOnboarding,
        'source': project.source,
      });
      firstLinked ??= linked;
    }
    if (selectedProjectHash == null && firstLinked != null) {
      await settings?.setSelectedProjectHash(firstLinked.pathHash);
      await _loadProjectSnapshot(firstLinked);
    }
    notifyListeners();
    await refreshBackendSync();
    return detected.length;
  }

  // ---- Results / errors -----------------------------------------------------
  ExtraAIResponse? _response;
  ExtraAIResponse? get response => _response;
  ResponseQualityReport? _qualityReport;
  ResponseQualityReport? get qualityReport => _qualityReport;
  ProjectAuditReport? _auditReport;
  ProjectAuditReport? get auditReport => _auditReport;
  AnalysisTrace? _analysisTrace;
  AnalysisTrace? get analysisTrace => _analysisTrace;

  VerificationStatus _verification = VerificationStatus.skipped;
  VerificationStatus get verification => _verification;

  // ---- Service health --------------------------------------------------------
  AppHealth _health = const AppHealth();
  AppHealth get health => _health;

  ProductHealthReport get productHealthReport => ProductHealthService.build(
    appHealth: _health,
    backendSync: _backendSyncState,
    syncOutbox: syncOutboxSummary,
    linkedProjects: linkedProjects,
    selectedProject: selectedProject,
    loadedFileCount: fileCount,
    redactedSecretCount: _redactedCount,
  );

  /// Silent background probe of both endpoints — call once on launch so a
  /// broken key shows as a calm amber dot, never a mid-demo surprise.
  Future<void> runHealthCheck() async {
    final checker = _healthChecker;
    if (checker == null) return;
    _health = await checker.check();
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _redactedCount = 0;
  int get redactedCount => _redactedCount;

  String? _loadingSubtitle;
  String? get loadingSubtitle => _loadingSubtitle;
  List<String> _loadingSteps = const [];
  List<String> get loadingSteps => _loadingSteps;
  int _loadingStepIndex = 0;
  int get loadingStepIndex => _loadingStepIndex;

  UserProfile? get profile => _profiles.current;
  int get usageThisMonth => _profiles.usageThisMonth;

  // ---- Navigation -----------------------------------------------------------
  void showInput() => _setView(OverlayView.input);

  void editLastPrompt() {
    _prefillPrompt = (_lastRoughPrompt?.trim().isNotEmpty ?? false)
        ? _lastRoughPrompt
        : _response?.improvedPrompt ?? '';
    _setView(OverlayView.input);
  }

  void showHome([ShellSection? section]) {
    if (section != null) _shellSection = section;
    _setView(OverlayView.home);
  }

  void setShellSection(ShellSection section) {
    _shellSection = section;
    notifyListeners();
  }

  /// Opens the settings modal (over the shell). Reachable from anywhere.
  void openSettings([SettingsTab tab = SettingsTab.general]) {
    _settingsTab = tab;
    _settingsOpen = true;
    if (_view != OverlayView.home) _view = OverlayView.home;
    notifyListeners();
  }

  void setSettingsTab(SettingsTab tab) {
    _settingsTab = tab;
    notifyListeners();
  }

  void closeSettings() {
    _settingsOpen = false;
    notifyListeners();
  }

  /// Quick-template hotkey fired: open the input pre-filled with the canned
  /// prompt for that analysis type.
  void startTemplateAnalysis(String cannedPrompt) {
    _prefillPrompt = cannedPrompt;
    _setView(OverlayView.input);
  }

  void _setView(OverlayView v) {
    _view = v;
    notifyListeners();
  }

  // ---- Onboarding -----------------------------------------------------------
  Future<void> completeOnboarding(UserProfile profile) async {
    await _profiles.save(profile);
    _setView(OverlayView.home);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _profiles.save(profile);
    notifyListeners();
  }

  // ---- Files ----------------------------------------------------------------
  /// Loads a set of raw file contents (from the picker), redacts them, and
  /// records the redaction count for the trust notice.
  void setFiles(
    Map<String, String> rawByName, {
    String projectPath = 'untitled',
  }) {
    _clearAnalysisArtifacts();
    _rawFiles = rawByName;
    _projectPath = projectPath;
    _project = FileService.buildFromRaw(rawByName);
    _projectIntelligence = ProjectIntelligenceService.analyze(
      projectPath: projectPath,
      project: _project!,
    );
    _redactedCount = _project!.redactedSecretCount;
    notifyListeners();
  }

  // ---- History clearing -----------------------------------------------------
  Future<void> clearProjectHistory() async {
    await _history.clear(ProjectContext.stablePathHash(_projectPath));
    notifyListeners();
  }

  /// Deletes every stored analysis (destructive; caller confirms first).
  Future<void> clearAllHistory() async {
    await _history.clearAll();
    notifyListeners();
  }

  // ---- The analyze pipeline -------------------------------------------------
  Future<void> analyze(
    String roughPrompt, {
    Uint8List? screenshot,
    AnalysisPreferences preferences = const AnalysisPreferences(),
  }) async {
    _errorMessage = null;
    _clearAnalysisArtifacts(notify: false);
    _lastRoughPrompt = roughPrompt;
    final trimmedPrompt = roughPrompt.trim();

    if (trimmedPrompt.isEmpty) {
      _fail('Write what you want to change first.');
      return;
    }

    _loadingSteps = const [
      'Mapping selected project',
      'Redacting secrets locally',
      'Generating prompt with Gemini',
      'Second-pass quality check',
      'Ready to copy',
    ];
    _loadingStepIndex = 0;
    _loadingSubtitle = 'Reading selected project files...';
    _setView(OverlayView.loading);

    await _refreshActiveProjectFiles(
      query: preferences.autoFileSearch ? trimmedPrompt : '',
    );
    _auditReport = ProjectAuditService.evaluate(
      project: _project ?? FileService.buildFromRaw(const {}),
      preferences: preferences,
    );
    _loadingStepIndex = 1;
    _loadingSubtitle =
        _projectIntelligence?.summary ??
        (fileCount > 0
            ? 'Loaded $fileCount fresh ${fileCount == 1 ? 'file' : 'files'} from this project.'
            : 'No project files attached yet.');
    notifyListeners();

    // 1. Validate.
    final validation = RequestValidator.validate(
      roughPrompt: trimmedPrompt,
      fileContents: _project?.redactedContentByName.values.toList() ?? const [],
      screenshotBytes: screenshot,
    );
    if (!validation.isValid) {
      _fail(
        validation.message ?? ErrorMessages.forFailure(FailureType.unknown),
      );
      return;
    }

    // 2. Rate limit.
    if (!_rateLimiter.canMakeRequest()) {
      _fail(ErrorMessages.forFailure(FailureType.rateLimited));
      return;
    }
    _rateLimiter.recordRequest();

    // 3. Build context (profile, project, history, KB, frustration).
    final profile = _profiles.current;
    if (profile == null) {
      _setView(OverlayView.onboarding);
      return;
    }

    final projectContext = await _projects.observe(
      projectPath: _projectPath,
      files: _rawFiles,
    );
    final projectHash = ProjectContext.stablePathHash(_projectPath);
    final legacyProjectHash = _projectPath.hashCode.toString();
    await _history.rekeyProject(from: legacyProjectHash, to: projectHash);
    final recent = _history.recentFor(projectHash);

    final builder = ExtraAIRequestBuilder(
      userProfile: profile,
      projectContext: projectContext,
      auditReport: _auditReport,
      projectIntelligence: _projectIntelligence,
      recentHistory: recent,
      preferences: preferences,
      frustrationDetected: FrustrationDetector.detect(roughPrompt),
    );
    final fullPrompt = builder.buildFullPrompt(
      fileContents: _project?.concatenatedContent ?? '',
      roughPrompt: trimmedPrompt,
      issuesEnabled: true,
    );

    // 4. Loading state.
    _loadingStepIndex = 2;
    _loadingSubtitle = fileCount > 0
        ? 'Gemini is using the current request plus $fileCount fresh ${fileCount == 1 ? 'file' : 'files'}.'
        : 'Gemini is using the current request and visible screen context.';
    notifyListeners();

    // 5. Generate (Gemini) — already timeout+retry-wrapped inside the service.
    final result = await _gemini.analyze(
      fullPrompt: fullPrompt,
      screenshotBytes: screenshot,
    );

    // 6. Handle generation outcome.
    if (!result.isSuccess) {
      // DEMO-ONLY safety net for the live pitch: if both live attempts fail,
      // show the pre-recorded known-good response instead of an error screen.
      if (_demoFallbackEnabled) {
        _response = buildContextualFallbackResponse(
          roughPrompt: trimmedPrompt,
          fileNames: _project?.fileNames ?? const [],
        );
        _verification = VerificationStatus.demoFallback;
        _analysisTrace = _buildAnalysisTrace(
          projectContext: projectContext,
          historyEntriesUsed: recent.length,
          preferences: preferences,
          freshnessRegenerated: false,
        );
        _setView(OverlayView.results);
        return;
      }
      _fail(ErrorMessages.forFailure(result.failure!));
      return;
    }

    _response = result.response;
    var freshnessRegenerated = false;
    if (ResponseFreshnessService.looksStale(
      response: _response!,
      roughPrompt: trimmedPrompt,
      recentHistory: recent,
    )) {
      _loadingSubtitle =
          'Regenerating because the first draft matched history...';
      notifyListeners();
      final fresh = await _gemini.regenerateStaleDraft(
        fullPrompt: fullPrompt,
        staleDraft: _response!,
        roughPrompt: trimmedPrompt,
        screenshotBytes: screenshot,
      );
      if (fresh.isSuccess) {
        _response = fresh.response;
        freshnessRegenerated = true;
      }
    }
    _qualityReport = ResponseQualityService.evaluate(
      response: _response!,
      knownFiles: _project?.fileNames ?? const [],
      preferences: preferences,
      intelligence: _projectIntelligence,
    );

    // 7. Verify with the structurally different critic model, then correct
    //    once if flagged. The gate degrades gracefully: an unreachable critic
    //    or failed correction never blocks the user's result.
    _loadingStepIndex = 3;
    _loadingSubtitle =
        'Checking the draft for stale output, missing files, and risky advice.';
    notifyListeners();
    _verification = await _verifyAndMaybeCorrect(
      fullPrompt: fullPrompt,
      profile: profile,
      screenshot: screenshot,
    );
    if (_response != null) {
      _qualityReport = ResponseQualityService.evaluate(
        response: _response!,
        knownFiles: _project?.fileNames ?? const [],
        preferences: preferences,
        intelligence: _projectIntelligence,
      );
    }
    _analysisTrace = _buildAnalysisTrace(
      projectContext: projectContext,
      historyEntriesUsed: recent.length,
      preferences: preferences,
      freshnessRegenerated: freshnessRegenerated,
    );

    // 8. Persist history + usage; report the entry to the other window so
    //    its dashboards see it this session (separate engine = separate Hive
    //    in-memory copy).
    final entry = PromptHistoryEntry(
      projectPathHash: projectHash,
      roughPrompt: trimmedPrompt,
      improvedPrompt: _response!.improvedPrompt,
      issuesFound: _response!.issues,
      timestamp: DateTime.now(),
      qualityStatus: _qualityReport?.status.name,
      qualitySummary: _qualityReport?.summary,
      auditStatus: _auditReport?.status,
      auditSummary: _auditReport?.summary,
      auditReport: _auditReport,
      trace: _analysisTrace,
    );
    await _history.add(entry);
    await _projects.recordAnalysis(projectContext);
    await _profiles.incrementUsage();
    await _enqueueSyncEvent(SyncEventType.analysisCreated, {
      'projectPathHash': projectHash,
      'filesRead': _analysisTrace?.filesRead ?? 0,
      'redactedSecrets': _analysisTrace?.redactedSecrets ?? 0,
      'historyEntriesUsed': recent.length,
      'qualityStatus': _qualityReport?.status.name ?? 'unknown',
      'auditStatus': _auditReport?.status ?? 'unknown',
      'auditIssueCount': _auditReport?.issues.length ?? 0,
      'verificationStatus': _verification.name,
      'modelLabel': _gemini.modelLabel,
      'freshnessRegenerated': _analysisTrace?.freshnessRegenerated ?? false,
    });
    await refreshBackendSync();
    notifyListeners();
    await onAnalysisPersisted?.call(entry);

    _loadingStepIndex = 4;
    _loadingSubtitle = 'Prompt ready to copy.';
    notifyListeners();
    _setView(OverlayView.results);
  }

  void _clearAnalysisArtifacts({bool notify = false}) {
    _response = null;
    _qualityReport = null;
    _auditReport = null;
    _analysisTrace = null;
    _verification = VerificationStatus.skipped;
    _loadingSubtitle = null;
    _loadingSteps = const [];
    _loadingStepIndex = 0;
    if (_view == OverlayView.results) _view = OverlayView.input;
    if (notify) notifyListeners();
  }

  Future<void> _refreshActiveProjectFiles({String query = ''}) async {
    final selected = selectedProject;
    if (selected == null) return;
    await _loadProjectSnapshot(selected, query: query);
  }

  Future<void> _loadProjectSnapshot(
    ProjectContext project, {
    String query = '',
  }) async {
    final loaded = await FileService.loadProjectSnapshot(
      project.projectPath,
      query: query,
    );
    _projectPath = project.projectPath;
    _project = loaded;
    _projectIntelligence = ProjectIntelligenceService.analyze(
      projectPath: project.projectPath,
      project: loaded,
    );
    _rawFiles = loaded.redactedContentByName;
    _redactedCount = loaded.redactedSecretCount;
  }

  AnalysisTrace _buildAnalysisTrace({
    required ProjectContext projectContext,
    required int historyEntriesUsed,
    required AnalysisPreferences preferences,
    required bool freshnessRegenerated,
  }) {
    return AnalysisTrace(
      projectName: projectContext.displayName,
      projectPathHash: projectContext.pathHash,
      modelLabel: _gemini.modelLabel,
      filesRead: _project?.fileNames.length ?? 0,
      filesSample: (_project?.fileNames ?? const []).take(6).toList(),
      redactedSecrets: _redactedCount,
      historyEntriesUsed: historyEntriesUsed,
      preferences: preferences,
      recommendedChecks: _projectIntelligence?.recommendedChecks ?? const [],
      freshnessRegenerated: freshnessRegenerated,
      qualityStatus: _qualityReport?.status.name ?? 'unknown',
      verificationStatus: _verification.name,
      generatedAt: DateTime.now(),
    );
  }

  /// The two-model quality gate: critic verdict → optional single corrective
  /// pass. Mutates [_response] only when the correction succeeds.
  Future<VerificationStatus> _verifyAndMaybeCorrect({
    required String fullPrompt,
    required UserProfile profile,
    Uint8List? screenshot,
  }) async {
    final verifier = _verifier;
    if (verifier == null || !verifier.isConfigured) {
      return VerificationStatus.skipped;
    }

    final verdict = await verifier.verify(
      draft: _response!,
      originalFileContents: _project?.concatenatedContent ?? '',
      userProfile: profile,
    );

    if (verdict == null) return VerificationStatus.unavailable;
    if (verdict.passed) return VerificationStatus.verified;

    // One corrective pass only — never loop chasing perfection.
    final correction = verdict.correctionInstruction;
    if (correction == null) return VerificationStatus.unavailable;

    final fixed = await _gemini.correctDraft(
      fullPrompt: fullPrompt,
      draft: _response!,
      correctionInstruction: correction,
      screenshotBytes: screenshot,
    );
    if (fixed.isSuccess) {
      _response = fixed.response;
      return VerificationStatus.corrected;
    }
    // Correction failed — best-effort: keep the original draft, be honest.
    return VerificationStatus.unavailable;
  }

  void _fail(String message) {
    _errorMessage = message;
    _setView(OverlayView.input);
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }
}
