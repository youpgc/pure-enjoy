// dart:async 以别名引入：flame/components 同名导出 Flame Timer（double 秒），
// 经验条两段式动画的 Dart 定时器统一走 dart_async.Timer（exp part）。
import 'dart:async' as dart_async;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

import '../../../../../services/error_reporter.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_seed.dart';
import 'journey_battle_controller.dart';
import 'journey_sprites.dart';

part 'journey_engine_world.dart';
part 'journey_engine_player.dart';
part 'journey_engine_monsters.dart';
part 'journey_engine_weapons.dart';
part 'journey_weapon_render.dart';
part 'journey_engine_choices.dart';
part 'journey_engine_kit.dart';
part 'journey_engine_lifecycle.dart';
part 'journey_engine_fx.dart';
part 'journey_engine_loot.dart';
part 'journey_engine_damage.dart';
part 'journey_engine_spawns.dart';
part 'journey_engine_interact.dart';
part 'journey_engine_grid.dart';
part 'journey_engine_exp.dart';
part 'journey_engine_minimap.dart';

/// 西行·Flame 对局主类。
///
/// 平铺大地图全向自由探索；周身环绕法宝周期收割；妖王驻守地图据点，
/// 循罗盘找到并击杀通关。接触伤害全局 0.5s 节拍。
class JourneyFlameGame extends FlameGame
    with JourneyWeaponMixin, JourneyDamageTickMixin, JourneyLootMixin,
        JourneySpawnMixin
    implements JourneyWeaponHost {
  JourneyFlameGame({
    required this.level,
    required this.character,
    required this.controller,
    this.loadout = const JourneyLoadout(),
    this.monsterCap = 120,
    this.config,
    this.runtime = const JourneyLevelRuntime(),
  });

  final JourneyLevelModel level;
  final JourneyCharacterModel character;
  @override
  final JourneyBattleController controller;
  final JourneyLoadout loadout;

  /// 配置快照引用：怪物池/区域（boss_code）配置化数据源；null=内置兜底。
  final JourneyConfigSnapshot? config;

  /// 单关运行时配置（波次/热区/参照物，按 level_id 从远端拉取）。
  /// 空配置 → 引擎走兜底全向刷怪。
  final JourneyLevelRuntime runtime;

  /// 同屏怪物实体上限：由远端配置（journey_globals.monster_cap）下发，
  /// 兜底 120 仅为配置未就绪时的模拟值。
  final int monsterCap;

  /// 平铺大地图边长：全向可走，规模随关号递增（配置化随 SQL 批次落地）；
  /// 无尽妖潮用小地图（2000）保持遭遇密度。
  double get worldSize =>
      _isEndless(this) ? 2000 : 3200 + level.levelNo * 160.0;

  /// 屏幕逻辑宽度（宿主视图）：臂展钳制与百分比展示的基准。
  double get screenLogicalWidth {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return 400;
    return view.physicalSize.width / view.devicePixelRatio;
  }

  /// 臂展直径上限 = 屏幕逻辑宽 - 40（左右各留 20px 空余）。
  @override
  double get maxArmDiameter => screenLogicalWidth - 40;

  /// 妖王据点坐标（开局确定性生成，远离出生点）。
  late final Vector2 bossPos;

  /// 进局时出生点到据点的距离（罗盘接近度基准）。
  double bossStartDist = 1;

  @override
  late JourneyPlayerComponent player;
  final List<JourneyMonsterComponent> monsters = <JourneyMonsterComponent>[];
  final List<JourneyPickupComponent> pickups = <JourneyPickupComponent>[];

  late List<JourneyMonsterModel> pool;
  JourneyMonsterModel? bossModel;
  JourneyMonsterComponent? boss;

  late final math.Random rng = math.Random(level.levelNo);

  // ---- 运行状态 ----
  double _elapsed = 0, _exp = 0, _expNeed = 12;
  int _charLv = 1, _kills = 0, _meritCoins = 0;
  bool _ended = false;
  bool get isEnded => _ended;

  /// 待结算的升级次数（连升时不堆叠弹窗，逐个出卡）。
  int _pendingLevelUps = 0;

  /// 升级选卡导致的引擎暂停（区别于暂停键），最后一张选完才恢复。
  bool _pausedByLevelUp = false;

  /// 引擎当前是否因升级选卡而暂停（暂停键恢复时需据此跳过 resume，
  /// 否则选卡期间世界会被误恢复运行）。
  bool get isPausedForLevelUp => _pausedByLevelUp;

  /// 当前妖王战场次（0-based；bossFights>1 时打完一场增强再战）。
  int _bossStage = 0;

  /// 妖王伏诛（末场击杀后）：等待玩家抉择「结算离开/继续游玩」；
  /// 继续游玩后无妖王（罗盘距离导航已移除），循环刷怪照常成长。
  bool _bossDefeated = false;

  /// 无尽妖潮末波终局结算已排程（防每帧重复挂延时定时器）。
  bool _endlessSettleScheduled = false;

  /// 妖王是否已伏诛（暂停面板「提前结算」按钮显隐依据）。
  bool get bossDefeated => _bossDefeated;

  /// 悟空「大圣威压」：击杀触发的短暂转速增益剩余时间。
  double _wukongBuffTimer = 0;

  // ---- 角色专属天赋·特殊能力（主系标志分支满级解锁，loadout 注入）----
  /// 已解锁特殊能力标记（'ability_tang' 等；引擎钩子按标记生效）。
  final Set<String> abilities = <String>{};

  /// 是否持有某角色特殊能力（'tang'→'ability_tang'）。
  bool hasAbility(String char) => abilities.contains('ability_$char');

  /// 金身佛光（tang）：周期回血计时 / 每局首次致命伤免死已用标记。
  double _jinshenTimer = 0;
  bool _jinshenFatalUsed = false;

  /// 身外身法（wukong）：击杀计数（每 30 清零）/ 临时增益剩余时间。
  int _shenfenKills = 0;
  double _shenfenTimer = 0;

  /// 铜皮铁骨（bajie）：受击后减伤窗口剩余时间（3s）。
  double _bajieGuard = 0;

  /// 伏魔重击（shaseng）：蓄力计时 / 充能就绪标记（每 20s 一次）。
  static const double _fumoChargeSec = 20;
  double _fumoTimer = 0;
  bool _fumoCharged = false;

  /// 西游扩展批（被动/特效法宝）：
  /// 三根毫毛免死已用标记（单局一次）/ 金刚琢与阴阳二气瓶计时。
  bool _maoUsed = false;
  double _zhuoTimer = 0;
  double _pingTimer = 0;

  /// 环绕旋转方向（局外设置）：1=顺时针，-1=逆时针；对局页进局时注入。
  double spinDirection = 1.0;

  // ---- 经验条两段式动画（exp part 驱动）----
  /// 待播放「充满→归零」的升级段数（连升排队，逐段播放）。
  int _expFillPending = 0;

  /// 当前段充满→归零的定时器（null=无段在播；UI 写入口径见 exp part）。
  dart_async.Timer? _expFillTimer;

  /// 小地图采样计时（minimap part）：0.25s 一次。
  double _minimapTimer = 0;

  // ---- 暴击体系（§8）----
  /// 暴击率（局外天赋注入+局内暴击维度槽，引擎钳 ≤0.60）与暴击伤害
  /// 乘区（基准 1.5，天赋化形/局内暴伤槽增量，钳 [1.0, 2.0]）。
  @override
  double critRate = 0;
  @override
  double critDamage = 1.5;

  /// 实际伤害乘区：伤害加成钳 ≤+200%（damageAmp 1.0 基准，超过不再增长）。
  double get damageMult => 1.0 + (damageAmp - 1.0).clamp(0.0, 2.0);

  /// 法宝数值参数（journey_weapon_params 后台配置；行缺失回落 fallback）。
  double weaponParam(String code, String key, double fallback) =>
      config?.weaponParam(code, key, fallback) ?? fallback;

  /// 妖王能力参数（journey_monster_params 后台配置；行缺失回落 fallback）。
  double monsterParam(String monsterCode, String key, double fallback) =>
      config?.monsterParam(monsterCode, key, fallback) ?? fallback;

  /// 维度槽定义缓存（slotDefMap 惰性构建一次；对局内配置不变）。
  Map<String, JourneySlotDefModel>? _slotDefCache;

  /// 维度槽定义（code 匹配；含远端空表回落内置种子）。
  JourneySlotDefModel? slotDefOf(String code) {
    final map = _slotDefCache ??= config?.slotDefMap() ?? const {};
    return map[code];
  }

  /// 维度槽每级数值（value_per_level 后台配置；0/缺失回落内置兜底）。
  @override
  double slotValue(String code, double fallback) {
    final v = slotDefOf(code)?.valuePerLevel ?? 0;
    return v > 0 ? v : fallback;
  }

  /// 属性面板展示口径：最终角速度（含 5 圈/秒=10π 钳制，与环绕推进同源）。
  double get displayAngularSpeed =>
      ((weaponArm?.speedBase ?? 0) * spinAmp).clamp(0.0, 10 * math.pi);

  // ---- 特效触发法宝（§6）----
  /// 已激活的触发型法宝（kunxian_rope/fanshang_thorns/baoji_thunder）。
  final Set<String> effectWeapons = <String>{};

  /// 特效渲染层（浮动文字/闪电连线/破坏残屑），world 内置顶。
  late final JourneyFxLayer fxLayer = JourneyFxLayer(this);

  /// 空间哈希网格（节点12 性能）：每帧重建，武器/接触伤害只查附近候选。
  final JourneySpatialGrid spatialGrid = JourneySpatialGrid();

  // ---- 参照物运行时状态（§7/§2）----
  /// 参照物破坏标记（下标对齐 runtime.mapObjects）。
  late List<bool> _mapObjDead;

  /// 可击破参照物剩余血量（仅 kind=breakable 且 hp>0 的行；
  /// 行 hp<=0 未入表=一击破坏）。
  final Map<int, double> _mapObjHp = <int, double>{};

  /// 已触发的里程碑参照物（同一参照物只报一次）。
  final Set<int> _milestoneHit = <int>{};

  /// 参照物扇叶命中冷却（per-object 0.3s，对齐 orbHitCd 口径；
  /// 无冷却时高伤一帧即破坏，hp 配置失去「累积破坏」意义）。
  final Map<int, double> _mapObjHitCd = <int, double>{};

  // ---- 还魂复活（§3）/ 宝箱炼化（§6）----
  /// 本局剩余还魂次数（还魂丹口径：功德直接购买，单局 1 次）。
  int revivesLeft = 1;

  /// 还魂确认弹窗占用标记（防 takeDamage 重入连弹）。
  bool _revivePending = false;

  /// 本局是否已炼化（宝箱流水线一次性；渲染变化由对局页承接）。
  bool evolved = false;

  /// 炼化伤害倍率（配方 evo_mult 后台可配，炼化时写入；
  /// 品阶刷新持续乘算，保证增幅不因升级刷新而丢失）。
  double evoMult = 1.6;

  /// 炼化确认弹窗占用标记。
  bool _alchemyPending = false;

  // ---- 周身环绕武器（电风扇模型）----
  /// 初始武器（角色特性法宝，1 件）从角色容器延伸到外环旋转收割。
  /// 6 主动槽=维度槽（属性/特效）：初始武器占 1 特效槽，空槽由三选一
  /// 「习得」卡填入，各维度带等级上限（journey_weapon_slots 配置）；
  /// 被动加持占被动槽 6 格。
  @override
  JourneyWeaponArm? weaponArm;

  /// 初始武器编码（环绕渲染取该武器纯内容 SVG）。
  late final String weaponCode = character.weaponCode;

  /// 武器维度槽（≤6：初始特效槽 + 习得维度）。
  @override
  final List<JourneyWeaponSlot> weaponSlots = <JourneyWeaponSlot>[];
  final List<String> passiveSlotCodes = <String>[]; // 被动槽（≤6）

  @override
  double spinAmp = 1.0; // 全局转速加成乘区

  double get orbSpeed => spinAmp;

  /// 扇叶数：1 条本体扇叶 + 分身槽每级 1 条分身（等角间隔，命中同效；
  /// 兜底 seed 无 clone 行时=1）；身外身法增益期间临时 +1 分身扇叶。
  /// 单局上限：分身≤5，总扇叶（本体+分身）≤6（运营可配 clone 上限 5）。
  int get bladeCount =>
      math.min(1 + slotLevel('clone') + (_shenfenTimer > 0 ? 1 : 0), 6);

  // ---- 局内成长（三选一应用的加成）----
  @override
  double damageAmp = 1.0;
  double moveSpeedAmp = 1.0;

  /// 经验获取乘区（八戒「贪食」光环）。
  double expAmp = 1.0;

  /// 局内强度随时间缓升 × 关卡难度乘区（怪物增强为主轴）。
  double get buffMult =>
      (1.0 + (_elapsed / 60.0) * (0.6 + level.levelNo * 0.05)) * levelMult;

  /// 关卡难度乘区：game_levels.difficulty（后台可调，缺省=难号）驱动，
  /// 每点难度 +6%；替代原先散落的 levelNo*0.03 等零散口径，全关统一乘区。
  double get levelMult => 1.0 + level.difficulty * 0.06;

  /// 角色法宝内置基准伤害（分级表缺失时的兜底，_buildStarterArm 写入）。
  double weaponBaseDamage = 14.0;

  @override
  Future<void> onLoad() async {
    pool = _buildPool(this);
    // 每日游历按图怪物池（journey_daily_maps.monster_pool，后台逐图可配；
    // 空=内置全怪池兜底）：非空时过滤刷怪池（妖王本就被 _buildPool 排除）；
    // 过滤后空池（怪种失效/误配妖王）回落全池并上报，保「配置断裂可玩」
    if (_isDaily(this)) {
      final codes = config?.dailyMapOf(level.regionCode)?.monsterPool;
      if (codes != null && codes.isNotEmpty) {
        final filtered =
            pool.where((m) => codes.contains(m.code)).toList(growable: true);
        if (filtered.isNotEmpty) {
          pool = filtered;
        } else {
          ErrorReporter.reportMessage(
            '每日游历 ${level.regionCode} 怪物池全部失效，回落全怪池',
            module: 'games',
            level: 'warning',
          );
        }
      }
    }
    bossModel = _bossOfRegion(this);
    initWaveProgress(this);

    // 妖王据点：确定性随机方位，距出生点（地图中心）0.32~0.45 倍边长
    final size = worldSize;
    final angle = rng.nextDouble() * math.pi * 2;
    final dist = size * (0.32 + rng.nextDouble() * 0.13);
    bossPos = Vector2(
      (size / 2 + math.cos(angle) * dist).clamp(320.0, size - 320),
      (size / 2 + math.sin(angle) * dist).clamp(320.0, size - 320),
    );

    // 使用 FlameGame 自带的 world/camera（自建会与 game.world/game.camera
    // 错位成两套坐标系：实体进默认世界、相机查错相机 → 实体全部不可见）。
    camera.viewfinder.anchor = Anchor.center;
    // 相机边界钳制交由 Flame 内置 BoundedPositionBehavior：整个视口不出
    // 世界矩形（防黑边）。该行为 priority 1000，每帧在 follow 修正之后
    // 生效，手写在组件 update 里覆盖 viewfinder.position 会被 follow 拉回。
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, size, size),
      considerViewport: true,
    );

    // 参照物运行时状态：破坏标记 + 可击破血量表（hp<=0 行视为一击破坏）
    _mapObjDead = List<bool>.filled(runtime.mapObjects.length, false);
    for (var i = 0; i < runtime.mapObjects.length; i++) {
      final o = runtime.mapObjects[i];
      if (o.kind == 'breakable' && o.hp > 0) {
        _mapObjHp[i] = o.hp.toDouble();
      }
    }

    final bg = JourneyWorldBackground(
      worldSize: size,
      themeColor: controller.themeColor,
      seed: level.levelNo,
      bossPos: bossPos,
      mapObjects: runtime.mapObjects,
      isObjDestroyed: (i) => _mapObjDead[i],
    );
    world.add(bg);

    player = JourneyPlayerComponent(
      game: this,
      position: Vector2(size / 2, size / 2),
      maxHp: character.baseHp.toDouble(),
    );
    world.add(player);
    world.add(JourneyOrbitWeapons(game: this));
    world.add(fxLayer);
    camera.follow(player);

    spawnBossAtPost(this);
    seedInitialPack(this);
    // 面包屑铜钱：沿出生点→据点直线均匀撒 6 枚（无妖章回落随机方向）
    _seedBreadcrumbCoins();
    // 无尽妖潮：进场即亮「结算」按钮（随时可主动结算，按当前进度入账）；
    // HUD 通知调度到帧尾（onLoad 处于构建期，防 markNeedsBuild during build）
    if (_isEndless(this)) {
      _bossDefeated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.hud.bossDefeated.value = true;
      });
    }
    // 先建立角色武器臂（分身起步 1），再叠光环与天赋注入
    _buildStarterArm();
    _applyCharacterKit();
    _applyLoadout();

    // onLoad 发生于 GameWidget 挂载（构建）期：HUD 通知一律调度到帧尾，
    // 防 ValueListenableBuilder markNeedsBuild during build 异常
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.hud.maxHp.value = player.maxHp;
      controller.hud.hp.value = player.hp;
      // 无妖章回（原著无妖）：HUD 罗盘位切换为坚持通关倒计时
      controller.hud.hasBoss.value = bossModel != null;
      if (bossModel == null) {
        controller.hud.surviveLeft.value = surviveTargetSec;
      }
      controller.hud.bossStartDist.value = bossStartDist;
    });
    bossStartDist = (bossPos - player.position).length;
    // 罗盘「里」换算基准（距妖王 = 接近度 × 基准距离 ÷25，1 里=25 单位）
    debugPrint('罗盘基准: lv=${level.levelNo} boss=${bossModel?.code} '
        'startDist=${bossStartDist.toStringAsFixed(0)} '
        'bossPos=$bossPos player=${player.position} worldSize=$size');
  }

  @override
  void update(double dt) {
    // 布局期防护：GameWidget 布局期的 resize 空刷（dt=0 tick）可能同步跑
    // update，此时写 HUD ValueNotifier 会触发 markNeedsBuild during build
    // （错误日志#1）；该 tick 无推进，直接跳过。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    // dt=0 的空 tick 来自 GameWidget 布局期的 resize 刷新（发生在 Flutter
    // build 阶段内）。引擎状态全部是积分型（计时器累加/位移步进），0 步进
    // 无需刷新；若照常执行，拾取判定/妖王生成/通关结算等副作用会在 build
    // 阶段弹出 UI 或触发 HUD 通知，导致 markNeedsBuild during build 异常。
    if (dt <= 0) return;
    super.update(dt);
    if (_wukongBuffTimer > 0) {
      _wukongBuffTimer -= dt;
    }
    // 特殊能力计时递减：身外身法增益窗口 / 铜皮铁骨减伤窗口
    if (_shenfenTimer > 0) _shenfenTimer -= dt;
    if (_bajieGuard > 0) _bajieGuard -= dt;
    if (_ended || _pendingLevelUps > 0) return;
    _elapsed += dt;

    // 伏魔重击（shaseng）：每 20s 蓄力一次，就绪后停表待下一次命中消耗
    if (hasAbility('shaseng') && !_fumoCharged) {
      _fumoTimer += dt;
      if (_fumoTimer >= _fumoChargeSec) {
        _fumoCharged = true;
        _fumoTimer = 0;
      }
    }

    // 无妖章回：坚持满时长即满足通关条件（不主动结算，由玩家决定）；
    // 满足后罗盘倒计时停 0，结算按钮亮起，游玩照常
    if (bossModel == null && !_isEndless(this)) {
      final left = (surviveTargetSec - _elapsed).ceil().clamp(0, surviveTargetSec);
      if (left != controller.hud.surviveLeft.value) {
        controller.hud.surviveLeft.value = left;
      }
      if (_elapsed >= surviveTargetSec && !_bossDefeated) {
        _markClearedAvailable('坚持功成');
      }
    }

    updateSpawns(this, dt);
    // 空间哈希（节点12）：刷怪后每帧重建，供武器/接触伤害查询附近候选
    spatialGrid.rebuild(monsters);
    updateWeapons(this, dt);
    updateDamageTick(this, dt);
    checkMilestones();
    _sampleMinimap(dt);

    // 清理已死亡/已拾取实体
    monsters.removeWhere((m) => m.isDead);
    pickups.removeWhere((p) => p.isMounted == false);
  }

}
