part of 'journey_flame_game.dart';

/// 角色特殊能力的周期计时与触发：由主循环每帧调用，暂停/结算时随引擎冻结。
extension JourneyAbilityTick on JourneyFlameGame {
  void tickAbilities(double dt) {
    // 三根毫毛（sanheng_mao）：免死冷却递减；冷却快照统一在
    // syncSlotCooldowns 中写入 HUD，驱动被动槽时钟蒙层与倒计时。
    if (_maoCd > 0) {
      _maoCd = math.max(0, _maoCd - dt);
    }

    // 伏魔重击（shaseng）：蓄力周期可配，就绪后停表待下一次命中消耗
    if (hasAbility('shaseng') && !_fumoCharged) {
      _fumoTimer += dt;
      if (_fumoTimer >= battleNum('ability', 'fumo_charge_sec', 20)) {
        _fumoCharged = true;
        _fumoTimer = 0;
        // GameAudio.instance.journeyAura();
      }
    }

    // 三头六臂（nezha）：每周期现身一段窗口，窗口内伤害/转速双增益；
    // 计时器在窗口期照常累加，保证两次触发间隔恒为周期值
    if (hasAbility('nezha')) {
      if (_nezhaWindow > 0) _nezhaWindow -= dt;
      _nezhaTimer += dt;
      if (_nezhaTimer >= battleNum('ability', 'nezha_period_sec', 30)) {
        _nezhaTimer = 0;
        _nezhaWindow = battleNum('ability', 'nezha_window_sec', 6);
        spawnFloatText(
          player.position + Vector2(0, -36),
          '三头六臂',
          const Color(0xFFE8C470),
        );
        // GameAudio.instance.journeyAura();
      }
    }

    // 兜率炉火（laojun）：每周期炉火加持一段窗口，命中附加灼烧（结算侧判定）
    if (hasAbility('laojun')) {
      if (_laojunWindow > 0) _laojunWindow -= dt;
      _laojunTimer += dt;
      if (_laojunTimer >= battleNum('ability', 'laojun_period_sec', 30)) {
        _laojunTimer = 0;
        _laojunWindow = battleNum('ability', 'laojun_window_sec', 6);
        spawnFloatText(
          player.position + Vector2(0, -36),
          '兜率炉火',
          const Color(0xFFD4593F),
        );
        // GameAudio.instance.journeyAura();
      }
    }

    // 芭蕉罡风（tieshan）：周期扇出罡风，臂长内妖物按参数击退并定身。
    // 计时到周期即停住，范围内无妖物不空转；有目标时立即触发并重新计时。
    if (hasAbility('tieshan')) {
      final period = battleNum('ability', 'tieshan_period_sec', 30);
      if (_tieshanTimer < period) {
        _tieshanTimer = math.min(period, _tieshanTimer + dt);
      }
      if (_tieshanTimer >= period) {
        final arm = weaponArm;
        final reach = arm?.outerRadius ?? 0.0;
        final inRange = monsters.where((m) => !m.isDead &&
            (m.position - player.position).length <= reach).toList();
        if (inRange.isNotEmpty) {
          _tieshanTimer = 0;
          final push = battleNum('ability', 'tieshan_knockback', 240);
          final root = battleNum('ability', 'tieshan_root_sec', 1);
          for (final m in inRange) {
            final away = m.position - player.position;
            if (away.length > 1) {
              m.applyKnockback(away, push);
            }
            m.rootTimer = root;
          }
          fxLayer.spawnRing(player.position, reach);
          spawnFloatText(
            player.position + Vector2(0, -36),
            '芭蕉罡风',
            const Color(0xFF9AD5C3),
          );
        }
      }
    }

    // 新维度槽（回元/护盾）的周期驱动 + 范围减速的每帧施加；聚妖幡寻猎走法宝通道
    tickNewSlots(dt);

    // 计时类槽的 HUD 冷却快照统一同步（时钟蒙层 + 秒数），20fps 节流写入。
    syncSlotCooldowns(dt);
  }
}

