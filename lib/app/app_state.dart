import 'package:flutter/foundation.dart';

import '../models/extra_ai_response.dart';
import '../models/prompt_history_entry.dart';
import '../models/user_profile.dart';
import '../security/rate_limiter.dart';
import '../security/request_validator.dart';
import '../services/extra_ai_request_builder.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../services/profile_service.dart';
import '../services/project_context_service.dart';
import '../understanding/error_messages.dart';
import '../understanding/frustration_detector.dart';

/// Which screen the overlay window is showing.
enum OverlayView { onboarding, input, loading, results, settings }

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
    RateLimiter? rateLimiter,
  })  : _profiles = profileService,
        _projects = projectService,
        _history = historyService,
        _gemini = geminiService,
        _rateLimiter = rateLimiter ?? RateLimiter() {
    _view = _profiles.hasProfile ? OverlayView.input : OverlayView.onboarding;
  }

  final ProfileService _profiles;
  final ProjectContextService _projects;
  final HistoryService _history;
  final GeminiService _gemini;
  final RateLimiter _rateLimiter;

  // ---- View state -----------------------------------------------------------
  late OverlayView _view;
  OverlayView get view => _view;

  OverlayView _previousView = OverlayView.input;

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

  void openSettings() {
    _previousView = _view;
    _setView(OverlayView.settings);
  }

  void closeSettings() => _setView(_previousView);

  void _setView(OverlayView v) {
    _view = v;
    notifyListeners();
  }

  // ---- Onboarding -----------------------------------------------------------
  Future<void> completeOnboarding(UserProfile profile) async {
    await _profiles.save(profile);
    _setView(OverlayView.input);
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

    // 5. Call Gemini.
    final result = await _gemini.analyze(
      fullPrompt: fullPrompt,
      screenshotBytes: screenshot,
    );

    // 6. Handle outcome.
    if (!result.isSuccess) {
      _fail(ErrorMessages.forFailure(result.failure!));
      return;
    }

    _response = result.response;

    // 7. Persist history + usage.
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

  void _fail(String message) {
    _errorMessage = message;
    _setView(OverlayView.input);
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }
}
