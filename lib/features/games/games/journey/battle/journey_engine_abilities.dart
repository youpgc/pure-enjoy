part of 'journey_flame_game.dart';

/// 角色特殊能力的周期计时与触发：由主循环每帧调用，暂停/结算时随引擎冻结。
extension JourneyAbilityTick on JourneyFlameGame {
  void tickAbilities(double dt) {
    // 三根毫毛（sanheng_mao）：免死冷却递减；HUD 按整秒去重写入，
    // 驱动被动槽图标灰化与右下角秒数。冷却长度走法宝参数 cooldown。
    if (_maoCd > 0) {
      _maoCd = math.max(0, _maoCd - dt);
      final secs = _maoCd.ceil();
      if (controller.hud.maoCd.value != secs) {
        controller.hud.maoCd.value = secs;
      }
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

    // 芭蕉罡风（tieshan）：每周期扇出罡风，武器臂长内妖物按参数击退并定身
    if (hasAbility('tieshan')) {
      _tieshanTimer += dt;
      if (_tieshanTimer >= battleNum('ability', 'tieshan_period_sec', 30)) {
        _tieshanTimer = 0;
        final arm = weaponArm;
        final reach = arm?.outerRadius ?? 0.0;
        final push = battleNum('ability', 'tieshan_knockback', 240);
        final root = battleNum('ability', 'tieshan_root_sec', 1);
        for (final m in monsters) {
          if (m.isDead) continue;
          final away = m.position - player.position;
          if (away.length > reach) continue;
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

    // 新维度槽（回元/护盾）的周期驱动 + 范围减速的每帧施加；聚妖幡寻猎走法宝通道
    tickNewSlots(dt);
  }
}

/// 周期效果：回元按缺失血量回血、护体金光周期授予护盾、聚妖幡周期吸引
/// 范围内妖物主动接战；缚灵的减速为每帧范围刷新。
extension JourneyNewSlotTick on JourneyFlameGame {
  void tickNewSlots(double dt) {
    final p = player;

    // 回元（recovery）：周期按已损失生命比例回血，走 heal（含禁疗拦截）
    final recLv = slotLevel('recovery');
    if (recLv > 0) {
      p.recoveryTick += dt;
      final period = slotPeriod('recovery', battleNum('weapon', 'recovery_period', 4));
      if (p.recoveryTick >= period) {
        p.recoveryTick = 0;
        final missing = p.maxHp - p.hp;
        if (missing > 0) {
          final ratio = (slotValue('recovery', 0.05) * recLv).clamp(
            0.0,
            battleNum('weapon', 'recovery_cap', 0.5),
          );
          p.heal(missing * ratio);
          spawnFloatText(
            p.position + Vector2(0, -36),
            '回元',
            const Color(0xFF8FD98A),
          );
        }
      }
    }

    // 护体金光（shield）：周期按固定护盾点数授予（每级数值×等级），
    // 与最大生命无关；护盾总量上限为最大生命值，达到上限不再增长。
    final shieldLv = slotLevel('shield');
    if (shieldLv > 0) {
      p.shieldTick += dt;
      final period = slotPeriod('shield', battleNum('weapon', 'shield_period', 4));
      if (p.shieldTick >= period) {
        p.shieldTick = 0;
        final add = slotValue('shield', 20) * shieldLv;
        p.shield = math.min(p.maxHp, p.shield + add);
        controller.hud.shield.value = p.shield;
        spawnFloatText(
          p.position + Vector2(0, -36),
          '护体金光',
          const Color(0xFFE8C470),
        );
      }
    }

    // 缚灵（slow）：每帧对臂展圆内怪物刷新减速；离开范围由怪物侧计时自然到期
    final slowLv = slotLevel('slow');
    if (slowLv > 0) {
      final reach = weaponArm?.outerRadius ?? 0.0;
      final factor = (1 -
              (slotValue('slow', 0.06) * slowLv).clamp(
                0.0,
                battleNum('weapon', 'slow_cap', 0.7),
              ))
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
    // 周期/范围/锁定秒数走法宝参数（period/range/seconds）。
    if (effectWeapons.contains('juyao_fan')) {
      p.huntTick += dt;
      final period = weaponParam('juyao_fan', 'period', 15.0);
      if (p.huntTick >= period) {
        p.huntTick = 0;
        final reach = weaponParam('juyao_fan', 'range', 900.0);
        final hold = weaponParam('juyao_fan', 'seconds', 12.0);
        var lured = 0;
        for (final m in monsters) {
          if (m.isDead || m.model.isBoss) continue; // 妖王不受寻猎
          if ((m.position - p.position).length > reach) continue;
          m.lureTimer = hold;
          lured++;
        }
        if (lured > 0) {
          fxLayer.spawnRing(p.position, reach);
          spawnFloatText(
            p.position + Vector2(0, -36),
            '聚妖幡·$lured 妖',
            const Color(0xFFD98A8A),
          );
        }
      }
    }

    // 风火轮（灼烧扩散）：周期点燃最近妖物作火种；火种按扩散周期把灼烧
    // 传给邻近未点燃妖物，逐代衰减、代际到上限后停止，灼烧到期归位可复燃。
    if (effectWeapons.contains('fenghuo_lun')) {
      p.fenghuoTick += dt;
      final period = weaponParam('fenghuo_lun', 'period', 10.0);
      if (p.fenghuoTick >= period) {
        p.fenghuoTick = 0;
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
          final burn = weaponParam('fenghuo_lun', 'burn', 0.5) *
              (weaponArm?.damage ?? 10);
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
          (weaponArm?.damage ?? 10);
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
