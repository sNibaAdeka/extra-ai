/// A locally-stored user account. Auth is stubbed for the MVP: credentials
/// live only in Hive on this device (no backend, no real OAuth). The [id] is
/// what scopes UserProfile / ProjectContext / PromptHistoryEntry going forward.
class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
