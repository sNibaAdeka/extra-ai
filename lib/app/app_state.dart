import 'package:flutter/foundation.dart';

import '../models/extra_ai_response.dart';
import '../models/prompt_history_entry.dart';
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
import '../services/project_context_service.dart';
import '../services/settings_service.dart';
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
    this.notifications,
    this.favorites,
    this.templateBindings,
  })  : _profiles = profileService,
        _projects = projectService,
        _history = historyService,
        _gemini = geminiService,
        _verifier = verificationService,
        _healthChecker = healthCheckService,
        _rateLimiter = rateLimiter ?? RateLimiter(),
        _demoFallbackEnabled = demoFallbackEnabled { // ignore: prefer_initializing_formals
    _view = _profiles.hasProfile ? OverlayView.input : OverlayView.onboarding;
  }

  final ProfileService _profiles;
  final ProjectContextService _projects;
  final HistoryService _history;
  final GeminiService _gemini;
  final VerificationService? _verifier;
  final HealthCheckService? _healthChecker;
  final RateLimiter _rateLimiter;

  /// Shell-surface services (dashboard/history/templates/settings). Nullable
  /// so the compact analysis flow stays constructible in isolation.
  final SettingsService? settings;
  final NotificationsService? notifications;
  final FavoritesService? favorites;
  final TemplateBindingsService? templateBindings;

  HistoryService get history => _history;
  ProfileService get profiles => _profiles;

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
  String? takePrefillPrompt() {
    final p = _prefillPrompt;
    _prefillPrompt = null;
    return p;
  }

  // ---- Loaded project -------------------------------------------------------
  LoadedProject? _project;
  LoadedProject? get project => _project;
  int get fileCount => _project?.fileNames.length ?? 0;

  /// Raw (unredacted) map is used only to detect the stack + build context; it
  /// never leaves the device — the request uses the redacted concatenation.
  Map<String, String> _rawFiles = const {};
  String _projectPath = 'untitled';

  // ---- Results / errors -----------------------------------------------------
  ExtraAIResponse? _response;
  ExtraAIResponse? get response => _response;

  VerificationStatus _verification = VerificationStatus.skipped;
  VerificationStatus get verification => _verification;

  // ---- Service health --------------------------------------------------------
  AppHealth _health = const AppHealth();
  AppHealth get health => _health;

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

  UserProfile? get profile => _profiles.current;
  int get usageThisMonth => _profiles.usageThisMonth;

  // ---- Navigation -----------------------------------------------------------
  void showInput() => _setView(OverlayView.input);

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
  void setFiles(Map<String, String> rawByName, {String projectPath = 'untitled'}) {
    _rawFiles = rawByName;
    _projectPath = projectPath;
    _project = FileService.buildFromRaw(rawByName);
    _redactedCount = _project!.redactedSecretCount;
    notifyListeners();
  }

  // ---- History clearing -----------------------------------------------------
  Future<void> clearProjectHistory() async {
    await _history.clear(_projectPath.hashCode.toString());
    notifyListeners();
  }

  /// Deletes every stored analysis (destructive; caller confirms first).
  Future<void> clearAllHistory() async {
    await _history.clearAll();
    notifyListeners();
  }

  // ---- The analyze pipeline -------------------------------------------------
  Future<void> analyze(String roughPrompt, {Uint8List? screenshot}) async {
    _errorMessage = null;

    // 1. Validate.
    final validation = RequestValidator.validate(
      roughPrompt: roughPrompt,
      fileContents: _project?.redactedContentByName.values.toList() ?? const [],
      screenshotBytes: screenshot,
    );
    if (!validation.isValid) {
      _fail(validation.message ?? ErrorMessages.forFailure(FailureType.unknown));
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
    final projectHash = _projectPath.hashCode.toString();
    final recent = _history.recentFor(projectHash);

    final builder = ExtraAIRequestBuilder(
      userProfile: profile,
      projectContext: projectContext,
      recentHistory: recent,
      frustrationDetected: FrustrationDetector.detect(roughPrompt),
    );
    final fullPrompt = builder.buildFullPrompt(
      fileContents: _project?.concatenatedContent ?? '',
      roughPrompt: roughPrompt,
      issuesEnabled: true,
    );

    // 4. Loading state.
    _loadingSubtitle =
        fileCount > 0 ? 'Reading $fileCount ${fileCount == 1 ? 'file' : 'files'}...' : null;
    _setView(OverlayView.loading);

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
        _response = kDemoFallbackResponse;
        _verification = VerificationStatus.demoFallback;
        _setView(OverlayView.results);
        return;
      }
      _fail(ErrorMessages.forFailure(result.failure!));
      return;
    }

    _response = result.response;

    // 7. Verify with the structurally different critic model, then correct
    //    once if flagged. The gate degrades gracefully: an unreachable critic
    //    or failed correction never blocks the user's result.
    _verification = await _verifyAndMaybeCorrect(
      fullPrompt: fullPrompt,
      profile: profile,
      screenshot: screenshot,
    );

    // 8. Persist history + usage.
    await _history.add(PromptHistoryEntry(
      projectPathHash: projectHash,
      roughPrompt: roughPrompt,
      improvedPrompt: _response!.improvedPrompt,
      issuesFound: _response!.issues,
      timestamp: DateTime.now(),
    ));
    await _projects.recordAnalysis(projectContext);
    await _profiles.incrementUsage();

    _setView(OverlayView.results);
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
