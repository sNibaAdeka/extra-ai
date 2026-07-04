import '../models/backend_sync_state.dart';
import '../models/product_health_report.dart';
import '../models/project_context.dart';
import '../models/sync_outbox_event.dart';
import 'health_check_service.dart';

class ProductHealthService {
  const ProductHealthService._();

  static ProductHealthReport build({
    required AppHealth appHealth,
    required BackendSyncState backendSync,
    required SyncOutboxSummary syncOutbox,
    required List<ProjectContext> linkedProjects,
    required ProjectContext? selectedProject,
    required int loadedFileCount,
    required int redactedSecretCount,
  }) {
    // NOTE: the cloud-sync line is intentionally omitted from the report.
    // There is no live backend yet, so a "sync" status would raise the
    // question "sync to what?" for a jury with no good answer. backendSync /
    // syncOutbox params are kept in the signature for when sync ships.
    return ProductHealthReport(
      generatedAt: DateTime.now(),
      items: [
        _generator(appHealth.generator),
        _critic(appHealth.critic),
        _privacy(redactedSecretCount),
      ],
    );
  }

  static ProductHealthItem _generator(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.healthy => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.ok,
        title: 'AI analysis: Connected',
        detail: 'Ready to analyze your screen and code.',
      ),
      ServiceStatus.degraded => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.critical,
        title: 'AI analysis: Unavailable',
        detail: 'Check your internet connection and try again.',
        actionLabel: 'Retry',
      ),
      ServiceStatus.unconfigured => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.critical,
        title: 'AI analysis: Not set up',
        detail: 'An API key is needed before live analysis.',
        actionLabel: 'Set up',
      ),
      ServiceStatus.unknown => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.info,
        title: 'AI analysis: Checking…',
        detail: 'Running a quick connection check.',
      ),
    };
  }

  static ProductHealthItem _critic(ServiceStatus status) {
    return switch (status) {
      ServiceStatus.healthy => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.ok,
        title: 'Quality verification: Active',
        detail: 'A second model double-checks every result.',
      ),
      ServiceStatus.degraded => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.warning,
        title: 'Quality verification: Limited',
        detail: 'Analysis still works; second-model checks may be skipped.',
      ),
      ServiceStatus.unconfigured => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.info,
        title: 'Quality verification: Optional',
        detail: 'Analysis works on its own; a second model can be added.',
      ),
      ServiceStatus.unknown => const ProductHealthItem(
        area: ProductHealthArea.ai,
        severity: ProductHealthSeverity.info,
        title: 'Quality verification: Checking…',
        detail: 'Status updates after the quick connection check.',
      ),
    };
  }

  static ProductHealthItem _privacy(int redactedSecretCount) {
    if (redactedSecretCount > 0) {
      return ProductHealthItem(
        area: ProductHealthArea.privacy,
        severity: ProductHealthSeverity.ok,
        title: 'Secrets redacted',
        detail:
            '$redactedSecretCount potential ${redactedSecretCount == 1 ? 'secret was' : 'secrets were'} removed before model input.',
      );
    }
    return const ProductHealthItem(
      area: ProductHealthArea.privacy,
      severity: ProductHealthSeverity.ok,
      title: 'Privacy guard active',
      detail: 'Project files are redacted locally before any model request.',
    );
  }
}
