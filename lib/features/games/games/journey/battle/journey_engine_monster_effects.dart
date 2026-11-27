part of 'journey_flame_game.dart';

/// 位移队列：命中只登记方向与总距离，位移在逐帧推进中按缓出曲线分配，
/// 避免单帧一次性加满造成的闪现；连续命中把未走完的距离并入新一轮。
/// 击退与拖拽各走独立通道，方向互不覆盖，可同一次命中并存。
mixin JourneyKnockbackMixin on PositionComponent {
  bool get isDead;

  Vector2 _knockDir = Vector2.zero();
  double _knockTotal = 0;
  double _knockElapsed = 0;

  Vector2 _dragDir = Vector2.zero();
  double _dragTotal = 0;
  double _dragElapsed = 0;

  static const double _knockDuration = 0.22;
  static const double _knockChaseFactor = 0.25;

  bool get _isKnocking => _knockTotal > 0;

  /// 击退期间追击/归位速度系数：不立刻贴回玩家，推开过程才看得见。
  double get knockChaseFactor => _isKnocking ? _knockChaseFactor : 1.0;

  void applyKnockback(Vector2 dir, double distance) {
    if (isDead || distance <= 0 || dir.length < 0.001) return;
    _knockDir = dir.normalized();
    _knockTotal = _remainingKnock() + distance;
    _knockElapsed = 0;
  }

  /// 拖拽：向指定方向拉近，独立于击退队列，不与击退互相覆盖方向。
  void applyDrag(Vector2 dir, double distance) {
    if (isDead || distance <= 0 || dir.length < 0.001) return;
    _dragDir = dir.normalized();
    _dragTotal = _remainingDrag() + distance;
    _dragElapsed = 0;
  }

  /// 缓出曲线 f(t)=1-(1-t)^2 下的剩余距离：前快后慢。
  double _remainingKnock() {
    if (_knockTotal <= 0) return 0;
    final t = (_knockElapsed / _knockDuration).clamp(0.0, 1.0);
    return _knockTotal * (1 - t) * (1 - t);
  }

  double _remainingDrag() {
    if (_dragTotal <= 0) return 0;
    final t = (_dragElapsed / _knockDuration).clamp(0.0, 1.0);
    return _dragTotal * (1 - t) * (1 - t);
  }

  /// 每帧推进击退与拖拽增量；与追击/分离力/边界钳制叠加，不覆盖其他位移。
  void _tickKnockback(double dt) {
    if (_knockTotal > 0) {
      final before = _remainingKnock();
      _knockElapsed = math.min(_knockDuration, _knockElapsed + dt);
      final after = _remainingKnock();
      position += _knockDir * (before - after);
      if (_knockElapsed >= _knockDuration) _knockTotal = 0;
    }
    if (_dragTotal > 0) {
      final before = _remainingDrag();
      _dragElapsed = math.min(_knockDuration, _dragElapsed + dt);
      final after = _remainingDrag();
      position += _dragDir * (before - after);
      if (_dragElapsed >= _knockDuration) _dragTotal = 0;
    }
  }
}

/// 灼烧单来源的本帧结算明细：来源键、本帧伤害、是否真实伤害绕甲。
/// 调用方按来源逐条扣血，避免把不同来源相加成一笔伤害。
typedef JourneyBurnTick = ({String source, double damage, bool trueDamage});

