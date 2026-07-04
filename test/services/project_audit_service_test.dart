import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/analysis_preferences.dart';
import 'package:extra_ai/models/project_audit_report.dart';
import 'package:extra_ai/services/file_service.dart';
import 'package:extra_ai/services/project_audit_service.dart';

void main() {
  test('finds local security, accessibility, and responsive risks', () {
    final project = FileService.buildFromRaw({
      'src/main.tsx': '''
const token = localStorage.getItem('token');
eval(window.location.hash);
export const Hero = () => <img src="/hero.png" />;
''',
      'src/styles.css': '''
.hero { width: 900px; overflow: hidden; }
''',
    });

    final report = ProjectAuditService.evaluate(
      project: project,
      preferences: const AnalysisPreferences(),
    );

    expect(report.status, 'risk');
    expect(
      report.issues.map((issue) => issue.category),
      containsAll([
        ProjectAuditCategory.security,
        ProjectAuditCategory.accessibility,
        ProjectAuditCategory.responsive,
      ]),
    );
    expect(report.toPromptBlock(), contains('LOCAL AUDIT'));
  });

  test('respects disabled security and bug audits', () {
    final project = FileService.buildFromRaw({
      'src/main.ts': 'eval("alert(1)"); // TODO fix',
    });

    final report = ProjectAuditService.evaluate(
      project: project,
      preferences: const AnalysisPreferences(
        securityAudit: false,
        bugAudit: false,
      ),
    );

    expect(report.issues, isEmpty);
    expect(report.status, 'clean');
  });
}
