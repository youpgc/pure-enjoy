/// 体重记录模型 - 对应 Supabase weight_records 表
/// 字段: id(UUID), user_id(VARCHAR50), weight(DECIMAL), body_fat(DECIMAL), record_date(DATE)
class WeightRecordModel {
  final String id;
  final String userId;
  final double weight;
  final double? bodyFat;
  final DateTime recordDate;

  WeightRecordModel({
    required this.id,
    required this.userId,
    required this.weight,
    this.bodyFat,
    required this.recordDate,
  });

  factory WeightRecordModel.fromJson(Map<String, dynamic> json) {
    return WeightRecordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weight: (json['weight'] as num).toDouble(),
      bodyFat: json['body_fat'] != null ? (json['body_fat'] as num).toDouble() : null,
      recordDate: DateTime.parse(json['record_date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'weight': weight,
      'body_fat': bodyFat,
      'record_date': recordDate.toIso8601String().split('T').first,
    };
  }

  WeightRecordModel copyWith({
    String? id,
    String? userId,
    double? weight,
    double? bodyFat,
    DateTime? recordDate,
  }) {
    return WeightRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weight: weight ?? this.weight,
      bodyFat: bodyFat ?? this.bodyFat,
      recordDate: recordDate ?? this.recordDate,
    );
  }
}
