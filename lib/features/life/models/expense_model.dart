import 'package:flutter/material.dart';

/// 支出记录模型
class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    this.userId = 'local_user',
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
