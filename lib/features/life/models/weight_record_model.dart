/// 体重记录模型
class WeightRecordModel {
  final String id;
  final String userId;
  final double weight;
  final double? bmi;
  final double? bodyFat;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WeightRecordModel({
    required this.id,
    required this.userId,
    required this.weight,
    this.bmi,
    this.bodyFat,
    this.note,
    required this.date,
    required this.createdAt,
    this.updatedAt,
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
      'weight': weight,
      'bmi': bmi,
      'body_fat': bodyFat,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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
    DateTime? updatedAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
