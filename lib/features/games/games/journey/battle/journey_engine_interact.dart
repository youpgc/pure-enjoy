part of 'journey_flame_game.dart';

/// 对局交互系统（extension，同 library 访问宿主私有成员）：
/// - 参照物实体判定/破坏/里程碑播报（§7/§2）；
/// - 还魂复活（§3，功德直接购买）；
/// - 宝箱炼化流水线（§6）；
/// - 面包屑铜钱。
extension JourneyInteract on JourneyFlameGame {
  /// 参照物是否实体阻挡：unbreakable 恒实体；未破坏 breakable 实体
  /// （chest_point/milestone/waypoint 可通行）。
  bool isMapObjectSolid(int index) {
    final objs = runtime.mapObjects;
    if (index < 0 || index >= objs.length) return false;
    final o = objs[index];
    if (o.kind == 'unbreakable') return true;
    if (o.kind == 'breakable') return !_mapObjDead[index];
    return false;
  }

  /// 可击破参照物是否仍存活（扇叶扫掠判定用）。
  bool isMapObjectBreakableAlive(int index) {
    final objs = runtime.mapObjects;
    if (index < 0 || index >= objs.length) return false;
    return objs[index].kind == 'breakable' && !_mapObjDead[index];
  }

  /// 参照物受击扣血：hp<=0 → 标记破坏 + 残屑视觉 + 掉落判定
  /// （dropTableCode 非空否则 'breakable_default' 加权随机）。
  void damageMapObject(int index, double damage) {
    final hp = (_mapObjHp[index] ?? 0) - damage;
    if (hp > 0) {
      _mapObjHp[index] = hp;
      return;
    }
    if (_mapObjDead[index]) return;
    _mapObjDead[index] = true;
    _mapObjHp.remove(index);
    final o = runtime.mapObjects[index];
    fxLayer.spawnDebris(Vector2(o.x, o.y), o.radius);
    final tableCode =
        (o.dropTableCode != null && o.dropTableCode!.isNotEmpty)
            ? o.dropTableCode!
            : 'breakable_default';
    final table = config?.dropTableOf(tableCode) ?? const <JourneyDropModel>[];
    if (table.isNotEmpty) {
      _rollDropTable(this, table, Vector2(o.x, o.y));
    }
  }

  /// 里程碑参照物播报：接近 <70 触发一次（已西行里程=出生点到当前距离
  /// ÷25，与罗盘里数同口径：1 里=25 世界单位）。
  void checkMilestones() {
    final objs = runtime.mapObjects;
    if (objs.isEmpty) return;
    final spawn = Vector2(worldSize / 2, worldSize / 2);
    for (var i = 0; i < objs.length; i++) {
      if (objs[i].kind != 'milestone' || _milestoneHit.contains(i)) continue;
      final o = objs[i];
      if ((player.position - Vector2(o.x, o.y)).length >= 70) continue;
      _milestoneHit.add(i);
      final li = ((player.position - spawn).length / 25.0).round();
      controller.hud.milestoneText.value = '已西行 $li 里';
    }
  }

  /// 还魂复活（§3）：回 60% 血量、300px 内怪物向外推至 420px、弹「还魂！」。
  void doRevive() {
    revivesLeft--;
    player.hp = player.maxHp * 0.6;
    for (final m in monsters) {
      if (m.isDead) continue;
      final d = m.position - player.position;
      final len = d.length;
      if (len < 300) {
        m.position = len < 1
            ? player.position + Vector2(420, 0)
            : player.position + d.normalized() * 420;
      }
    }
    spawnFloatText(
      player.position + Vector2(0, -40),
      '还魂！',
      const Color(0xFFF6E3B4),
    );
    controller.hud.hp.value = player.hp;
    _revivePending = false;
    // 选卡弹窗未清时交由 applyUpgrade 尾部恢复，避免误恢复选卡暂停态
    if (!isPausedForLevelUp) {
      resumeEngine();
    }
  }

