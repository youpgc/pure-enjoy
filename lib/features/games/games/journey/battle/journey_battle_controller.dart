import 'package:flame/components.dart' show Vector2;
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
    Future<bool> Function(int cost)? onRevivePrompt,
    Future<bool> Function(String resultName)? onAlchemyPrompt,
  })  : onRevivePrompt = onRevivePrompt ?? _defaultRevivePrompt,
        onAlchemyPrompt = onAlchemyPrompt ?? _defaultAlchemyPrompt;

  final String themeColor;
  final void Function(int newLevel) onLevelUp;
  final void Function({
    required bool cleared,
    required int kills,
    required int meritFromCoins,
    required int meritClearBonus,
    required int durationSec,
  }) onFinished;
  final void Function(String bossName) onBossSpawn;

  /// 还魂复活确认（§3）：入参=还魂功德价；返回 true=已扣功德允许复活。
  /// 缺省实现=拒绝（对局页注入真实弹窗 + JourneyProgressService.spendRevive）。
  final Future<bool> Function(int cost) onRevivePrompt;

  /// 宝箱炼化确认（§6）：入参=炼化结果名；返回 true=确认炼化。
  /// 缺省实现=放弃（宝箱已消耗，引擎直接恢复运行）。
  final Future<bool> Function(String resultName) onAlchemyPrompt;

  static Future<bool> _defaultRevivePrompt(int cost) =>
      Future<bool>.value(false);
  static Future<bool> _defaultAlchemyPrompt(String resultName) =>
      Future<bool>.value(false);

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

/// 局外预注入（对局页组装）：五行天赋树线性增量 + 加强点能力标记。
///
/// 数值口径（伤害公式固定）：基础值 → 加百分比，百分比加法合流后
/// 单次乘算，不做乘法叠乘。天赋金/火层数走攻击力%（attackAmp），
/// 与武器增伤%（damageAmp，舍利子等）分桶展示。
class JourneyLoadout {
  final double attackAmp; // 攻击力%合计（天赋锐金/离火，加法合流）
  final double damageAmp; // 武器增伤%合计（1.0 基准，局内舍利子等续加）
  final double spinAmp; // 环绕转速加成注入
  final double armorFlat;
  final double bonusMaxHp;
  final double regenFlat;
  final double pickupRangeFlat;
  final double expAmp;
  final double critRateFlat; // 暴击率增量（引擎钳 ≤0.60）
  final double critDamageBonus; // 暴击伤害增量（引擎基准 1.5，钳 [1.0, 2.0]）

  /// 已点亮标志强化（sig 化形枝）效果键：wood=回复翻倍+生命+10%，
  /// earth=拾取磁吸全屏；其余系走数值字段。
  final Set<String> signatures;

  /// 已点亮加强点解锁的角色特殊能力（'ability_tang' 等；引擎按能力
  /// 标记挂对应钩子，永久生效）。
  final Set<String> abilities;

  const JourneyLoadout({
    this.attackAmp = 0,
    this.damageAmp = 0,
    this.spinAmp = 0,
    this.armorFlat = 0,
    this.bonusMaxHp = 0,
    this.regenFlat = 0,
    this.pickupRangeFlat = 0,
    this.expAmp = 1.0,
    this.critRateFlat = 0,
    this.critDamageBonus = 0,
    this.signatures = const <String>{},
    this.abilities = const <String>{},
  });
}

/// 单个计时槽的冷却快照（HUD 时钟蒙层数据源）：
/// remain=距下次触发/就绪的剩余秒数，total=周期或冷却总秒数。
/// 周期类（玉净瓶/回元/护体）随计时推进 remain 递减，归零即触发并重置；
/// 冷却类（三根毫毛）触发时置满，递减归零即就绪。
class JourneySlotCooldown {
  const JourneySlotCooldown(this.remain, this.total);

  final double remain;
  final double total;

  /// 蒙层比例（0=无蒙层/就绪，1=满蒙层/刚触发）。
  double get progress =>
      total > 0 ? (remain / total).clamp(0.0, 1.0) : 0.0;

  /// 文案倒计时取整秒（向上取整，归零前始终显示至少 1）。
  int get secs => remain.ceil();
}

/// 局内 HUD 数值源（ValueNotifier 直读，组件化 HUD 订阅）。
class JourneyBattleHud {
  final ValueNotifier<double> hp = ValueNotifier<double>(100);
  final ValueNotifier<double> maxHp = ValueNotifier<double>(100);
  /// 护体金光护盾值（HUD 血条下方白线按 shield/maxHp 比例展示）。
  final ValueNotifier<double> shield = ValueNotifier<double>(0);

