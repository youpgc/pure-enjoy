// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_model.dart';

class NovelModelAdapter extends TypeAdapter<NovelModel> {
  @override
  final int typeId = 5;

  @override
  NovelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NovelModel(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      coverUrl: fields[3] as String?,
      description: fields[4] as String?,
      source: fields[5] as String,
      sourceId: fields[6] as String,
      addedAt: fields[7] as DateTime,
      lastReadAt: fields[8] as DateTime?,
      lastChapterIndex: fields[9] as int? ?? 0,
      progress: fields[10] as double? ?? 0.0,
      synced: fields[11] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NovelModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.coverUrl)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.source)
      ..writeByte(6)
      ..write(obj.sourceId)
      ..writeByte(7)
      ..write(obj.addedAt)
      ..writeByte(8)
      ..write(obj.lastReadAt)
      ..writeByte(9)
      ..write(obj.lastChapterIndex)
      ..writeByte(10)
      ..write(obj.progress)
      ..writeByte(11)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
