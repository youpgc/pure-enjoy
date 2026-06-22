import 'dart:async';

/// 全局事件总线，用于跨页面/跨组件通信
///
/// 使用示例：
/// ```dart
/// // 发送事件
/// EventBus.instance.fire(EventType.expenseUpdated);
///
/// // 监听事件
/// EventBus.instance.on(EventType.expenseUpdated).listen((_) {
///   _loadLatestRecords();
/// });
/// ```
class EventBus {
  static final EventBus _instance = EventBus._internal();
  static EventBus get instance => _instance;

  EventBus._internal();

  final _controllers = <EventType, StreamController<void>>{};

  /// 获取指定事件类型的广播流
  Stream<void> on(EventType type) {
    _controllers.putIfAbsent(type, () => StreamController<void>.broadcast());
    return _controllers[type]!.stream;
  }

  /// 触发指定事件
  void fire(EventType type) {
    if (_controllers.containsKey(type)) {
      _controllers[type]!.add(null);
    }
  }

  /// 释放资源（应用退出时调用）
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}

/// 事件类型枚举
enum EventType {
  /// 记账数据更新（新增/编辑/删除）
  expenseUpdated,

  /// 体重记录更新
  weightRecordUpdated,

  /// 心情日记更新
  moodDiaryUpdated,

  /// 笔记更新
  noteUpdated,

  /// 习惯打卡更新
  habitUpdated,

  /// 提醒事项更新
  reminderUpdated,

  /// 书架更新
  bookshelfUpdated,
}
