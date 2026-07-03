import '../../../utils/date_time_utils.dart';

/// 支出记录模型 - 对应 Supabase expenses 表
/// 字段: id(UUID), user_id(VARCHAR), amount(DECIMAL), category(VARCHAR), description(TEXT), note(TEXT), date(DATE), created_at, updated_at
class ExpenseModel {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String? description;
  final String? note;
  final DateTime date;
  final String? userNickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.description,
    this.note,
    required this.date,
    this.userNickname,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String?,
      note: json['note'] as String?,
      date: DateTimeUtils.parseDate(json['date'] as String?) ?? DateTime.now(),
      userNickname: json['user_nickname'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'amount': amount,
      'category': category,
      'description': description,
      'note': note,
      'date': date.toIso8601String().split('T').first,
    };
    if (userNickname != null) {
      json['user_nickname'] = userNickname;
    }
    // 只在ID非空时添加，让数据库自动生成新记录的ID
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    if (createdAt != null) {
      json['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      json['updated_at'] = updatedAt!.toIso8601String();
    }
    return json;
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'note': note,
      'date': date.toIso8601String().split('T').first,
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? description,
    String? note,
    DateTime? date,
    String? userNickname,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      note: note ?? this.note,
      date: date ?? this.date,
      userNickname: userNickname ?? this.userNickname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
