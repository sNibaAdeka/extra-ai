enum ProjectAuditSeverity { info, warning, high }

enum ProjectAuditCategory { security, bug, accessibility, responsive }

class ProjectAuditIssue {
  const ProjectAuditIssue({
    required this.category,
    required this.severity,
    required this.title,
    required this.detail,
    this.file,
  });

  final ProjectAuditCategory category;
  final ProjectAuditSeverity severity;
  final String title;
  final String detail;
  final String? file;

  Map<String, dynamic> toMap() => {
    'category': category.name,
    'severity': severity.name,
    'title': title,
    'detail': detail,
    'file': file,
  };

  factory ProjectAuditIssue.fromMap(Map<String, dynamic> map) {
    return ProjectAuditIssue(
      category: ProjectAuditCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ProjectAuditCategory.bug,
      ),
      severity: ProjectAuditSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => ProjectAuditSeverity.info,
      ),
      title: map['title'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      file: map['file'] as String?,
    );
  }
}

class ProjectAuditReport {
  const ProjectAuditReport({required this.issues});

  final List<ProjectAuditIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
  int get highCount =>
      issues.where((i) => i.severity == ProjectAuditSeverity.high).length;
  int get warningCount =>
      issues.where((i) => i.severity == ProjectAuditSeverity.warning).length;

  String get status {
    if (highCount > 0) return 'risk';
    if (warningCount > 0) return 'warning';
    return 'clean';
  }

  String get label => switch (status) {
    'risk' => 'Risk found',
    'warning' => 'Review recommended',
    _ => 'No local risks found',
  };

  String get summary {
    if (issues.isEmpty) {
      return 'Local bug/security scan found no obvious risks in loaded files.';
    }
    final security = issues
        .where((i) => i.category == ProjectAuditCategory.security)
        .length;
    final bugs = issues
        .where((i) => i.category == ProjectAuditCategory.bug)
        .length;
    final ux = issues.length - security - bugs;
    final parts = [
      if (security > 0) '$security security',
      if (bugs > 0) '$bugs bug',
      if (ux > 0) '$ux UX',
    ];
    return '${issues.length} local ${issues.length == 1 ? 'signal' : 'signals'}: ${parts.join(', ')}.';
  }

  String toPromptBlock() {
    if (issues.isEmpty) {
      return 'LOCAL AUDIT:\n- No deterministic local bug/security signals found.';
    }
    final lines = issues
        .take(8)
        .map(
          (issue) =>
              '- [${issue.severity.name}/${issue.category.name}] ${issue.file == null ? '' : '@${issue.file}: '}${issue.title} — ${issue.detail}',
        )
        .join('\n');
    return 'LOCAL AUDIT:\n$lines';
  }

  Map<String, dynamic> toMap() => {
    'issues': issues.map((i) => i.toMap()).toList(growable: false),
  };

  factory ProjectAuditReport.fromMap(Map<String, dynamic> map) {
    return ProjectAuditReport(
      issues: (map['issues'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ProjectAuditIssue.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false),
    );
  }
}