  /// 宝箱收集（§6 流水线）：匹配炼化配方→确认炼化；未匹配→80% 额外
  /// 三选一 / 20% 功德兜底（50% 翻倍成 30）；满级后不再弹三选一，
  /// 收益统一走功德兜底。
  Future<void> handleChestCollected() async {
    if (_ended || _alchemyPending || _revivePending) return;
    final recipe = config?.evoRecipeOf(character.weaponCode);
    // 配方匹配：被动无等级概念（requiredPassiveLv 种子=1，持有即达标）
    final matched = recipe != null &&
        !evolved &&
        passiveSlotCodes.contains(recipe.requiredPassiveCode);
    if (matched) {
      _alchemyPending = true;
      pauseEngine();
      var confirmed = false;
      try {
        confirmed = await controller.onAlchemyPrompt(recipe.resultName);
      } catch (_) {
        confirmed = false;
      }
      if (confirmed) {
        _applyEvolution(
          recipe.resultName,
          mult: recipe.evoMult > 0 ? recipe.evoMult : 1.6,
        );
      }
      _alchemyPending = false;
      // 选卡弹窗未清时交由 applyUpgrade 尾部恢复，避免误恢复选卡暂停态
      if (!_ended && !isPausedForLevelUp) {
        resumeEngine();
      }
      return;
    }
    if (_charLv < _charLevelCap && rng.nextDouble() < 0.8) {
      // 额外三选一（不涨经验，复用升级选卡暂停/恢复路径）
      triggerBonusChoice();
    } else {
      _chestMeritFallback();
    }
  }

  /// 宝箱功德兜底：15 枚，50% 概率翻倍成 30（暴击翻倍口径）。
  void _chestMeritFallback() {
    final coins = rng.nextDouble() < 0.5 ? 30 : 15;
    addMeritCoins(coins);
    spawnFloatText(
      player.position + Vector2(0, -36),
      '+$coins 功德',
      const Color(0xFFE8C470),
    );
  }

  /// 炼化成功：立 evolved 标记 + 武器伤害 ×evoMult（配方 evo_mult 后台
  /// 可配，0=未配置走内置 1.6；渲染变化由对局页承接）。
  void _applyEvolution(String resultName, {required double mult}) {
    evolved = true;
    evoMult = mult;
    weaponBaseDamage *= mult;
    final arm = weaponArm;
    if (arm != null) {
      arm.damage *= mult;
    }
    spawnFloatText(
      player.position + Vector2(0, -40),
      '炼化·$resultName！',
      const Color(0xFFE8C470),
    );
  }

  /// 宝箱额外三选一（不涨经验）：_pendingLevelUps++ 后走升级选卡暂停路径，
  /// applyUpgrade 尾部按余量续弹或恢复运行（复用现有恢复路径）。
  void triggerBonusChoice() {
    _pendingLevelUps++;
    if (_pausedByLevelUp) return;
    _pausedByLevelUp = true;
    pauseEngine();
    controller.onLevelUp(_charLv, paused: true);
  }

  /// 面包屑铜钱（§2）：沿出生点→妖王据点直线均匀撒 6 枚指引西行；
  /// 无妖章回（bossModel==null）沿随机方向渐远撒布。每枚价值=铜钱单价
  /// （pickupConfigOf 缺省 3）。
  void _seedBreadcrumbCoins() {
    final unit = config?.pickupConfigOf('gongde_tongqian')?.value ?? 3;
    final size = worldSize;
    final origin = Vector2(size / 2, size / 2);
    final hasBoss = bossModel != null;
    for (var i = 1; i <= 6; i++) {
      Vector2 pos;
      if (hasBoss) {
        pos = origin + (bossPos - origin) * (i / 7.0);
      } else {
        final a = rng.nextDouble() * math.pi * 2;
        final dist = 300.0 + i * 220.0;
        pos = Vector2(
          (origin.x + math.cos(a) * dist).clamp(80.0, size - 80),
          (origin.y + math.sin(a) * dist).clamp(80.0, size - 80),
        );
      }
      _spawnPickup(this, JourneyPickupKind.meritCoin, pos, unit);
    }
  }
}
