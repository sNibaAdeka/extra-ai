enum ModelEffort { fast, balanced, deep }

enum ActionMode { promptOnly, fullAccess, autoEdit }

class AnalysisPreferences {
  const AnalysisPreferences({
    this.effort = ModelEffort.balanced,
    this.actionMode = ActionMode.promptOnly,
    this.screenContext = true,
    this.autoFileSearch = true,
    this.securityAudit = true,
    this.bugAudit = true,
  });

  final ModelEffort effort;
  final ActionMode actionMode;
  final bool screenContext;
  final bool autoFileSearch;
  final bool securityAudit;
  final bool bugAudit;

  Map<String, dynamic> toMap() => {
    'effort': effort.name,
    'actionMode': actionMode.name,
    'screenContext': screenContext,
    'autoFileSearch': autoFileSearch,
    'securityAudit': securityAudit,
    'bugAudit': bugAudit,
  };

  factory AnalysisPreferences.fromMap(Map<String, dynamic> map) {
    return AnalysisPreferences(
      effort: ModelEffort.values.firstWhere(
        (e) => e.name == map['effort'],
        orElse: () => ModelEffort.balanced,
      ),
      actionMode: ActionMode.values.firstWhere(
        (m) => m.name == map['actionMode'],
        orElse: () => ActionMode.promptOnly,
      ),
      screenContext: map['screenContext'] as bool? ?? true,
      autoFileSearch: map['autoFileSearch'] as bool? ?? true,
      securityAudit: map['securityAudit'] as bool? ?? true,
      bugAudit: map['bugAudit'] as bool? ?? true,
    );
  }

  String get effortLabel => switch (effort) {
    ModelEffort.fast => 'Fast',
    ModelEffort.balanced => 'Balanced',
    ModelEffort.deep => 'Deep',
  };

  String get actionLabel => switch (actionMode) {
    ActionMode.promptOnly => 'Prompt',
    ActionMode.fullAccess => 'Full access',
    ActionMode.autoEdit => 'Auto edit',
  };

  String toPromptDirectives() {
    final effortText = switch (effort) {
      ModelEffort.fast =>
        'Fast: prioritize the shortest accurate prompt; avoid extra diagnosis.',
      ModelEffort.balanced =>
        'Balanced: produce a precise prompt with enough context to implement safely.',
      ModelEffort.deep =>
        'Deep: inspect relationships between files and include implementation constraints.',
    };
    final actionText = switch (actionMode) {
      ActionMode.promptOnly =>
        'Output a copy-ready prompt for the target coding tool.',
      ActionMode.fullAccess =>
        'Write the prompt as if the coding agent has full local repository access and should inspect related files before editing.',
      ActionMode.autoEdit =>
        'Write the prompt as an auto-apply instruction: the coding agent should make the changes directly, run checks, and report changed files.',
    };

    return '''
ANALYSIS PREFERENCES:
- Effort: $effortText
- Mode: $actionText
- Use screen context: $screenContext
- Auto-search similar project files: $autoFileSearch
- Include security audit: $securityAudit
- Include bug/regression audit: $bugAudit
''';
  }
}