/// 计时类槽冷却快照同步：把每帧累加的周期/冷却计时折算为「剩余/总秒数」
/// 写入 HUD，驱动槽位顺时针蒙层与倒计时文案。按 20fps 节流、0.05s 量化去重，
/// 避免每帧通知 Flutter 层重建；就绪（剩余<=0）或槽位不存在则移除该项。
/// 覆盖：回元/护体（维度槽周期）、玉净瓶（被动周期）、三根毫毛（被动冷却）。
extension JourneySlotCooldownSync on JourneyFlameGame {
  void syncSlotCooldowns(double dt) {
    _slotCdSyncTimer += dt;
    if (_slotCdSyncTimer < 0.05) return;
    _slotCdSyncTimer = 0;

    final prevMap = controller.hud.slotCooldowns.value;
    final next = <String, JourneySlotCooldown>{};

    // 量化到 0.05s：同一次节流窗内重复的快照复用旧对象，仅变化项触发重建。
    void put(String code, double remain, double total) {
      if (total <= 0 || remain <= 0) return;
      final prev = prevMap[code];
      next[code] = prev != null &&
              _cdQuant(prev.remain) == _cdQuant(remain) &&
              _cdQuant(prev.total) == _cdQuant(total)
          ? prev
          : JourneySlotCooldown(remain, total);
    }

    // 回元 / 护体：周期从 0 累加到 period，剩余 = period - tick。
    for (final code in const ['recovery', 'shield']) {
      final lv = slotLevel(code);
      if (lv <= 0) continue;
      final period =
          slotPeriod(code, battleNum('weapon', '${code}_period', 4));
      if (period <= 0) continue;
      final tick = code == 'recovery' ? player.recoveryTick : player.shieldTick;
      put(code, math.max(0.0, period - tick), period);
    }
    // 玉净瓶：周期回血，剩余 = period - 甘露累加计时。
    if (passiveSlotCodes.contains('yujing_ping')) {
      final period = weaponParam('yujing_ping', 'period', 20);
      put('yujing_ping',
          math.max(0.0, period - player.ganluElapsed), period);
    }
    // 三根毫毛：冷却从 cooldown 递减到 0，剩余 = _maoCd；-1=本局不再免死。
    if (passiveSlotCodes.contains('sanheng_mao') && _maoCd > 0) {
      put('sanheng_mao', _maoCd, weaponParam('sanheng_mao', 'cooldown', 300));
    }

    if (next.length != prevMap.length ||
        next.entries.any((e) => !identical(e.value, prevMap[e.key]))) {
      controller.hud.slotCooldowns.value = Map.unmodifiable(next);
    }
  }

  /// 冷却量化：0.05s 一格，与节流窗一致，保证扫过平滑且不频繁重建。
  int _cdQuant(double v) => (v * 20).round();
}

