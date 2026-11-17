part of 'journey_flame_game.dart';

/// 角色特殊能力的周期计时与触发：由主循环每帧调用，暂停/结算时随引擎冻结。
extension JourneyAbilityTick on JourneyFlameGame {
  void tickAbilities(double dt) {
    // 伏魔重击（shaseng）：蓄力周期可配，就绪后停表待下一次命中消耗
    if (hasAbility('shaseng') && !_fumoCharged) {
      _fumoTimer += dt;
      if (_fumoTimer >= battleNum('ability', 'fumo_charge_sec', 20)) {
        _fumoCharged = true;
        _fumoTimer = 0;
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
  }
}
