import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Colors;

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_seed.dart';
import 'journey_battle_controller.dart';
import 'journey_sprites.dart';

part 'journey_engine_world.dart';
part 'journey_engine_monsters.dart';
part 'journey_engine_weapons.dart';
part 'journey_engine_kit.dart';
part 'journey_engine_loot.dart';
part 'journey_engine_damage.dart';
part 'journey_engine_spawns.dart';

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

  /// 平铺大地图边长：全向可走，规模随关号递增（配置化随 SQL 批次落地）。
  double get worldSize => 3200 + level.levelNo * 160.0;

  /// 妖王据点坐标（开局确定性生成，远离出生点）。
  late final Vector2 bossPos;

  /// 进局时出生点到据点的距离（罗盘接近度基准）。
  double bossStartDist = 1;

  @override
  late JourneyPlayerComponent player;
  final List<JourneyMonsterComponent> monsters = <JourneyMonsterComponent>[];
  final List<JourneyPickupComponent> pickups = <JourneyPickupComponent>[];

  late final List<JourneyMonsterModel> pool;
  JourneyMonsterModel? bossModel;
  JourneyMonsterComponent? boss;

  late final math.Random rng = math.Random(level.levelNo);

  // ---- 运行状态 ----
  double _elapsed = 0;
  double _exp = 0;
  double _expNeed = 12;
  int _charLv = 1;
  int _kills = 0;
  int _meritCoins = 0;
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

  /// 悟空「大圣威压」：击杀触发的短暂转速增益剩余时间。
  double _wukongBuffTimer = 0;

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

  /// 扇叶数：定稿=单武器单扇叶，维度槽只成长属性与特效，不加扇叶
  /// （保持「一件武器」口径）。
  int get bladeCount => 1;

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

  /// 转速加成上限：默认 1.60；水系标志层「玄水·流转」突破至 1.75。
  @override
  double get spinCap =>
      loadout.signatures.contains('signature_water') ? 1.75 : 1.60;

  /// 角色法宝内置基准伤害（分级表缺失时的兜底，_buildStarterArm 写入）。
  double weaponBaseDamage = 14.0;

  @override
  Future<void> onLoad() async {
    pool = _buildPool(this);
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

    final bg = JourneyWorldBackground(
      worldSize: size,
      themeColor: controller.themeColor,
      seed: level.levelNo,
      bossPos: bossPos,
      mapObjects: runtime.mapObjects,
    );
    world.add(bg);

    player = JourneyPlayerComponent(
      game: this,
      position: Vector2(size / 2, size / 2),
      maxHp: character.baseHp.toDouble(),
    );
    world.add(player);
    world.add(JourneyOrbitWeapons(game: this));
    camera.follow(player);

    spawnBossAtPost(this);
    seedInitialPack(this);
    // 先建立角色武器臂（分身起步 1），再叠光环与天赋注入
    _buildStarterArm();
    _applyCharacterKit();
    _applyLoadout();

    controller.hud.maxHp.value = player.maxHp;
    controller.hud.hp.value = player.hp;
    // 无妖章回（原著无妖）：HUD 罗盘位切换为坚持通关倒计时
    controller.hud.hasBoss.value = bossModel != null;
    if (bossModel == null) {
      controller.hud.surviveLeft.value = surviveTargetSec;
    }
    bossStartDist = (bossPos - player.position).length;
  }

  @override
  void update(double dt) {
    // dt=0 的空 tick 来自 GameWidget 布局期的 resize 刷新（发生在 Flutter
    // build 阶段内）。引擎状态全部是积分型（计时器累加/位移步进），0 步进
    // 无需刷新；若照常执行，拾取判定/妖王生成/通关结算等副作用会在 build
    // 阶段弹出 UI 或触发 HUD 通知，导致 markNeedsBuild during build 异常。
    if (dt <= 0) return;
    super.update(dt);
    if (_wukongBuffTimer > 0) {
      _wukongBuffTimer -= dt;
    }
    if (_ended || _pendingLevelUps > 0) return;
    _elapsed += dt;

    // 无妖章回：坚持满时长即功成（罗盘位显示剩余秒）
    if (bossModel == null) {
      final left = (surviveTargetSec - _elapsed).ceil().clamp(0, surviveTargetSec);
      if (left != controller.hud.surviveLeft.value) {
        controller.hud.surviveLeft.value = left;
      }
      if (_elapsed >= surviveTargetSec) {
        _finish(cleared: true);
        return;
      }
    }

    updateSpawns(this, dt);
    updateWeapons(this, dt);
    updateDamageTick(this, dt);

    // 清理已死亡/已拾取实体
    monsters.removeWhere((m) => m.isDead);
    pickups.removeWhere((p) => p.isMounted == false);
  }

  // ---- 伤害/击杀（damage part 调用）----
  void onMonsterKilled(JourneyMonsterComponent m) {
    _kills++;
    controller.hud.kills.value = _kills;

    // 妖王固定功德入账（merit_drop 配置列，计入铜钱明细）
    if (m.model.meritDrop > 0) {
      addMeritCoins(m.model.meritDrop);
    }

    // 悟空「大圣威压」：击杀 20% 概率触发 3 秒攻速增益
    if (character.code == 'wukong' && rng.nextDouble() < 0.20) {
      _wukongBuffTimer = 3.0;
    }

    spawnLoot(this, m);

    // 多场妖王战（如「三打白骨精」）：打完一场增强再战，末场才通关
    if (m == boss && !_ended) {
      final totalFights = level.bossFights > 1 ? level.bossFights : 1;
      if (_bossStage < totalFights - 1) {
        _bossStage++;
        respawnBoss(this);
      } else {
        _finish(cleared: true);
      }
    }
  }

  void gainExp(double amount) {
    _exp += amount * expAmp;
    while (_exp >= _expNeed) {
      _exp -= _expNeed;
      _charLv++;
      _expNeed = 12 + _charLv * 7;
      _pendingLevelUps++;
      _refreshWeaponGrade(); // 法宝分级：品阶随角色等级提升
    }
    controller.hud.level.value = _charLv;
    controller.hud.exp.value = _exp;
    controller.hud.expNeed.value = _expNeed;
    if (_pendingLevelUps > 0 && !_pausedByLevelUp) {
      // 真暂停：选卡期间世界完全静止（怪物不逼近、节拍不走）
      _pausedByLevelUp = true;
      pauseEngine();
      controller.onLevelUp(_charLv, paused: true);
    }
  }

  /// 三选一选定：应用加成；仍有余级则继续弹卡，否则恢复运行。
  /// （候选池构建见 weapons part 的 drawChoices，本方法只结算。）
  void applyUpgrade(JourneyUpgradeChoice choice) {
    switch (choice.kind) {
      case JourneyUpgradeKind.slotLearn:
        learnSlot(choice.code);
        break;
      case JourneyUpgradeKind.slotUpgrade:
        upgradeSlot(choice.code);
        break;
      case JourneyUpgradeKind.passiveGrant:
        _grantPassiveWeapon(choice.code);
        break;
      case JourneyUpgradeKind.moveSpeed:
        moveSpeedAmp += 0.09;
        break;
      case JourneyUpgradeKind.maxHp:
        player.maxHp += 20;
        player.hp += 20;
        controller.hud.maxHp.value = player.maxHp;
        controller.hud.hp.value = player.hp;
        break;
      case JourneyUpgradeKind.regen:
        player.regen += 1.0;
        break;
      case JourneyUpgradeKind.pickupRange:
        player.pickupRange += 18;
        break;
    }
    _pendingLevelUps--;
    if (_pendingLevelUps > 0) {
      controller.onLevelUp(_charLv, paused: true);
    } else {
      _pausedByLevelUp = false;
      resumeEngine();
    }
  }

  void onPlayerHpChanged() {
    controller.hud.hp.value = player.hp;
    if (player.hp <= 0 && !_ended) _finish(cleared: false);
  }

  void addMeritCoins(int coins) {
    _meritCoins += coins;
    controller.hud.meritCoins.value = _meritCoins;
  }

  void _finish({required bool cleared}) {
    if (_ended) return;
    _ended = true;
    pauseEngine();
    // 首通奖励仅首次通关该难发放（首通判定基准=进关时最远记录）。
    final firstClear = level.levelNo > controller.farthestAtStart;
    final clearBonus =
        cleared && firstClear ? level.firstClearMerit : 0;
    controller.onFinished(
      cleared: cleared,
      kills: _kills,
      meritFromCoins: _meritCoins,
      meritClearBonus: clearBonus,
      durationSec: _elapsed.round(),
    );
  }
}
