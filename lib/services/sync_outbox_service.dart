import 'package:hive/hive.dart';

import '../models/sync_outbox_event.dart';

abstract class SyncOutboxGateway {
  Future<void> enqueue(SyncEventType type, Map<String, dynamic> payload);
  List<SyncOutboxEvent> all();
  SyncOutboxSummary summary();
  Future<int> flushPending();
}

class LocalSyncOutboxService implements SyncOutboxGateway {
  LocalSyncOutboxService(this._box);

  static const String boxName = 'sync_outbox';

  final Box _box;

  @override
  Future<void> enqueue(SyncEventType type, Map<String, dynamic> payload) async {
    final now = DateTime.now();
    final event = SyncOutboxEvent(
      id: '${now.microsecondsSinceEpoch}_${type.name}',
      type: type,
      status: SyncEventStatus.pending,
      createdAt: now,
      payload: _safeMetadata(payload),
    );
    await _box.put(event.id, event.toMap());
  }

  @override
  List<SyncOutboxEvent> all() {
    final events = _box.values
        .whereType<Map>()
        .map((m) => SyncOutboxEvent.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  @override
  SyncOutboxSummary summary() => _summaryFor(all());

  @override
  Future<int> flushPending() async {
    final pending = all().where((event) => event.isPending).toList();
    final now = DateTime.now();
    for (final event in pending) {
      final flushed = event.copyWith(
        status: SyncEventStatus.flushed,
        lastAttemptAt: now,
        attemptCount: event.attemptCount + 1,
      );
      await _box.put(event.id, flushed.toMap());
    }
    return pending.length;
  }

  static SyncOutboxSummary _summaryFor(List<SyncOutboxEvent> events) {
    var pending = 0;
    var flushed = 0;
    var failed = 0;
    DateTime? last;
    for (final event in events) {
      switch (event.status) {
        case SyncEventStatus.pending:
          pending++;
        case SyncEventStatus.flushed:
          flushed++;
        case SyncEventStatus.failed:
          failed++;
      }
      if (last == null || event.createdAt.isAfter(last)) last = event.createdAt;
    }
    return SyncOutboxSummary(
      pending: pending,
      flushed: flushed,
      failed: failed,
      lastEventAt: last,
    );
  }

  static Map<String, dynamic> _safeMetadata(Map<String, dynamic> payload) {
    final out = <String, dynamic>{};
    for (final entry in payload.entries) {
      final value = entry.value;
      if (value == null ||
          value is String ||
          value is num ||
          value is bool ||
          value is List<String>) {
        out[entry.key] = value;
      }
    }
    return out;
  }
}

class InMemorySyncOutboxService implements SyncOutboxGateway {
  final List<SyncOutboxEvent> _events = [];

  @override
  Future<void> enqueue(SyncEventType type, Map<String, dynamic> payload) async {
    final now = DateTime.now();
    _events.add(
      SyncOutboxEvent(
        id: '${now.microsecondsSinceEpoch}_${type.name}',
        type: type,
        status: SyncEventStatus.pending,
        createdAt: now,
        payload: LocalSyncOutboxService._safeMetadata(payload),
      ),
    );
  }

  @override
  List<SyncOutboxEvent> all() => List.unmodifiable(
    _events.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  SyncOutboxSummary summary() => LocalSyncOutboxService._summaryFor(all());

  @override
  Future<int> flushPending() async {
    var count = 0;
    final now = DateTime.now();
    for (var i = 0; i < _events.length; i++) {
      final event = _events[i];
      if (!event.isPending) continue;
      _events[i] = event.copyWith(
        status: SyncEventStatus.flushed,
        lastAttemptAt: now,
        attemptCount: event.attemptCount + 1,
      );
      count++;
    }
    return count;
  }
}
