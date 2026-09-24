import '../../../constants/pet_render.dart';

/// 2D 动作仲裁器：决定「此刻舞台上应该播哪个动作」。
///
/// 口径来自需求 §11.3 的 8 标准动作与《3D 展现与交互实现方案》§2.1 的触发矩阵
/// ——该矩阵只讲优先级与互斥，与渲染栈无关，故 2D 原样沿用：
/// `evolve`（独占）> `eat` = `petted` > `happy` > `sad` > `sleep` > `walk` > `idle`，
/// 高优先级打断低优先级，一次性动作演完回落到环境态。
///
/// **只做仲裁，不做计时**：播放时长是本文件的编排常量（表现层属性，不是业务
/// 阈值，故不受铁律 2 的「数值必须后台可配」约束）；业务阈值（饱食/心情/时段/
/// 空闲秒数）一律读 `pet_config`，本类不写任何数值默认。
///
/// 纯 Dart，无 Flutter 依赖，便于单测与被成长/孵化页复用。
class PetActionMachine {
  PetActionMachine({PetAction current = PetAction.idle}) : _current = current;

  PetAction _current;

  /// 最近一次被接受的一次性动作时刻（同级防抖基准）；环境态不记录
  DateTime? _lastAccepted;

  /// 当前正在播放的动作
  PetAction get current => _current;

  /// 环境态：无交互时应该循环什么。
  ///
  /// 只有 [PetAction.idle] 是纯结构性判定，可直接给；`sleep`（夜间时段 /
  /// 无操作满 N 分钟）与 `walk`（空闲随机 30~90 秒）都需要 `pet_config` 里的
  /// 时段与秒数阈值，缺配置时**不启用**（铁律 2：客户端不写默认值）。
  /// 两个动作的播放能力已经实装（见 `pet_living_art.dart`），后台补上
  /// `anim_sleep_*` / `anim_walk_*` 阈值后只需在此处接判定。
  PetAction get ambient => PetAction.idle;

  /// 反应式动作是否接受播放；返回 false 表示被仲裁挡掉（不打断当前动作）。
  ///
  /// 同优先级设最短间隔防抖（[_samePriorityGap]）：连点喂食/抚摸不会让动作
  /// 停在同一档反复重启，观感上等于"卡住"。
  bool request(PetAction action) {
    if (!action.ambient) {
      if (_current == PetAction.evolve) return false; // 进化独占
      if (action.priority < _current.priority) return false;
      if (_current == action &&
          _lastAccepted != null &&
          DateTime.now().difference(_lastAccepted!) < _samePriorityGap) {
        return false;
      }
    }
    _current = action;
    _lastAccepted = action.ambient ? null : DateTime.now();
    return true;
  }

  /// 一次性动作播完：回落到环境态（[_current] 仍是 [action] 时才回落，
  /// 避免迟到的定时器把更高优先级的新动作打回 idle）
  void finish(PetAction action) {
    if (_current == action && !action.ambient) _current = ambient;
  }

  /// 换宠/离场复位
  void reset() {
    _current = ambient;
    _lastAccepted = null;
  }

  /// 同级防抖窗口：小于该值内的同名重复请求直接丢弃
  static const Duration _samePriorityGap = Duration(milliseconds: 900);

  /// 各动作一轮演出时长（idle/sleep/walk 为循环周期）
  static const Map<PetAction, Duration> _durations = {
    PetAction.idle: Duration(milliseconds: 3400),
    PetAction.walk: Duration(milliseconds: 4200),
    PetAction.sleep: Duration(milliseconds: 4800),
    PetAction.sad: Duration(milliseconds: 2400),
    PetAction.happy: Duration(milliseconds: 1100),
    PetAction.petted: Duration(milliseconds: 1200),
    PetAction.eat: Duration(milliseconds: 1500),
    PetAction.evolve: Duration(milliseconds: 2200),
  };

  static Duration durationOf(PetAction action) =>
      _durations[action] ?? _durations[PetAction.idle]!;
}