  /// 玩家负面状态剩余秒数（HUD 血条行角标）：定身=百眼魔君金光缚身，
  /// 禁疗=蝎子精倒马毒桩。引擎按 0.1s 粒度去重写入，0=已解除。
  final ValueNotifier<double> rootRemain = ValueNotifier<double>(0);
  final ValueNotifier<double> healBlockRemain = ValueNotifier<double>(0);
  final ValueNotifier<double> exp = ValueNotifier<double>(0);
  final ValueNotifier<double> expNeed = ValueNotifier<double>(12);
  /// 满级累计展示态：满级瞬间经验归零，此后经验继续入账并封顶数值上限，
  /// HUD 分母改显文字 max、分子展示累计值，经验条保持充满；
  /// expNeed 仍保留本级需求，供上限突破时退出累计态恢复常规曲线。
  final ValueNotifier<bool> expMaxed = ValueNotifier<bool>(false);
  final ValueNotifier<int> level = ValueNotifier<int>(1);

  /// 当前境界名号（随境界突破切换，引擎同步；顶部状态面板首行展示）。
  final ValueNotifier<String> realmTitle = ValueNotifier<String>('');

  /// 经验条两段式动画的归零计数：每次「充满→归零」+1，进度条监听后按
  /// 新 key 重建 TweenAnimationBuilder（重建即落位，无从满倒退的反向
  /// tween）。写入口径见引擎 exp part。
  final ValueNotifier<int> expReset = ValueNotifier<int>(0);

  /// 妖王伏诛标记：末场击杀后置 true（暂停面板「提前结算」按钮与
  /// 伏诛抉择弹层的显隐依据）。
  final ValueNotifier<bool> bossDefeated = ValueNotifier<bool>(false);
  final ValueNotifier<int> kills = ValueNotifier<int>(0);
  final ValueNotifier<int> meritCoins = ValueNotifier<int>(0);

  /// 妖王罗盘：bearing=指向据点的世界弧度；progress=据点接近度（0→1）。
  final ValueNotifier<double> bearing = ValueNotifier<double>(0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// 无妖章回罗盘位口径：每日游历不展示通关条件/提示（进图即亮「功成」、
  /// 随时可结算）；无妖主线章回=西行里程（travelBased=true 时用 travelLeft=
  /// 剩余里数，按玩家实际位移累计，挂机不可达成）。
  final ValueNotifier<bool> hasBoss = ValueNotifier<bool>(true);

  /// 西行里程口径（无妖主线章回）：travelBased=true 时罗盘位改展示
  /// travelLeft（剩余里数）。
  final ValueNotifier<bool> travelBased = ValueNotifier<bool>(false);
  final ValueNotifier<int> travelLeft = ValueNotifier<int>(0);

  /// 法宝槽位变更计数：入槽/升级后 +1，槽栏监听重建（读 controller 槽表）。
  final ValueNotifier<int> slotsRevision = ValueNotifier<int>(0);

  /// 计时槽冷却快照表：code → 剩余/总秒数。驱动槽位顺时针蒙层与秒数文案。
  /// 收录全部带计时的槽（回元/护体/玉净瓶/三根毫毛），由引擎逐帧按秒去重
  /// 写入；就绪或槽位消失时移除该项，蒙层随之隐藏。
  final ValueNotifier<Map<String, JourneySlotCooldown>> slotCooldowns =
      ValueNotifier<Map<String, JourneySlotCooldown>>(
          const <String, JourneySlotCooldown>{});

  /// 等待玩家接管摇杆：点继续/选卡后世界仍时停，按下摇杆才恢复。
  final ValueNotifier<bool> awaitingJoystick = ValueNotifier<bool>(false);

  /// 里程碑播报（milestone 参照物接近触发，同一参照物只报一次；
  /// null=无播报，对局页监听展示后可清回 null）。
  final ValueNotifier<String?> milestoneText = ValueNotifier<String?>(null);

  /// 横幅源（节点11）：开场难名/妖王降临/伏诛写入；
  /// 覆盖层监听后每次写入各成一条、独立计时，不与其他横幅互相覆盖。
  final ValueNotifier<String?> banner = ValueNotifier<String?>(null);

  /// 妖王大血条组（节点11）：一条=一只妖王，最多三条，自上而下叠加。
  /// 引擎维护稳定序：新进一律从队尾入列，在列妖王不因走位重排，退出后
  /// 下方顺位上移；优先级仅用于满额淘汰最弱者与同批入场的先后。
  /// 空列表=当前无妖王横幅。
  final ValueNotifier<List<JourneyBossHudBar>> bossBars =
      ValueNotifier<List<JourneyBossHudBar>>(const <JourneyBossHudBar>[]);

  /// 受击脉冲计数：玩家每次有效受击 +1，屏幕边框呼吸灯据此重启动画。
  final ValueNotifier<int> hitPulse = ValueNotifier<int>(0);

  /// 主线章回妖王已降临且未伏诛：罗盘导航的显隐依据，由 spawns 置位、
  /// lifecycle 伏诛时复位；小地图标记与小地图快照解耦，不读本字段。
  final ValueNotifier<bool> bossPresent = ValueNotifier<bool>(false);

  /// 妖王降临倒计时（秒）：主线首次降临与多场战复活冷却共用此位，由引擎
  /// 从计时起点持续写入剩余秒数（罗盘位展示「妖王降临 · Xs」），
  /// 归零复活/降临后引擎置 0 自然隐藏；无妖章回与无尽妖潮恒为 0。
  final ValueNotifier<int> bossSpawnIn = ValueNotifier<int>(0);

  /// 妖王罗盘·据点基准距离（出生点到据点，进关时引擎写入一次）：
  /// 接近度口径的换算基准（progress=1-实际距离/基准）；罗盘里数展示
  /// 已改用 bossDistWorld 实际距离，不再经基准反推。
  final ValueNotifier<double> bossStartDist = ValueNotifier<double>(1);

  /// 妖王罗盘·距妖王实际距离（世界单位）：引擎每帧上报（带去重阈值）。
  /// 玩家绕路时实际距离可能大于出生基准，罗盘里数=此值÷25 直接换算，
  /// 不受接近度钳制影响（1 里=25 世界单位）。
  final ValueNotifier<double> bossDistWorld = ValueNotifier<double>(0);

  /// 无尽妖潮当前波数（1 起；0=非无尽模式，罗盘位回退坚持倒计时口径）。
  final ValueNotifier<int> endlessWave = ValueNotifier<int>(0);

  /// 小地图点阵快照（节点11）：引擎每 0.25s 采样一次，无变化不写；
  /// null=尚未采样（覆盖层画空窗）。
  final ValueNotifier<JourneyMinimapData?> minimap =
      ValueNotifier<JourneyMinimapData?>(null);
}

/// 单条妖王大血条的展示快照。[key] 为对应妖王实体的引用，横幅以它作
/// ValueKey，保证同一妖王在顺位变化时动画状态不串给别的妖王。
class JourneyBossHudBar {
  const JourneyBossHudBar({
    required this.key,
    required this.name,
    required this.ratio,
    required this.hp,
    required this.maxHp,
  });

