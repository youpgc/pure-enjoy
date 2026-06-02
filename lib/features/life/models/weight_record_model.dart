/// 体重记录模型 - 对应 Supabase weight_records 表
/// 字段: id(UUID), user_id(VARCHAR), weight(DECIMAL), bmi(DECIMAL), body_fat(DECIMAL), note(TEXT), date(DATE), created_at, updated_at
class WeightRecordModel {
  final String id;
  final String userId;
  final double weight;
  final double? bmi;
  final double? bodyFat;
  final String? note;
  final DateTime date;
  final DateTime? createdAt;

  WeightRecordModel({
    required this.id,
    required this.userId,
    required this.weight,
    this.bmi,
    this.bodyFat,
    this.note,
    required this.date,
    this.createdAt,
  });

  factory WeightRecordModel.fromJson(Map<String, dynamic> json) {
    return WeightRecordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weight: (json['weight'] as num).toDouble(),
      bmi: json['bmi'] != null ? (json['bmi'] as num).toDouble() : null,
      bodyFat: json['body_fat'] != null ? (json['body_fat'] as num).toDouble() : null,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'weight': weight,
      'bmi': bmi,
      'body_fat': bodyFat,
      'note': note,
      'date': date.toIso8601String().split('T').first,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
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
    double? weight,
    double? bmi,
    double? bodyFat,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return WeightRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      bodyFat: bodyFat ?? this.bodyFat,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