/// 灼烧按来源独立计时：武器灼烧、兜率炉火、阴阳二气瓶互不覆盖，
/// 每秒伤害叠加结算，使「附加灼烧」不会重置已有点燃。
/// 固定值型来源（trueDamage=true，如灼烧槽 8/秒×等级）为真实伤害
/// 绕过护甲减免；百分比型来源（按基础伤害比例点燃）仍经护甲。
mixin JourneyBurnMixin on PositionComponent {
  bool get isDead;

  /// 处于武器臂展圆内的连续驻留时长：驱动所有灼烧来源的点燃，离开范围清零。
  /// 每满驻留阈值续烧一次，已点燃的来源按各自时长独立烧完。
  double burnDwell = 0;

  final Map<String, (double, double, bool)> _burnSources =
      <String, (double, double, bool)>{};

  double get burnRemaining {
    var longest = 0.0;
    for (final source in _burnSources.values) {
      if (source.$2 > longest) longest = source.$2;
    }
    return longest;
  }

  double get burnDps => _burnSources.values.fold(0.0, (sum, v) => sum + v.$1);

  /// 风火轮灼烧代际：-1=未点燃，0=火种，>=1=扩散代。灼烧源到期归位后可被再次点燃。
  int fenghuoGen = -1;
  /// 风火轮扩散计时：火种按周期向邻近未点燃妖物传播灼烧。
  double fenghuoSpreadTimer = 0;

  void igniteFenghuo(double burnDps, double seconds, int gen) {
    ignite(source: 'fenghuo_lun', burnDps: burnDps, seconds: seconds);
    fenghuoGen = gen;
    fenghuoSpreadTimer = 0;
  }

  void ignite({
    required String source,
    required double burnDps,
    required double seconds,
    bool trueDamage = false,
  }) {
    if (isDead) return;
    _burnSources[source] = (burnDps, seconds, trueDamage);
  }

  /// 臂展驻留灼烧：处于武器外环圆内（整圆判定，不看扇叶角度与命中冷却）
  /// 累计驻留时长，每满 [dwellSec] 秒续燃全部生效来源；离开范围清零计时。
  /// 三路来源沿用各自伤害口径，已点燃者按独立时长继续烧完不被覆盖中断。
  void tickBurnAura(
    JourneyFlameGame game,
    double dt, {
    required double dwellSec,
    required double monsterRadius,
  }) {
    final arm = game.weaponArm;
    if (isDead || arm == null) {
      burnDwell = 0;
      return;
    }
    final safeDwell = dwellSec.clamp(0.1, 30.0);
    final dist = (game.player.position - position).length;
    if (dist - monsterRadius > arm.outerRadius) {
      // 离开臂展圆即清零驻留，重新进入需再次驻留满阈值
      burnDwell = 0;
      return;
    }
    burnDwell += dt;
    if (burnDwell < safeDwell) return;
    // 每满一个阈值续燃一次；用取模而非清零，保留超出部分继续累计
    burnDwell %= safeDwell;
    // 武器灼烧槽：槽值×等级×角色等级成长×三昧倍率，固定值型绕甲。
    // 成长随局内角色等级线性提升，避免后期怪物血量上涨后固定灼烧失效；
    // 灼烧本身不随驻留时间递增，只靠槽等级与角色等级提升数值。
    final burnLv = game.slotLevel('burn');
    if (burnLv > 0) {
      final honghaier = game.hasAbility('honghaier');
      final lvGrowth = 1 +
          (game.charLevel - 1) *
              game.battleNum('weapon', 'burn_level_growth', 0.04);
      ignite(
        source: 'weapon_burn',
        burnDps: game.linearSlotValue('burn', burnLv, 8.0) *
            lvGrowth *
            (honghaier
                ? game.battleNum('ability', 'honghaier_burn_mult', 2.0)
                : 1.0) *
            game.passiveAmpFactor,
        seconds: honghaier
            ? game.battleNum('ability', 'honghaier_burn_sec', 4)
            : 2,
        trueDamage: true,
      );
    }
    // 兜率炉火（老君）：炉火加持窗口内按武器伤害比例点燃，经甲
    if (game._laojunWindow > 0) {
      ignite(
        source: 'laojun_fire',
        burnDps:
            game.hitDamageBase * game.battleNum('ability', 'laojun_burn_ratio', 0.4),
        seconds: game.battleNum('ability', 'laojun_burn_sec', 2),
      );
    }
    // 阴阳二气瓶：装备该法宝即按周期口径的伤害比例点燃，经甲
    if (game.effectWeapons.contains('yinyang_ping')) {
      ignite(
        source: 'yinyang_ping',
        burnDps:
            game.hitDamageBase * game.weaponParam('yinyang_ping', 'burn', 0.4),
        seconds: game.weaponParam('yinyang_ping', 'root', 2.5),
      );
    }
  }

  /// 推进各来源计时，返回本帧各来源的灼烧伤害明细：每条带来源键、伤害值、
  /// 是否真实伤害绕甲。调用方逐来源扣血，使各来源独立结算、互不相加。
  List<JourneyBurnTick> tickBurn(double dt) {
    if (_burnSources.isEmpty) return const [];
    final ticks = <JourneyBurnTick>[];
    final expired = <String>[];
    for (final entry in _burnSources.entries.toList()) {
      final left = entry.value.$2 - dt;
      if (left <= 0) {
        expired.add(entry.key);
        continue;
      }
      _burnSources[entry.key] = (entry.value.$1, left, entry.value.$3);
      if (entry.value.$1 <= 0) continue;
      ticks.add((
        source: entry.key,
        damage: entry.value.$1 * dt,
        trueDamage: entry.value.$3,
      ));
    }
    for (final key in expired) {
      if (key == 'fenghuo_lun') fenghuoGen = -1;
      _burnSources.remove(key);
    }
    return ticks;
  }
}

