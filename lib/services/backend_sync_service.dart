import '../models/backend_sync_state.dart';
import '../models/sync_outbox_event.dart';

abstract class BackendSyncGateway {
  Future<BackendSyncState> status([SyncOutboxSummary? outbox]);
}

/// Local-first sync adapter. It intentionally performs no upload; it exposes a
/// stable backend contract so cloud sync can be introduced without touching the
/// UI flow.
class LocalBackendSyncService implements BackendSyncGateway {
  const LocalBackendSyncService();

  @override
  Future<BackendSyncState> status([SyncOutboxSummary? outbox]) async {
    final pending = outbox?.pending ?? 0;
    final failed = outbox?.failed ?? 0;
    return BackendSyncState(
      mode: BackendSyncMode.cloudReady,
      lastCheckedAt: DateTime.now(),
      adaptersReady: const [
        'local auth',
        'local project memory',
        'local history',
        'billing gateway contract',
        'sync outbox',
      ],
      message: failed > 0
          ? '$failed sync events need attention before cloud upload.'
          : pending > 0
          ? '$pending safe metadata sync events are queued locally.'
          : 'Local-first now. Backend contracts are ready for Supabase/Stripe metadata sync.',
    );
  }
}
