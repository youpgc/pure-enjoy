// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood_diary_model.dart';

class MoodDiaryModelAdapter extends TypeAdapter<MoodDiaryModel> {
  @override
  final int typeId = 2;

  @override
  MoodDiaryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MoodDiaryModel(
      id: fields[0] as String,
      mood: fields[1] as String,
      moodLabel: fields[2] as String?,
      content: fields[3] as String?,
      date: fields[4] as DateTime,
      createdAt: fields[5] as DateTime,
      synced: fields[6] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, MoodDiaryModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mood)
      ..writeByte(2)
      ..write(obj.moodLabel)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodDiaryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