/// 妖王周期能力（阵风/火圈/摄魂）：各自独立计时，进战（追击态）才走，
/// 暂停时随引擎冻结。
mixin JourneyBossAbilityMixin on PositionComponent {
  JourneyFlameGame get game;
  JourneyMonsterModel get model;
  double get contactDamage;

  /// 周期能力计时（到周期即停住，GCD/条件未满足不空转）。
  /// 按能力键分桶，一妖多能力时各能力独立计时、互不叠加。
  final Map<String, double> _abilityTimers = <String, double>{};

  /// 白骨三变形态计数：交替授予护罩/致幻。
  int _boneForm = 0;

  /// 紫金铃三色轮转相位（火/烟/沙）。
  int _bellPhase = 0;

  /// 周期是否到点：计时钳在 period，就绪后由 [ackPeriodic] 清零。
  bool periodicReady(String key, double period) =>
      (_abilityTimers[key] ?? 0) >= period;

  void ackPeriodic(String key) => _abilityTimers[key] = 0;

  /// 统一调度入口（由 monsters part 每帧在追击态调用）：
  /// 周期读取、计时推进、GCD 检查与派发全部收敛在调度 part，
  /// 避免计时上限与派发阈值两处口径漂移。
  void tickBossAbility(double dt, double dist) {
    game.tickBossSkill(this as JourneyMonsterComponent, dt, dist);
  }

  /// 计时钳在周期上限（到点停表，不空转）。
  void advancePeriodic(String key, double dt, double period) {
    final timer = _abilityTimers[key] ?? 0;
    if (timer < period) {
      _abilityTimers[key] = math.min(period, timer + dt);
    }
  }
}

/// 脱战快速回血：只增长实体血量，大血条数值由每帧 syncBossHud 统一刷新。
/// 对所有怪物通用（含妖王），归在怪物效果 part 而非妖王血条 part。
extension JourneyMonsterRegen on JourneyMonsterComponent {
  void regenWhenDisengaged(double dt) {
    if (hp >= maxHp) return;
    hp = math.min(
      hp +
          maxHp *
              game.battleNum(
                  'monster', 'regen_per_sec', JourneyMonsterComponent._regenPerSec) *
          dt,
      maxHp,
    );
  }
}

/// 施加到怪物的临时状态：范围减速（缚灵槽）与周期寻猎（聚妖幡法宝）。
/// 二者都是计时型，随引擎逐帧推进；寻猎窗口内强制接战、压制 leash 脱战。
mixin JourneySlotStatusMixin on PositionComponent {
  bool get isDead;

  /// 减速剩余时间：>0 时移动乘 slowFactor。
  double slowTimer = 0;
  /// 减速倍率（1=不减速；由 slow 槽每帧刷新写入）。
  double slowFactor = 1;

  /// 寻猎剩余时间：>0 时强制进入追击态，忽略侦测/脱战半径（妖王不适用）。
  double lureTimer = 0;

  /// 当前减速对移动速度的乘算系数。
  double get slotSlowFactor => slowTimer > 0 ? slowFactor : 1.0;

  /// 每帧递减计时；离屏冻结由调用方决定是否跳过（寻猎怪需保持接战态）。
  void tickSlotStatus(double dt) {
    if (slowTimer > 0) slowTimer = math.max(0, slowTimer - dt);
    if (lureTimer > 0) lureTimer = math.max(0, lureTimer - dt);
  }
}
