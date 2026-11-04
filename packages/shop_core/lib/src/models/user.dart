import 'package:equatable/equatable.dart';

enum UserRole { customer, admin }

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] == 'admin' ? UserRole.admin : UserRole.customer,
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );

  @override
  List<Object?> get props => [id, name, email, role, createdAt];
}
