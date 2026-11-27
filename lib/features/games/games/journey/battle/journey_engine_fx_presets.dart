part of 'journey_flame_game.dart';

/// 特效参数集：进关时从通用战斗参数表的特效分组读取一次，对局内固定。
///
/// 每项都按安全区间钳制，后台误填不会撑爆粒子池或让每帧发射失控；
/// 参数缺失时回落下面的内置值，行为与参数表未部署时一致。
class JourneyFxPresets {
  JourneyFxPresets(this._read);

  final double Function(String group, String code, double fallback) _read;

  double _num(String code, double fallback, double min, double max) =>
      _read('fx', code, fallback).clamp(min, max).toDouble();

  int _int(String code, int fallback, int min, int max) =>
      _num(code, fallback.toDouble(), min.toDouble(), max.toDouble()).round();

  /// 粒子池槽位：进关时确定，后台调整下次进关生效。
  late final int poolSlots = _int('pool_slots', 64, 32, 512);

  // ---- 火焰 / 灼烧 ----

  /// 单束火舌寿命（秒）。
  late final double flameLife = _num('flame_life', 0.3, 0.1, 3);

  /// 单只怪物每次发射的焰舌条数。
  late final int flameCount = _int('flame_count', 2, 1, 12);

  /// 焰舌高度相对怪物半径的倍数：贴身短焰，不盖过怪物本体。
  late final double flameHeight = _num('flame_height_ratio', 0.7, 0.5, 4);

  /// 焰舌宽度相对怪物半径的倍数。
  late final double flameWidth = _num('flame_width_ratio', 0.2, 0.05, 1);

  /// 焰舌上窜初速（像素/秒）：默认贴地不窜，贴图自身摆动提供动态。
  late final double flameRise = _num('flame_rise_speed', 0, 0, 200);

  /// 焰舌横向扩散初速（像素/秒）。
  late final double flameSpread = _num('flame_spread_speed', 6, 0, 120);

  /// 伴随余烬数量。
  late final int flameEmbers = _int('flame_ember_count', 1, 0, 12);

  /// 伴随亮核数量：焰贴图自带亮核，仅极少数场景需要补光。
  late final int flameCoreCount = _int('flame_core_count', 0, 0, 8);

  /// 伴随烟尘浓度。
  late final double flameSmoke = _num('flame_smoke_alpha', 0.08, 0, 1);

  /// 伴随烟尘上浮速度（像素/秒）。
  late final double flameSmokeRise = _num('flame_smoke_rise', 16, 0, 80);

  /// 同一只怪物的火焰发射间隔（秒）。
  late final double flameInterval = _num('flame_emit_interval', 0.25, 0.02, 2);

  // ---- 雷电 / 电弧 ----

  /// 电弧寿命（秒）。
  late final double arcLife = _num('arc_life', 0.2, 0.05, 1);

  /// 电弧贴图厚度相对链长的倍数。
  late final double arcThickness = _num('arc_thickness_ratio', 0.42, 0.1, 1.5);

  /// 电弧贴图最小厚度（像素）。
  late final double arcMinThickness = _num('arc_min_thickness', 24, 8, 120);

  // ---- 冲击 / 残屑 ----

  /// 冲击环寿命（秒）。
  late final double shockLife = _num('shock_life', 0.42, 0.1, 2);

  /// 冲击环外扩火星数量。
  late final int shockSparks = _int('shock_spark_count', 4, 0, 32);

  /// 冲击环中心烟尘浓度。
  late final double shockSmoke = _num('shock_smoke_alpha', 0.08, 0, 1);

  /// 冲击烟尘半径相对冲击环半径的倍数。
  late final double shockSmokeRatio = _num('shock_smoke_ratio', 0.18, 0.05, 1);

  /// 参照物破碎的碎块数量。
  late final int debrisCount = _int('debris_count', 6, 0, 20);

  /// 碎块寿命（秒）。
  late final double debrisLife = _num('debris_life', 0.58, 0.1, 3);

  /// 碎块落地烟尘浓度。
  late final double debrisSmoke = _num('debris_smoke_alpha', 0.3, 0, 1);

  // ---- 尾迹 / 光束 ----

  /// 飞行弹体尾迹的发射间隔（秒）。
  late final double trailInterval = _num('trail_interval', 0.12, 0.01, 1);

  /// 尾迹光粒寿命（秒）。
  late final double trailLife = _num('trail_life', 0.3, 0.05, 2);

  /// 光束内的游离光粒数量。
  late final int beamMotes = _int('beam_mote_count', 4, 0, 40);

  // ---- 妖王领域 / 预警 ----

  /// 领域环境粒子的发射间隔（秒）。
  late final double fieldInterval = _num('field_emit_interval', 0.3, 0.02, 2);

  /// 领域环境粒子寿命（秒）。
  late final double fieldLife = _num('field_life', 0.6, 0.1, 3);

  /// 领域毒雾与灼烧雾粒浓度。
  late final double fieldSmoke = _num('field_smoke_alpha', 0.26, 0, 1);

  /// 预警圈边缘火星的发射间隔（秒）。
  late final double telegraphInterval =
      _num('telegraph_interval', 0.2, 0.02, 1);

  /// 预警圈边缘火星寿命（秒）。
  late final double telegraphLife = _num('telegraph_life', 0.28, 0.05, 2);
}
