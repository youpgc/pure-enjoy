import 'package:hive/hive.dart';

part 'expense_model.g.dart';

/// 消费记录模型
@HiveType(typeId: 1)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final double amount;
  
  @HiveField(2)
  final String category;
  
  @HiveField(3)
  final String? note;
  
  @HiveField(4)
  final DateTime date;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final bool synced;
  
  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.createdAt,
    this.synced = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'note': note,
    'date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'synced': synced,
  };
  
  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'],
    amount: json['amount'].toDouble(),
    category: json['category'],
    note: json['note'],
    date: DateTime.parse(json['date']),
    createdAt: DateTime.parse(json['created_at']),
    synced: json['synced'] ?? true,
  );
}
