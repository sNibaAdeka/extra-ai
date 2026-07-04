enum SyncEventType { analysisCreated, projectLinked, planChanged }

enum SyncEventStatus { pending, flushed, failed }

class SyncOutboxEvent {
  const SyncOutboxEvent({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.payload,
    this.lastAttemptAt,
    this.attemptCount = 0,
    this.error,
  });

  final String id;
  final SyncEventType type;
  final SyncEventStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final DateTime? lastAttemptAt;
  final int attemptCount;
  final String? error;

  bool get isPending => status == SyncEventStatus.pending;

  SyncOutboxEvent copyWith({
    SyncEventStatus? status,
    DateTime? lastAttemptAt,
    int? attemptCount,
    String? error,
  }) {
    return SyncOutboxEvent(
      id: id,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      payload: payload,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      error: error,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'payload': payload,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'attemptCount': attemptCount,
    'error': error,
  };

  factory SyncOutboxEvent.fromMap(Map<String, dynamic> map) {
    return SyncOutboxEvent(
      id: map['id'] as String? ?? '',
      type: SyncEventType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => SyncEventType.analysisCreated,
      ),
      status: SyncEventStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SyncEventStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      payload: Map<String, dynamic>.from((map['payload'] as Map?) ?? const {}),
      lastAttemptAt: DateTime.tryParse(map['lastAttemptAt'] as String? ?? ''),
      attemptCount: map['attemptCount'] as int? ?? 0,
      error: map['error'] as String?,
    );
  }
}

class SyncOutboxSummary {
  const SyncOutboxSummary({
    required this.pending,
    required this.flushed,
    required this.failed,
    this.lastEventAt,
  });

  final int pending;
  final int flushed;
  final int failed;
  final DateTime? lastEventAt;

  int get total => pending + flushed + failed;
  bool get hasWork => pending > 0 || failed > 0;

  String get label {
    if (pending > 0) return '$pending pending';
    if (failed > 0) return '$failed failed';
    if (flushed > 0) return 'Synced locally';
    return 'No sync events';
  }
}
