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
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String joinedAt;

  AppUser copyWith({String? name, String? email, UserRole? role}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        joinedAt: joinedAt,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Guest',
        email: json['email'] as String? ?? '',
        role: UserRole.fromWire(json['role'] as String?),
        joinedAt: json['joinedAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.wire,
        'joinedAt': joinedAt,
      };
}
