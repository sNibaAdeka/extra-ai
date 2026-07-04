/// Status of one backing service (generator or critic).
enum ServiceStatus {
  /// Not probed yet.
  unknown,

  /// Probe succeeded — key valid and endpoint reachable.
  healthy,

  /// Probe failed — the user should not discover this mid-demo.
  degraded,

  /// No credentials supplied; the feature is off, not broken.
  unconfigured,
}

/// Combined health of the app's two AI services.
class AppHealth {
  const AppHealth({
    this.generator = ServiceStatus.unknown,
    this.critic = ServiceStatus.unknown,
  });

  final ServiceStatus generator;
  final ServiceStatus critic;

  /// True when any configured service failed its probe.
  bool get isDegraded =>
      generator == ServiceStatus.degraded || critic == ServiceStatus.degraded;

  /// True when everything configured is confirmed working.
  bool get isHealthy =>
      generator == ServiceStatus.healthy &&
      (critic == ServiceStatus.healthy || critic == ServiceStatus.unconfigured);
}

/// Signature of a lightweight connectivity/auth probe — a minimal test call
/// (1-token completion / countTokens), never a full analysis.
typedef HealthProbe = Future<bool> Function();

/// Runs silent background probes against both endpoints on app launch so a
/// broken API key surfaces as a calm amber dot next to the settings gear —
/// never as a surprise failure mid-demo.
class HealthCheckService {
  HealthCheckService({this.generatorProbe, this.criticProbe});

  /// Null probe = the service is not configured.
  final HealthProbe? generatorProbe;
  final HealthProbe? criticProbe;

  Future<AppHealth> check() async {
    final results = await Future.wait([
      _probe(generatorProbe),
      _probe(criticProbe),
    ]);
    return AppHealth(generator: results[0], critic: results[1]);
  }

  Future<ServiceStatus> _probe(HealthProbe? probe) async {
    if (probe == null) return ServiceStatus.unconfigured;
    try {
      final ok = await probe().timeout(const Duration(seconds: 8));
      return ok ? ServiceStatus.healthy : ServiceStatus.degraded;
    } catch (_) {
      return ServiceStatus.degraded;
    }
  }
}
