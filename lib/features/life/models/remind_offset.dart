/// 提醒偏移设置模型（共享：纪念日 / 待办）
///
/// 一个提醒可配置多个触发偏移（如「当天」+「提前1天」+「提前15分钟」），
/// 每个偏移基于「目标时刻」推算真实触发时间。
class RemindOffset {
  /// 偏移单位：same=当天；minute=提前N分钟；day=提前N天
  final String unit;

  /// 偏移数值：same 时为 0；minute 为分钟数；day 为天数
  final int value;

  const RemindOffset(this.unit, this.value);

  /// 基于目标基准时刻计算真实触发时刻
  DateTime resolve(DateTime base) {
    switch (unit) {
      case 'minute':
        return base.subtract(Duration(minutes: value));
      case 'day':
        return base.subtract(Duration(days: value));
      case 'same':
      default:
        return base;
    }
  }

  /// 单位文案（不含具体时间），如「提前 1 天」
  String get unitLabel {
    switch (unit) {
      case 'minute':
        return '提前 $value 分钟';
      case 'day':
        return '提前 $value 天';
      case 'same':
      default:
        return '当天';
    }
  }

  Map<String, dynamic> toJson() => {'unit': unit, 'value': value};

  factory RemindOffset.fromJson(Map<String, dynamic> json) {
    return RemindOffset(
      (json['unit'] as String?) ?? 'same',
      (json['value'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RemindOffset && other.unit == unit && other.value == value;

  @override
  int get hashCode => unit.hashCode ^ value.hashCode;

  /// 预设档位
  static const RemindOffset sameDay = RemindOffset('same', 0);
  static const RemindOffset fifteenMinutes = RemindOffset('minute', 15);
  static const RemindOffset thirtyMinutes = RemindOffset('minute', 30);
  static const RemindOffset oneHour = RemindOffset('minute', 60);
  static const RemindOffset oneDay = RemindOffset('day', 1);
  static const RemindOffset threeDays = RemindOffset('day', 3);

  /// 所有可选项（供 UI 多选）
  static const List<RemindOffset> presets = [
    sameDay,
    fifteenMinutes,
    thirtyMinutes,
    oneHour,
    oneDay,
    threeDays,
  ];
}

/// 提醒设置（开关 + 多个偏移）
class RemindSettings {
  final bool enabled;
  final List<RemindOffset> offsets;

  const RemindSettings({this.enabled = false, this.offsets = const []});

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'offsets': offsets.map((e) => e.toJson()).toList(),
      };

  factory RemindSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RemindSettings();
    final list = json['offsets'];
    final offsets = list is List
        ? list
            .map((e) => RemindOffset.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <RemindOffset>[];
    return RemindSettings(
      enabled: json['enabled'] as bool? ?? false,
      offsets: offsets,
    );
  }
}
