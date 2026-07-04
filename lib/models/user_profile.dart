/// User's self-described coding experience — controls how technical the
/// improved_prompt language and issue descriptions can be.
enum ExperienceLevel {
  vibeCoder(
    'vibe-coder',
    "I vibe-code — I don't read code, I describe what I want",
    'The user does not read code. Explain issues in plain language, avoid jargon.',
  ),
  promptFirst(
    'prompt-first',
    'I can read code but write prompts more than code myself',
    'The user reads code but prefers prompts. Moderate technical depth is fine.',
  ),
  developer(
    'developer',
    "I'm a developer who uses AI to move faster",
    'The user is a developer. Full technical depth and terminology are welcome.',
  );

  const ExperienceLevel(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static ExperienceLevel fromId(String id) => ExperienceLevel.values.firstWhere(
    (e) => e.id == id,
    orElse: () => ExperienceLevel.promptFirst,
  );
}

/// What the user mostly builds — affects which issue categories to prioritize.
enum ProjectFocus {
  clientSites(
    'client-sites',
    'Client websites / landing pages',
    'Client landing pages — prioritize visual polish and basic security.',
  ),
  saas(
    'saas',
    'SaaS products / web apps',
    'SaaS products — prioritize data validation, auth, and reliability issues.',
  ),
  personal(
    'personal',
    'Personal projects / learning',
    'Personal/learning projects — favor clear explanations that teach.',
  ),
  mobile(
    'mobile',
    'Mobile apps',
    'Mobile apps — prioritize state, lifecycle, and platform-specific issues.',
  );

  const ProjectFocus(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static ProjectFocus fromId(String id) => ProjectFocus.values.firstWhere(
    (e) => e.id == id,
    orElse: () => ProjectFocus.personal,
  );
}

/// How verbose the issue descriptions should be.
enum ToneLevel {
  technical(
    'technical',
    'Just the facts — short and technical',
    'Keep issue descriptions short and technical. No hand-holding.',
  ),
  explained(
    'explained',
    'Explain a bit — I want to understand why',
    'Explain the why behind each issue briefly so the user understands it.',
  );

  const ToneLevel(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static ToneLevel fromId(String id) => ToneLevel.values.firstWhere(
    (e) => e.id == id,
    orElse: () => ToneLevel.explained,
  );
}

/// Collected once during onboarding; editable in settings. Persisted locally
/// via Hive (see HistoryService/onboarding). Never leaves the device except as
/// the specific fields embedded in the Gemini context block.
class UserProfile {
  const UserProfile({
    required this.experienceLevel,
    required this.primaryTools,
    required this.projectFocus,
    required this.tonePreference,
    required this.createdAt,
  });

  final ExperienceLevel experienceLevel;
  final List<String> primaryTools;
  final ProjectFocus projectFocus;
  final ToneLevel tonePreference;
  final DateTime createdAt;

  UserProfile copyWith({
    ExperienceLevel? experienceLevel,
    List<String>? primaryTools,
    ProjectFocus? projectFocus,
    ToneLevel? tonePreference,
    DateTime? createdAt,
  }) {
    return UserProfile(
      experienceLevel: experienceLevel ?? this.experienceLevel,
      primaryTools: primaryTools ?? this.primaryTools,
      projectFocus: projectFocus ?? this.projectFocus,
      tonePreference: tonePreference ?? this.tonePreference,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'experienceLevel': experienceLevel.id,
    'primaryTools': primaryTools,
    'projectFocus': projectFocus.id,
    'tonePreference': tonePreference.id,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    experienceLevel: ExperienceLevel.fromId(
      map['experienceLevel'] as String? ?? '',
    ),
    primaryTools: (map['primaryTools'] as List?)?.cast<String>() ?? const [],
    projectFocus: ProjectFocus.fromId(map['projectFocus'] as String? ?? ''),
    tonePreference: ToneLevel.fromId(map['tonePreference'] as String? ?? ''),
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
