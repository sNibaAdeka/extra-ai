import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/backend_sync_state.dart';
import 'package:extra_ai/services/backend_sync_service.dart';

void main() {
  test('local sync adapter exposes cloud-ready backend contracts', () async {
    const service = LocalBackendSyncService();

    final status = await service.status();

    expect(status.mode, BackendSyncMode.cloudReady);
    expect(status.label, 'Cloud-ready');
    expect(status.adaptersReady, contains('billing gateway contract'));
    expect(status.summary, contains('Backend contracts'));
  });
}