/// 周期效果：回元按缺失血量回血、护体金光周期授予护盾、聚妖幡周期吸引
/// 范围内妖物主动接战；缚灵的减速为每帧范围刷新。
extension JourneyNewSlotTick on JourneyFlameGame {
  void tickNewSlots(double dt) {
    final p = player;

    // 回元（recovery）：周期按已损失生命比例回血，走 heal（含禁疗拦截）。
    // 计时到周期即停住，满血/禁疗不空转；一旦缺血立即回血并重新计时。
    final recLv = slotLevel('recovery');
    if (recLv > 0) {
      final period =
          slotPeriod('recovery', battleNum('weapon', 'recovery_period', 4));
      if (p.recoveryTick < period) {
        p.recoveryTick = math.min(period, p.recoveryTick + dt);
      }
      final missing = p.maxHp - p.hp;
      if (p.recoveryTick >= period && missing > 0 && p.healBlockTimer <= 0) {
        p.recoveryTick = 0;
        final ratio = linearSlotValue('recovery', recLv, 0.05)
            .clamp(0.0, battleNum('weapon', 'recovery_cap', 0.5));
        p.heal(missing * ratio);
        spawnFloatText(
          p.position + Vector2(0, -36),
          '回元',
          const Color(0xFF8FD98A),
        );
      }
    }

    // 护体金光（shield）：周期按固定护盾点数授予（每级数值×等级），
    // 与最大生命无关；护盾总量上限为最大生命值。计时到周期即停住，
    // 满盾不空转；护盾被消耗后立即补盾并重新计时。
    final shieldLv = slotLevel('shield');
    if (shieldLv > 0) {
      final period =
          slotPeriod('shield', battleNum('weapon', 'shield_period', 4));
      if (p.shieldTick < period) {
        p.shieldTick = math.min(period, p.shieldTick + dt);
      }
      if (p.shieldTick >= period && p.shield < p.maxHp) {
        p.shieldTick = 0;
        final add = linearSlotValue('shield', shieldLv, 20);
        p.gainShield(add);
        spawnFloatText(
          p.position + Vector2(0, -36),
          '护体金光',
          const Color(0xFFE8C470),
        );
      }
    }

    // 坚韧光环（shaseng）：周期授予护盾，单次点数 = 每级点数 × 角色等级，
    // 并钳点数上限；护盾池上限与通用护体槽一致为最大生命值。与通用护体槽
    // 共用 player.shield 池但独立计时，避免互相重置。
    // 满盾不空转、消耗后下一周期补，周期/每级点数/点数上限均走光环参数。
    if (character.code == 'shaseng') {
      final period = character.auraNum('shield_period', 10);
      if (period > 0) {
        if (_shasengShieldTick < period) {
          _shasengShieldTick = math.min(period, _shasengShieldTick + dt);
        }
        final pointCap = character.auraNum('shield_max', 200);
        if (_shasengShieldTick >= period && p.shield < p.maxHp) {
          _shasengShieldTick = 0;
          final add = math.min(
            pointCap,
            character.auraNum('shield_per_level', 5) * _charLv,
          );
          p.gainShield(add);
          spawnFloatText(
            p.position + Vector2(0, -36),
            '坚韧·护盾',
            const Color(0xFFE8C470),
          );
        }
      }
    }

    // 缚灵（slow）：每帧对臂展圆内怪物刷新减速；离开范围由怪物侧计时自然到期
    final slowLv = slotLevel('slow');
    if (slowLv > 0) {
      final reach = weaponArm?.outerRadius ?? 0.0;
      final factor = (1 -
              linearSlotValue('slow', slowLv, 0.06)
                  .clamp(0.0, battleNum('weapon', 'slow_cap', 0.7)))
          .clamp(0.0, 1.0);
      final hold = battleNum('weapon', 'slow_hold_sec', 0.6);
      for (final m in monsters) {
        if (m.isDead) continue;
        final toM = m.position - p.position;
        if (toM.length - m.radius > reach) continue;
        m.slowFactor = factor;
        m.slowTimer = hold;
      }
    }

    // 聚妖幡（juyao_fan）：周期吸引范围内非妖王妖物主动接战；
    // 周期/范围/锁定秒数走法宝参数（period/range/seconds）。计时到周期
    // 即停住，无可引目标不空转；有目标时立即触发并重新计时。
    if (effectWeapons.contains('juyao_fan')) {
      final period = weaponParam('juyao_fan', 'period', 15.0);
      if (p.huntTick < period) {
        p.huntTick = math.min(period, p.huntTick + dt);
      }
      if (p.huntTick >= period) {
        final reach = weaponParam('juyao_fan', 'range', 900.0);
        final hold = weaponParam('juyao_fan', 'seconds', 12.0);
        final candidates = monsters.where((m) =>
            !m.isDead &&
            !m.model.isBoss &&
            (m.position - p.position).length <= reach).toList();
        if (candidates.isNotEmpty) {
          p.huntTick = 0;
          for (final m in candidates) {
            m.lureTimer = hold;
          }
          fxLayer.spawnRing(p.position, reach);
          spawnFloatText(
            p.position + Vector2(0, -36),
            '聚妖幡·${candidates.length} 妖',
            const Color(0xFFD98A8A),
          );
        }
      }
    }

    // 风火轮（灼烧扩散）：周期点燃最近妖物作火种；火种按扩散周期把灼烧
    // 传给邻近未点燃妖物，逐代衰减、代际到上限后停止，灼烧到期归位可复燃。
    if (effectWeapons.contains('fenghuo_lun')) {
      final period = weaponParam('fenghuo_lun', 'period', 10.0);
      if (p.fenghuoTick < period) {
        p.fenghuoTick = math.min(period, p.fenghuoTick + dt);
      }
      if (p.fenghuoTick >= period) {
        final reach = weaponArm?.outerRadius ?? 0.0;
        JourneyMonsterComponent? seed;
        var best = double.maxFinite;
        for (final m in monsters) {
          if (m.isDead) continue;
          final d = (m.position - p.position).length - m.radius;
          if (d > reach || d >= best) continue;
          best = d;
          seed = m;
        }
        if (seed != null) {
          p.fenghuoTick = 0;
          final burn = weaponParam('fenghuo_lun', 'burn', 0.5) *
              (weaponArm?.damage ?? 10) *
              passiveAmpFactor;
          seed.igniteFenghuo(
            burn,
            weaponParam('fenghuo_lun', 'seconds', 3.0),
            0,
          );
          fxLayer.spawnRing(seed.position, seed.radius + 8,
              color: const Color(0xFFFF8A4A));
          spawnFloatText(seed.position + Vector2(0, -seed.radius - 14),
              '风火轮·灼烧', const Color(0xFFFF8A4A));
        }
      }
      // 扩散：带灼烧的妖物按周期向邻近未点燃者传播下一代。
      final spreadPeriod = weaponParam('fenghuo_lun', 'spread_period', 2.0);
      final spreadRange = weaponParam('fenghuo_lun', 'spread_range', 140.0);
      final spreadRatio = weaponParam('fenghuo_lun', 'spread_ratio', 0.6);
      final maxGen = weaponParam('fenghuo_lun', 'spread_generations', 2).round();
      final baseBurn = weaponParam('fenghuo_lun', 'burn', 0.5) *
          (weaponArm?.damage ?? 10) *
          passiveAmpFactor;
      final seconds = weaponParam('fenghuo_lun', 'seconds', 3.0);
      final sources =
          monsters.where((m) => !m.isDead && m.fenghuoGen >= 0).toList();
      for (final src in sources) {
        src.fenghuoSpreadTimer += dt;
        if (src.fenghuoSpreadTimer < spreadPeriod) continue;
        src.fenghuoSpreadTimer = 0;
        if (src.fenghuoGen >= maxGen) continue;
        final nextGen = src.fenghuoGen + 1;
        final nextBurn = baseBurn * math.pow(spreadRatio, nextGen);
        for (final dst in monsters) {
          if (dst.isDead || dst.fenghuoGen >= 0) continue;
          if ((dst.position - src.position).length - dst.radius > spreadRange) {
            continue;
          }
          dst.igniteFenghuo(nextBurn.toDouble(), seconds, nextGen);
          fxLayer.spawnRing(dst.position, dst.radius + 8,
              color: const Color(0xFFFFB27A));
        }
      }
    }
  }
}
