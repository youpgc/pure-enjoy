import 'package:hive/hive.dart';

part 'user_model.g.dart';

/// 用户模型
@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String? email;
  
  @HiveField(2)
  final String? phone;
  
  @HiveField(3)
  final String? nickname;
  
  @HiveField(4)
  final String? avatarUrl;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final DateTime? lastLoginAt;
  
  UserModel({
    required this.id,
    this.email,
    this.phone,
    this.nickname,
    this.avatarUrl,
    required this.createdAt,
    this.lastLoginAt,
  });
  
  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? nickname,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
