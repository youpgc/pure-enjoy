/// 体重记录模型 - 对应 Supabase weight_records 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), weight(DECIMAL), body_fat(DECIMAL), record_date(DATE)
class WeightRecordModel {
  final String id;
  final String userId;
  final String? userNickname;
  final double weight;
  final double? bodyFat;
  final DateTime date;
  final DateTime? createdAt;

  WeightRecordModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.weight,
    this.bodyFat,
    required this.date,
    this.createdAt,
  });

  factory WeightRecordModel.fromJson(Map<String, dynamic> json) {
    return WeightRecordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      weight: (json['weight'] as num).toDouble(),
      bodyFat: json['body_fat'] != null ? (json['body_fat'] as num).toDouble() : null,
      date: DateTime.parse(json['record_date'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'user_nickname': userNickname,
      'weight': weight,
      'body_fat': bodyFat,
      'record_date': date.toIso8601String().split('T').first,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
    // 只在ID非空时添加，让数据库自动生成新记录的ID
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  WeightRecordModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    double? weight,
    double? bodyFat,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return WeightRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      weight: weight ?? this.weight,
      bodyFat: bodyFat ?? this.bodyFat,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
