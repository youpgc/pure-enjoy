import '../../../utils/date_time_utils.dart';

/// 支出/收入记录模型 - 对应 Supabase expenses 表
/// 字段: id(UUID), user_id(VARCHAR), amount(DECIMAL), category(VARCHAR), type(TEXT: expense/income), description(TEXT), date(DATE), created_at, updated_at
class ExpenseModel {
  /// 记录类型：支出
  static const String typeExpense = 'expense';

  /// 记录类型：收入
  static const String typeIncome = 'income';

  final String id;
  final String userId;
  final double amount;
  final String category;

  /// 记录类型：expense=支出 / income=收入；存量数据经列默认值均为 expense
  final String type;
  final String? description;
  final DateTime date;
  final String? userNickname;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    this.type = typeExpense,
    this.description,
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
      type: json['type'] as String? ?? typeExpense,
      description: json['description'] as String?,
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
      'type': type,
      'description': description,
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


  ExpenseModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? category,
    String? type,
    String? description,
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
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      userNickname: userNickname ?? this.userNickname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
