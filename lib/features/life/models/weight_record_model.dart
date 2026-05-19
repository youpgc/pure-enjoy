/// 体重记录模型 - 对应 Supabase weight_records 表
/// 字段: id(UUID), user_id(VARCHAR), user_nickname(VARCHAR), weight(DECIMAL), unit(VARCHAR), body_fat(DECIMAL), note(TEXT), date(DATE)
class WeightRecordModel {
  final String id;
  final String userId;
  final String? userNickname;
  final double weight;
  final String unit;
  final double? bodyFat;
  final String? note;
  final DateTime date;
  final DateTime? createdAt;

  WeightRecordModel({
    required this.id,
    required this.userId,
    this.userNickname,
    required this.weight,
    this.unit = 'kg',
    this.bodyFat,
    this.note,
    required this.date,
    this.createdAt,
  });

  factory WeightRecordModel.fromJson(Map<String, dynamic> json) {
    return WeightRecordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userNickname: json['user_nickname'] as String?,
      weight: (json['weight'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      bodyFat: json['body_fat'] != null ? (json['body_fat'] as num).toDouble() : null,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_nickname': userNickname,
      'weight': weight,
      'unit': unit,
      'body_fat': bodyFat,
      'note': note,
      'date': date.toIso8601String().split('T').first,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  WeightRecordModel copyWith({
    String? id,
    String? userId,
    String? userNickname,
    double? weight,
    String? unit,
    double? bodyFat,
    String? note,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return WeightRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userNickname: userNickname ?? this.userNickname,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      bodyFat: bodyFat ?? this.bodyFat,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
