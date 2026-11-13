part of 'journey_flame_game.dart';

/// 角色特殊能力的周期计时与触发：由主循环每帧调用，暂停/结算时随引擎冻结。
extension JourneyAbilityTick on JourneyFlameGame {
  void tickAbilities(double dt) {
    // 伏魔重击（shaseng）：每 20s 蓄力一次，就绪后停表待下一次命中消耗
    if (hasAbility('shaseng') && !_fumoCharged) {
      _fumoTimer += dt;
      if (_fumoTimer >= JourneyFlameGame._fumoChargeSec) {
        _fumoCharged = true;
        _fumoTimer = 0;
      }
    }

    // 三头六臂（nezha）：每 30s 现身 6s，窗口内伤害/转速双增益；
    // 计时器在窗口期照常累加，保证两次触发间隔恒为 30s
    if (hasAbility('nezha')) {
      if (_nezhaWindow > 0) _nezhaWindow -= dt;
      _nezhaTimer += dt;
      if (_nezhaTimer >= JourneyFlameGame._nezhaPeriodSec) {
        _nezhaTimer = 0;
        _nezhaWindow = JourneyFlameGame._nezhaWindowSec;
        spawnFloatText(
          player.position + Vector2(0, -36),
          '三头六臂',
          const Color(0xFFE8C470),
        );
      }
    }

    // 兜率炉火（laojun）：每 30s 炉火加持 6s，命中附加灼烧（结算侧判定）
    if (hasAbility('laojun')) {
      if (_laojunWindow > 0) _laojunWindow -= dt;
      _laojunTimer += dt;
      if (_laojunTimer >= JourneyFlameGame._laojunPeriodSec) {
        _laojunTimer = 0;
        _laojunWindow = JourneyFlameGame._laojunWindowSec;
        spawnFloatText(
          player.position + Vector2(0, -36),
          '兜率炉火',
          const Color(0xFFD4593F),
        );
      }
    }

    // 芭蕉罡风（tieshan）：每 30s 扇出罡风，全屏妖物击退 240 并定身 1s
    if (hasAbility('tieshan')) {
      _tieshanTimer += dt;
      if (_tieshanTimer >= JourneyFlameGame._tieshanPeriodSec) {
        _tieshanTimer = 0;
        for (final m in monsters) {
          if (m.isDead) continue;
          final away = m.position - player.position;
          if (away.length > 1) {
            m.applyKnockback(away, 240);
          }
          m.rootTimer = 1;
        }
        fxLayer.spawnRing(player.position, 240);
        spawnFloatText(
          player.position + Vector2(0, -36),
          '芭蕉罡风',
          const Color(0xFF9AD5C3),
        );
      }
    }
  }
}
