import 'package:flutter_test/flutter_test.dart';

import 'package:extra_ai/models/sync_outbox_event.dart';
import 'package:extra_ai/services/sync_outbox_service.dart';

void main() {
  test('enqueue stores only safe metadata payload', () async {
    final outbox = InMemorySyncOutboxService();

    await outbox.enqueue(SyncEventType.analysisCreated, {
      'projectPathHash': 'abc',
      'filesRead': 4,
      'unsafeMap': {'secret': 'nope'},
      'unsafeList': [1, 2, 3],
      'safeList': <String>['flutter analyze'],
    });

    final event = outbox.all().single;
    expect(event.type, SyncEventType.analysisCreated);
    expect(event.payload['projectPathHash'], 'abc');
    expect(event.payload['filesRead'], 4);
    expect(event.payload['safeList'], ['flutter analyze']);
    expect(event.payload.containsKey('unsafeMap'), isFalse);
    expect(event.payload.containsKey('unsafeList'), isFalse);
  });

  test('flushPending marks queued events as flushed', () async {
    final outbox = InMemorySyncOutboxService();
    await outbox.enqueue(SyncEventType.projectLinked, {'projectPathHash': 'p'});
    await outbox.enqueue(SyncEventType.planChanged, {'tier': 'pro'});

    expect(outbox.summary().pending, 2);
    final flushed = await outbox.flushPending();

    expect(flushed, 2);
    expect(outbox.summary().pending, 0);
    expect(outbox.summary().flushed, 2);
    expect(
      outbox.all().every((e) => e.status == SyncEventStatus.flushed),
      true,
    );
  });
}
