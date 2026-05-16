import 'package:flutter/material.dart';

/// 心情日记模型
class MoodDiaryModel {
  final String id;
  final String userId;
  final String mood;
  final String? content;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MoodDiaryModel({
    required this.id,
    this.userId = 'local_user',
    required this.mood,
    this.content,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  factory MoodDiaryModel.fromJson(Map<String, dynamic> json) {
    return MoodDiaryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mood: json['mood'] as String,
      content: json['content'] as String?,
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
      'mood': mood,
      'content': content,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MoodDiaryModel copyWith({
    String? id,
    String? userId,
    String? mood,
    String? content,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodDiaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      content: content ?? this.content,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 心情类型
enum MoodType {
  happy('开心', '😊', Color(0xFFFFD93D)),
  calm('平静', '😌', Color(0xFF6BCB77)),
  sad('难过', '😢', Color(0xFF4D96FF)),
  angry('生气', '😤', Color(0xFFFF6B6B)),
  anxious('焦虑', '😰', Color(0xFFC9B1FF)),
  tired('疲惫', '😴', Color(0xFFA0A0A0));

  final String label;
  final String emoji;
  final Color color;

  const MoodType(this.label, this.emoji, this.color);
}
