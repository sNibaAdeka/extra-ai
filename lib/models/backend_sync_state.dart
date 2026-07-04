enum BackendSyncMode { localOnly, cloudReady, cloudConnected }

class BackendSyncState {
  const BackendSyncState({
    required this.mode,
    required this.lastCheckedAt,
    required this.adaptersReady,
    this.message,
  });

  final BackendSyncMode mode;
  final DateTime lastCheckedAt;
  final List<String> adaptersReady;
  final String? message;

  String get label => switch (mode) {
    BackendSyncMode.localOnly => 'Local-first',
    BackendSyncMode.cloudReady => 'Cloud-ready',
    BackendSyncMode.cloudConnected => 'Cloud connected',
  };

  String get summary =>
      message ??
      switch (mode) {
        BackendSyncMode.localOnly =>
          'Code, prompts, and history stay on this Mac. Cloud adapters are not connected.',
        BackendSyncMode.cloudReady =>
          'Backend contracts are ready; connect Supabase/Stripe adapters when needed.',
        BackendSyncMode.cloudConnected =>
          'Cloud sync is connected for allowed metadata.',
      };
}