  final Object key;
  final String name;
  final double ratio;
  final int hp;
  final int maxHp;
}

/// 小地图采样快照（节点11）：怪点=相对玩家的世界偏移（≤span，上限 60）；
/// bossPositions=全部存活妖王相对玩家的偏移（超范围贴窗缘示方向）——
/// 主线据点妖王与妖王潮多妖王同源采样，大红点逐妖王绘制。
class JourneyMinimapData {
  /// 玩家世界坐标（备用参考位；渲染以偏移为准）。
  final Vector2 playerPos;

  /// 存活妖王相对玩家的偏移集合（空 = 无妖王在场/已清剿）。
  final List<Vector2> bossPositions;

  /// 相对玩家的怪物偏移（上限 60，均在 span 内）。
  final List<Vector2> monsterOffsets;

  /// 采样半径（世界单位）。
  final double span;

  const JourneyMinimapData({
    required this.playerPos,
    required this.monsterOffsets,
    this.bossPositions = const <Vector2>[],
    this.span = 1000,
  });
}

/// 三选一候选类别：用于类别层权重抽卡（维度槽/法宝/触发效果/基础值）。
enum JourneyChoiceCategory { slot, passive, effect, base }

/// 局内成长三选一选项（维度槽 + 被动加持 + 通用成长）。
enum JourneyUpgradeKind {
  slotLearn, // 习得新维度入空槽（[code] 载荷，Lv1）
  slotUpgrade, // 已有维度升级 +1（[code] 载荷，上限由配置驱动）
  passiveGrant, // 获得被动加持入被动槽（[code] 载荷，入槽即生效）
  effectGrant, // 触发型法宝激活（[code] 载荷，命中/受击/暴击时结算）
  moveSpeed,
  maxHp,
  regen,
  pickupRange,
  attack, // 基础攻击力成长（累计达上限后不再入池）
}

class JourneyUpgradeChoice {
  final JourneyUpgradeKind kind;
  /// 维度槽/法宝编码：按 kind 携带 code，用于复用同源图标与应用加成；
  /// 通用成长项（攻击/移速/生命等）为空串。
  final String code;
  final String title;
  final String desc;

  /// 类别层抽取归属（权重管理的最小粒度；类内均匀随机抽取）。
  final JourneyChoiceCategory category;

  const JourneyUpgradeChoice(
    this.kind, {
    this.code = '',
    required this.title,
    required this.desc,
    this.category = JourneyChoiceCategory.base,
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
