import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart' show Offset;

/// 武器维度槽：一个槽位=一个维度（属性/特效），带等级。
/// 等级上限与每级效果由 journey_weapon_slots 配置驱动（运营可调）。
class JourneyWeaponSlot {
  JourneyWeaponSlot(this.code, this.level);

  final String code;
  int level;
}

/// 对局控制器：Flame 主类与 Flutter 层（HUD/弹窗）之间的桥。
///
/// HUD 用 ValueNotifier 直读，避免每帧 setState；回调由对局页注入。
class JourneyBattleController {
  JourneyBattleController({
    required this.themeColor,
    required this.onLevelUp,
    required this.onFinished,
    required this.onBossSpawn,
  });

  final String themeColor;
  final void Function(int newLevel, {required bool paused}) onLevelUp;
  final void Function({
    required bool cleared,
    required int kills,
    required int meritFromCoins,
    required int meritClearBonus,
    required int durationSec,
  }) onFinished;
  final void Function(String bossName) onBossSpawn;

  final hud = JourneyBattleHud();

  /// 摇杆输入（对局页写入，引擎每帧读取）。
  final input = JourneyBattleInput();

  /// 进关时的最远关卡记录（首通判定基准）。
  int farthestAtStart = 0;

  /// 法宝槽位镜像（引擎入槽/升级时同步写，HUD 槽栏直接读取）。
  /// activeSlots=武器维度槽（初始武器占 1 特效槽 + 习得维度，≤6）；
  /// passiveSlots=被动加持（≤6）。
  final List<JourneyWeaponSlot> activeSlots = <JourneyWeaponSlot>[];
  final List<String> passiveSlots = <String>[];
}

/// 局外预注入（对局页组装）：天赋层增量 + 角色光环/特性法宝的效果包。
///
/// 数值口径：每系已修层数 × 系权重，标志层走独立效果键；
/// 灼烧/暴击/击退等战斗未支持的系统暂不接入（轻量映射，后续迭代补全）。
class JourneyLoadout {
  final double damageAmp;
  final double spinAmp; // 环绕转速加成注入
  final double armorFlat;
  final double bonusMaxHp;
  final double regenFlat;
  final double pickupRangeFlat;
  final double expAmp;
  final Set<String> signatures; // 如 signature_metal / signature_wood

  const JourneyLoadout({
    this.damageAmp = 0,
    this.spinAmp = 0,
    this.armorFlat = 0,
    this.bonusMaxHp = 0,
    this.regenFlat = 0,
    this.pickupRangeFlat = 0,
    this.expAmp = 1.0,
    this.signatures = const <String>{},
  });
}

/// 局内 HUD 数值源（ValueNotifier 直读，组件化 HUD 订阅）。
class JourneyBattleHud {
  final ValueNotifier<double> hp = ValueNotifier<double>(100);
  final ValueNotifier<double> maxHp = ValueNotifier<double>(100);
  final ValueNotifier<double> exp = ValueNotifier<double>(0);
  final ValueNotifier<double> expNeed = ValueNotifier<double>(12);
  final ValueNotifier<int> level = ValueNotifier<int>(1);
  final ValueNotifier<int> kills = ValueNotifier<int>(0);
  final ValueNotifier<int> meritCoins = ValueNotifier<int>(0);

  /// 妖王罗盘：bearing=指向据点的世界弧度；progress=据点接近度（0→1）。
  final ValueNotifier<double> bearing = ValueNotifier<double>(0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// 无妖章回（原著无妖，区域 boss_code=NULL）：hasBoss=false 时罗盘位
  /// 切换为坚持通关倒计时（surviveLeft=剩余秒）。
  final ValueNotifier<bool> hasBoss = ValueNotifier<bool>(true);
  final ValueNotifier<int> surviveLeft = ValueNotifier<int>(0);

  /// 法宝槽位变更计数：入槽/升级后 +1，槽栏监听重建（读 controller 槽表）。
  final ValueNotifier<int> slotsRevision = ValueNotifier<int>(0);
}

/// 局内成长三选一选项（维度槽 + 被动加持 + 通用成长）。
enum JourneyUpgradeKind {
  slotLearn, // 习得新维度入空槽（[code] 载荷，Lv1）
  slotUpgrade, // 已有维度升级 +1（[code] 载荷，上限由配置驱动）
  passiveGrant, // 获得被动加持入被动槽（[code] 载荷，入槽即生效）
  moveSpeed,
  maxHp,
  regen,
  pickupRange,
}

class JourneyUpgradeChoice {
  final JourneyUpgradeKind kind;
  final String code; // 法宝载荷（passiveGrant 用，其余空串）
  final String title;
  final String desc;

  const JourneyUpgradeChoice(
    this.kind, {
    this.code = '',
    required this.title,
    required this.desc,
  });
}

/// 摇杆输入向量（长度 0~1，屏幕方向；屏幕上=西行方向）。
class JourneyBattleInput {
  Offset vector = Offset.zero;

  void reset() => vector = Offset.zero;
}

/// 结算结果（对局页组装功德明细用）。
class JourneyRunResult {
  final bool cleared;
  final int kills;
  final int meritFromCoins;
  final int meritClearBonus;
  final int durationSec;
  final int firstClearMerit;
  final int levelNo;
  final String levelTitle;

  const JourneyRunResult({
    required this.cleared,
    required this.kills,
    required this.meritFromCoins,
    required this.meritClearBonus,
    required this.durationSec,
    required this.firstClearMerit,
    required this.levelNo,
    required this.levelTitle,
  });

  int get meritTotal => meritFromCoins + meritClearBonus;
}
