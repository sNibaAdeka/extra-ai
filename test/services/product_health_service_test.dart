import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/backend_sync_state.dart';
import 'package:extra_ai/models/product_health_report.dart';
import 'package:extra_ai/models/project_context.dart';
import 'package:extra_ai/models/sync_outbox_event.dart';
import 'package:extra_ai/services/health_check_service.dart';
import 'package:extra_ai/services/product_health_service.dart';

ProjectContext _project() => ProjectContext(
  projectPath: '/Users/me/app',
  detectedStack: 'Flutter',
  fileNames: const ['lib/main.dart'],
  firstSeenAt: DateTime(2026, 1, 1),
  lastAnalyzedAt: DateTime(2026, 1, 2),
  totalAnalysesCount: 1,
);

BackendSyncState _sync([BackendSyncMode mode = BackendSyncMode.cloudReady]) =>
    BackendSyncState(
      mode: mode,
      lastCheckedAt: DateTime(2026, 1, 1),
      adaptersReady: const ['sync outbox'],
    );

void main() {
  test('reports ready when core services and project context are healthy', () {
    final project = _project();
    final report = ProductHealthService.build(
      appHealth: const AppHealth(
        generator: ServiceStatus.healthy,
        critic: ServiceStatus.unconfigured,
      ),
      backendSync: _sync(),
      syncOutbox: const SyncOutboxSummary(pending: 0, flushed: 1, failed: 0),
      linkedProjects: [project],
      selectedProject: project,
      loadedFileCount: 4,
      redactedSecretCount: 0,
    );

    expect(report.readyForAnalysis, isTrue);
    expect(report.severity, ProductHealthSeverity.info);
    expect(
      report.items.map((item) => item.title),
      contains('AI analysis: Connected'),
    );
    expect(
      report.items.map((item) => item.title),
      contains('Privacy guard active'),
    );
    // Product/project/usage/sync lines are intentionally omitted from
    // technical health. They live in the dashboard context where they belong.
    expect(
      report.items.map((item) => item.area),
      isNot(contains(ProductHealthArea.sync)),
    );
  });

  test('blocks analysis only for real technical failures', () {
    final project = _project();
    final report = ProductHealthService.build(
      appHealth: const AppHealth(
        generator: ServiceStatus.degraded,
        critic: ServiceStatus.degraded,
      ),
      backendSync: _sync(),
      syncOutbox: const SyncOutboxSummary(pending: 0, flushed: 0, failed: 0),
      linkedProjects: [project],
      selectedProject: project,
      loadedFileCount: 1,
      redactedSecretCount: 2,
    );

    expect(report.readyForAnalysis, isFalse);
    expect(report.severity, ProductHealthSeverity.critical);
    expect(report.criticalCount, 1);
    expect(report.summary, contains('blocking'));
  });

  test('does not treat missing project or sync queue as technical health', () {
    final report = ProductHealthService.build(
      appHealth: const AppHealth(
        generator: ServiceStatus.healthy,
        critic: ServiceStatus.healthy,
      ),
      backendSync: _sync(BackendSyncMode.cloudConnected),
      syncOutbox: const SyncOutboxSummary(pending: 0, flushed: 1, failed: 2),
      linkedProjects: const [],
      selectedProject: null,
      loadedFileCount: 0,
      redactedSecretCount: 0,
    );

    expect(report.severity, ProductHealthSeverity.ok);
    expect(report.warningCount, 0);
    expect(report.readyForAnalysis, isTrue);
    expect(
      report.attentionItems.map((item) => item.title),
      isNot(contains('No projects linked')),
    );
    expect(report.allClear, isTrue);
    expect(report.dashboardLine, contains('smoothly'));
  });
}
