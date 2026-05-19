import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';

/// 支出记录模型 - 对应 Supabase expenses 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), amount(DECIMAL), category(VARCHAR), description(TEXT), date(DATE)
class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final DateTime date;
  final DateTime? createdAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': AuthService.instance.currentUserName,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String().split('T').first,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String().split('T').first,
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 支出分类
enum ExpenseCategory {
  food('餐饮', Icons.restaurant),
  transport('交通', Icons.directions_car),
  shopping('购物', Icons.shopping_bag),
  entertainment('娱乐', Icons.movie),
  health('医疗', Icons.local_hospital),
  education('教育', Icons.school),
  other('其他', Icons.more_horiz);

  final String label;
  final IconData icon;

  const ExpenseCategory(this.label, this.icon);
}
