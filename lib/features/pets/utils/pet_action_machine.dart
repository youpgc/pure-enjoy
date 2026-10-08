import '../../../constants/pet_bend.dart';
import '../../../constants/pet_render.dart';

/// 2D 动作仲裁器：决定「此刻舞台上应该播哪个动作」。
///
/// 口径来自需求 §11.3（2026-10-08 修订：核心 5 + 氛围 1；happy 并入 petted、
/// walk 移出定版集）——优先级与互斥沿用原触发矩阵：
/// `evolve`（独占）> `eat` = `petted` > `sad` > `sleep` > `idle`，
/// 高优先级打断低优先级，一次性动作演完回落到环境态（低状态时回落到 sad）。
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

  /// 环境态覆盖（2026-10-08 §11.3 修订接线）：低状态（饱食/心情低于历险出发
  /// 阈值，同一口径零新增配置）时由页面注入 [PetAction.sad]，恢复后置回 null。
  /// null = 常态 idle；sleep（夜间/久无操作）仍待 pet_config 阈值接线
  /// （铁律 2：客户端不写默认值），接线后在同一点扩展。
  PetAction? ambientOverride;

  /// 环境态：无交互时应该循环什么。
  PetAction get ambient => ambientOverride ?? PetAction.idle;

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

  /// 各动作一轮演出时长：直接回读弯曲编排表（`kPetBendActs` 的 `per`，单位秒）。
  ///
  /// 旧版这里是本文件手抄的一份 Duration 表，和样片冻结的周期早已对不上
  /// （walk 4200 vs 3200、evolve 2200 vs 6800）——一次性动作的回落计时比实际演出
  /// 短一截，演到一半就被切回环境态。周期本来就是编排的一部分，只留一个源。
  static Duration durationOf(PetAction action) {
    final per = (kPetBendActs[action.code] ?? kPetBendActs['idle']!).per;
    return Duration(milliseconds: (per * 1000).round());
  }
}
