import 'package:hive/hive.dart';

part 'weight_record_model.g.dart';

/// 体重记录模型
@HiveType(typeId: 3)
class WeightRecordModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final double weight; // 体重 kg
  
  @HiveField(2)
  final String? note;
  
  @HiveField(3)
  final DateTime date;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final bool synced;
  
  WeightRecordModel({
    required this.id,
    required this.weight,
    this.note,
    required this.date,
    required this.createdAt,
    this.synced = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'note': note,
    'date': date.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'synced': synced,
  };
  
  factory WeightRecordModel.fromJson(Map<String, dynamic> json) => WeightRecordModel(
    id: json['id'],
    weight: json['weight'].toDouble(),
    note: json['note'],
    date: DateTime.parse(json['date']),
    createdAt: DateTime.parse(json['created_at']),
    synced: json['synced'] ?? true,
  );
}
