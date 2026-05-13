// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_record_model.dart';

class WeightRecordModelAdapter extends TypeAdapter<WeightRecordModel> {
  @override
  final int typeId = 3;

  @override
  WeightRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightRecordModel(
      id: fields[0] as String,
      weight: fields[1] as double,
      note: fields[2] as String?,
      date: fields[3] as DateTime,
      createdAt: fields[4] as DateTime,
      synced: fields[5] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, WeightRecordModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
