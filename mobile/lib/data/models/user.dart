import 'enums.dart';

/// A users/{uid} profile document. Its existence is what marks a signed-in
/// account as onboarded.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.embers = 0,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String joinedAt;

  /// Spendable currency, earned one per check-in and spent repairing broken
  /// streaks. Written only by Cloud Functions — the client can read it but
  /// Firestore rules reject any client write that changes it.
  final int embers;

  AppUser copyWith({String? name, String? email, UserRole? role}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        joinedAt: joinedAt,
        embers: embers,
      );

  /// Only demo mode sets this directly. Against the live backend the balance is
  /// owned by Cloud Functions, so [copyWith] deliberately carries it through
  /// untouched rather than exposing it as an editable field.
  AppUser withEmbers(int value) => AppUser(
        id: id,
        name: name,
        email: email,
        role: role,
        joinedAt: joinedAt,
        embers: value,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Guest',
        email: json['email'] as String? ?? '',
        role: UserRole.fromWire(json['role'] as String?),
        joinedAt: json['joinedAt'] as String? ?? '',
        embers: (json['embers'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.wire,
        'joinedAt': joinedAt,
        // Serialized for demo mode's local store. FirestoreRepository strips
        // this before writing: against the live backend the balance is owned by
        // Cloud Functions, and a client write carrying a stale value would both
        // clobber an increment and be rejected by the security rules.
        'embers': embers,
      };
}
