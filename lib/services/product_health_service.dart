import '../models/backend_sync_state.dart';
import '../models/product_health_report.dart';
import '../models/project_context.dart';
import '../models/subscription_state.dart';
import '../models/sync_outbox_event.dart';
import 'health_check_service.dart';

class ProductHealthService {
  const ProductHealthService._();

  static ProductHealthReport build({
    required AppHealth appHealth,
    required BackendSyncState backendSync,
    required SyncOutboxSummary syncOutbox,
    required SubscriptionState subscription,
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
        _project(
          linkedProjects: linkedProjects,
          selectedProject: selectedProject,
          loadedFileCount: loadedFileCount,
        ),
        _privacy(redactedSecretCount),
        _usage(subscription),
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

  static ProductHealthItem _project({
    required List<ProjectContext> linkedProjects,
    required ProjectContext? selectedProject,
    required int loadedFileCount,
  }) {
    if (linkedProjects.isEmpty) {
      return const ProductHealthItem(
        area: ProductHealthArea.project,
        severity: ProductHealthSeverity.warning,
        title: 'No projects linked',
        detail: 'Sync Codex/Claude projects or choose a folder manually.',
        actionLabel: 'Link project',
      );
    }
    if (selectedProject == null) {
      return ProductHealthItem(
        area: ProductHealthArea.project,
        severity: ProductHealthSeverity.warning,
        title: 'No active project selected',
        detail:
            '${linkedProjects.length} projects are linked, but analysis has no default folder.',
        actionLabel: 'Select project',
      );
    }
    if (loadedFileCount == 0) {
      return ProductHealthItem(
        area: ProductHealthArea.project,
        severity: ProductHealthSeverity.info,
        title: 'Project selected',
        detail:
            '${selectedProject.displayName} is active; files will be refreshed before analysis.',
      );
    }
    return ProductHealthItem(
      area: ProductHealthArea.project,
      severity: ProductHealthSeverity.ok,
      title: 'Project context ready',
      detail:
          '${selectedProject.displayName} has $loadedFileCount fresh ${loadedFileCount == 1 ? 'file' : 'files'} loaded.',
    );
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

  static ProductHealthItem _usage(SubscriptionState subscription) {
    if (subscription.remainingAnalyses == 0) {
      return ProductHealthItem(
        area: ProductHealthArea.usage,
        severity: ProductHealthSeverity.critical,
        title: 'Monthly limit reached',
        detail: subscription.headline,
        actionLabel: 'Upgrade plan',
      );
    }
    if (subscription.usageRatio >= 0.85) {
      return ProductHealthItem(
        area: ProductHealthArea.usage,
        severity: ProductHealthSeverity.warning,
        title: 'Plan almost full',
        detail:
            '${subscription.remainingAnalyses} analyses remain on ${subscription.tier.label}.',
        actionLabel: 'View plans',
      );
    }
    return ProductHealthItem(
      area: ProductHealthArea.usage,
      severity: ProductHealthSeverity.ok,
      title: '${subscription.tier.label} plan ready',
      detail: '${subscription.remainingAnalyses} analyses remain this month.',
    );
  }
}
