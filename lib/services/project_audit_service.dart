import '../models/analysis_preferences.dart';
import '../models/project_audit_report.dart';
import 'file_service.dart';

class ProjectAuditService {
  const ProjectAuditService._();

  static ProjectAuditReport evaluate({
    required LoadedProject project,
    required AnalysisPreferences preferences,
  }) {
    final issues = <ProjectAuditIssue>[];

    if (preferences.securityAudit) {
      _security(project, issues);
    }
    if (preferences.bugAudit) {
      _bugs(project, issues);
      _accessibilityAndResponsive(project, issues);
    }

    issues.sort((a, b) {
      final severity = _rank(b.severity).compareTo(_rank(a.severity));
      if (severity != 0) return severity;
      return a.title.compareTo(b.title);
    });
    return ProjectAuditReport(issues: issues.take(8).toList(growable: false));
  }

  static void _security(LoadedProject project, List<ProjectAuditIssue> out) {
    if (project.redactedSecretCount > 0) {
      out.add(
        ProjectAuditIssue(
          category: ProjectAuditCategory.security,
          severity: ProjectAuditSeverity.high,
          title: 'Secret-like value was redacted',
          detail:
              '${project.redactedSecretCount} value(s) matched local secret redaction patterns before the model request.',
        ),
      );
    }

    for (final entry in project.redactedContentByName.entries) {
      final path = entry.key;
      final content = entry.value;
      _match(
        content,
        RegExp(r'\beval\s*\(|new\s+Function\s*\('),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.security,
            severity: ProjectAuditSeverity.high,
            title: 'Dynamic code execution',
            detail: 'Avoid eval/new Function unless strictly sandboxed.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'dangerouslySetInnerHTML|\.innerHTML\s*=|document\.write\s*\('),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.security,
            severity: ProjectAuditSeverity.warning,
            title: 'HTML injection surface',
            detail: 'Sanitize user-controlled HTML or render text safely.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'http://(?!localhost|127\.0\.0\.1)'),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.security,
            severity: ProjectAuditSeverity.warning,
            title: 'Insecure HTTP URL',
            detail: 'Use HTTPS for external requests and assets.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(
          r'localStorage\.(setItem|getItem)\([^)]*(token|password|secret)',
          caseSensitive: false,
        ),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.security,
            severity: ProjectAuditSeverity.warning,
            title: 'Sensitive localStorage usage',
            detail: 'Tokens and secrets in localStorage are exposed to XSS.',
            file: path,
          ),
        ),
      );
    }
  }

  static void _bugs(LoadedProject project, List<ProjectAuditIssue> out) {
    for (final entry in project.redactedContentByName.entries) {
      final path = entry.key;
      final content = entry.value;
      _match(
        content,
        RegExp(r'\b(TODO|FIXME|HACK)\b'),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.bug,
            severity: ProjectAuditSeverity.info,
            title: 'Unresolved implementation marker',
            detail: 'TODO/FIXME/HACK comments often mark unfinished behavior.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'catch\s*\([^)]*\)\s*\{\s*\}'),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.bug,
            severity: ProjectAuditSeverity.warning,
            title: 'Empty catch block',
            detail: 'Swallowed errors make runtime failures hard to diagnose.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'\bconsole\.log\s*\('),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.bug,
            severity: ProjectAuditSeverity.info,
            title: 'Console logging left in source',
            detail: 'Remove debug logging or gate it behind debug mode.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'localhost:\d+|127\.0\.0\.1:\d+'),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.bug,
            severity: ProjectAuditSeverity.warning,
            title: 'Hard-coded local endpoint',
            detail: 'Move local URLs into environment-specific config.',
            file: path,
          ),
        ),
      );
    }
  }

  static void _accessibilityAndResponsive(
    LoadedProject project,
    List<ProjectAuditIssue> out,
  ) {
    for (final entry in project.redactedContentByName.entries) {
      final path = entry.key;
      final content = entry.value;
      _match(
        content,
        RegExp(r'<img(?![^>]*\salt=)', caseSensitive: false),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.accessibility,
            severity: ProjectAuditSeverity.warning,
            title: 'Image without alt text',
            detail: 'Add meaningful alt text or mark decorative images.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'''(width|min-width)\s*[:=]\s*['"]?([5-9]\d{2,}|1\d{3,})'''),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.responsive,
            severity: ProjectAuditSeverity.warning,
            title: 'Large fixed width',
            detail: 'Large fixed widths often break mobile layouts.',
            file: path,
          ),
        ),
      );
      _match(
        content,
        RegExp(r'overflow\s*:\s*hidden'),
        () => out.add(
          ProjectAuditIssue(
            category: ProjectAuditCategory.responsive,
            severity: ProjectAuditSeverity.info,
            title: 'Overflow hidden',
            detail:
                'Check that clipped content is intentional on small screens.',
            file: path,
          ),
        ),
      );
    }
  }

  static void _match(String content, RegExp pattern, VoidCallback add) {
    if (pattern.hasMatch(content)) add();
  }

  static int _rank(ProjectAuditSeverity severity) => switch (severity) {
    ProjectAuditSeverity.high => 3,
    ProjectAuditSeverity.warning => 2,
    ProjectAuditSeverity.info => 1,
  };
}

typedef VoidCallback = void Function();
