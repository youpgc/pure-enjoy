part of 'journey_flame_game.dart';

/// 击退位移队列：命中只登记方向与总距离，位移在逐帧推进中按缓出曲线分配，
/// 避免单帧一次性加满造成的闪现；连续命中把未走完的距离并入新一轮。
mixin JourneyKnockbackMixin on PositionComponent {
  bool get isDead;

  Vector2 _knockDir = Vector2.zero();
  double _knockTotal = 0;
  double _knockElapsed = 0;

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

  /// 缓出曲线 f(t)=1-(1-t)^2 下的剩余距离：前快后慢。
  double _remainingKnock() {
    if (_knockTotal <= 0) return 0;
    final t = (_knockElapsed / _knockDuration).clamp(0.0, 1.0);
    return _knockTotal * (1 - t) * (1 - t);
  }

  /// 每帧推进击退增量；与追击/分离力/边界钳制叠加，不覆盖其他位移。
  void _tickKnockback(double dt) {
    if (_knockTotal <= 0) return;
    final before = _remainingKnock();
    _knockElapsed = math.min(_knockDuration, _knockElapsed + dt);
    final after = _remainingKnock();
    position += _knockDir * (before - after);
    if (_knockElapsed >= _knockDuration) _knockTotal = 0;
  }
}

/// 灼烧按来源独立计时：武器灼烧、兜率炉火、阴阳二气瓶互不覆盖，
/// 每秒伤害叠加结算，使「附加灼烧」不会重置已有点燃。
/// 固定值型来源（trueDamage=true，如灼烧槽 8/秒×等级）为真实伤害
/// 绕过护甲减免；百分比型来源（按基础伤害比例点燃）仍经护甲。
mixin JourneyBurnMixin on PositionComponent {
  bool get isDead;

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

  void ignite({
    required String source,
    required double burnDps,
    required double seconds,
    bool trueDamage = false,
  }) {
    if (isDead) return;
    _burnSources[source] = (burnDps, seconds, trueDamage);
  }

  /// 推进各来源计时，返回本帧应扣灼烧伤害：
  /// $1=经护甲减免部分（百分比型来源），$2=真实伤害部分（固定值型来源）。
  (double, double) tickBurn(double dt) {
    if (_burnSources.isEmpty) return (0, 0);
    var ampDps = 0.0;
    var trueDps = 0.0;
    final expired = <String>[];
    for (final entry in _burnSources.entries.toList()) {
      final left = entry.value.$2 - dt;
      if (left <= 0) {
        expired.add(entry.key);
      } else {
        if (entry.value.$3) {
          trueDps += entry.value.$1;
        } else {
          ampDps += entry.value.$1;
        }
        _burnSources[entry.key] = (entry.value.$1, left, entry.value.$3);
      }
    }
    for (final key in expired) {
      _burnSources.remove(key);
    }
    return (ampDps * dt, trueDps * dt);
  }
}

/// 妖王周期能力（阵风/火圈/摄魂）：各自独立计时，进战（追击态）才走，
/// 暂停时随引擎冻结。
mixin JourneyBossAbilityMixin on PositionComponent {
  JourneyFlameGame get game;
  JourneyMonsterModel get model;
  double get contactDamage;

  double _abilityTimer = 0;

  void tickBossAbility(double dt, double dist) {
    _abilityTimer += dt;
    final code = model.abilityKey;
    final period = switch (code) {
      'swift_wind' => game.monsterParam(model.code, 'wind_period', 8.0),
      'samadhi_fire' => game.monsterParam(model.code, 'fire_period', 6.0),
      'gourd_pull' => game.monsterParam(model.code, 'pull_period', 10.0),
      _ => 0.0,
    };
    if (period <= 0 || _abilityTimer < period) return;
    final player = game.player;
    switch (code) {
      case 'swift_wind':
        // 三昧神风：阵风把玩家吹离 200px（世界边界钳制）
        final dir = (player.position - position);
        final len = dir.length;
        if (len > 1) {
          player.position += dir.normalized() *
              game.monsterParam(model.code, 'wind_push', 200);
          player.position.x =
              player.position.x.clamp(28.0, game.worldSize - 28);
          player.position.y =
              player.position.y.clamp(28.0, game.worldSize - 28);
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '三昧神风！',
            const Color(0xFFD4A73F),
          );
        }
        _abilityTimer = 0;
        break;
      case 'samadhi_fire':
        // 三昧真火：火圈 AOE——玩家在射程内受接触伤害比例（过护甲）
        final fireRange = game.monsterParam(model.code, 'fire_range', 250.0);
        final fireRatio = game.monsterParam(model.code, 'fire_ratio', 0.8);
        if (dist <= fireRange) {
          final raw = contactDamage * fireRatio;
          player.takeDamage(
            raw *
                (1 -
                    JourneyDamageTickMixin.armorReductionRatio(player.armor,
                        curveK: game.armorCurveK)),
          );
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '三昧真火',
            const Color(0xFFD4593F),
          );
        }
        game.fxLayer.spawnRing(position, fireRange);
        _abilityTimer = 0;
        break;
      case 'gourd_pull':
        // 紫金摄魂：把玩家拉向自身（距离可配，世界边界钳制）
        final dir = position - player.position;
        final len = dir.length;
        if (len > 1) {
          player.position += dir.normalized() *
              game.monsterParam(model.code, 'pull_dist', 180);
          player.position.x =
              player.position.x.clamp(28.0, game.worldSize - 28);
          player.position.y =
              player.position.y.clamp(28.0, game.worldSize - 28);
          game.spawnFloatText(
            player.position + Vector2(0, -36),
            '紫金摄魂',
            const Color(0xFFB07CD4),
          );
        }
        _abilityTimer = 0;
        break;
    }
  }
}
