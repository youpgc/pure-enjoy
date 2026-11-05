part of 'journey_flame_game.dart';

/// 怪物实体：驻守→追击→归位三态；精灵渲染 + 体型缩放。
class JourneyMonsterComponent extends PositionComponent {
  JourneyMonsterComponent({
    required this.game,
    required this.model,
    required this.buffMult,
    required super.position,
  })  : hp = model.baseHp * buffMult,
        maxHp = model.baseHp * buffMult,
        _speed = model.baseSpeed * (0.9 + buffMult * 0.12),
        _contactDamageVal =
            model.contactDamage * (0.85 + buffMult * 0.2);

  final JourneyFlameGame game;
  final JourneyMonsterModel model;
  final double buffMult;

  double hp;
  double maxHp;
  final double _speed;
  double _contactDamageVal;

  double get _contactDamage => _contactDamageVal;

  bool isDead = false;
  bool _aggro = false;

  /// 环绕法宝命中冷却：防旋转扫过同一怪连击叠伤。
  double orbHitCd = 0;

  /// 血条显示剩余时间：受击刷新，超时渐隐（妖王血条常显不受此控）。
  double _hpBarTimer = 0;

  /// 灼烧状态（武器灼烧维度命中点燃）：剩余秒数与每秒伤害。
  double burnRemaining = 0;
  double burnDps = 0;

  /// 点燃：刷新灼烧状态（重复命中刷新持续时间）。
  void ignite({required double burnDps, required double seconds}) {
    if (isDead) return;
    this.burnDps = burnDps;
    burnRemaining = seconds;
  }

  static const double _baseRadius = 18;
  double get radius => _baseRadius * model.sizeScale;

  // 驻守坐标（脱战后归位）
  late final Vector2 home = position.clone();

  /// 侦测半径：普通怪≈屏高 0.4 口径；妖王据点用更大触发圈。
  double get aggroRange => model.isBoss ? 420 : 260;

  /// 脱战半径 = 侦测 × 1.5。
  double get leashRange => aggroRange * 1.5;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hpBarTimer > 0) {
      _hpBarTimer -= dt;
    }
    if (orbHitCd > 0) {
      orbHitCd -= dt;
    }
    if (isDead) return;

    // 灼烧掉血（武器灼烧维度）：持续期间每帧按 dps 扣血，计时归零熄灭
    if (burnRemaining > 0) {
      burnRemaining -= dt;
      takeDamage(burnDps * dt);
      if (isDead) return;
    }
    final player = game.player;
    final toPlayer = player.position - position;
    final dist = toPlayer.length;

    // 三态两半径（妖王同规则：驻点待机→侦测追击→脱战归位据点）
    if (!_aggro && dist < aggroRange) {
      _aggro = true;
    } else if (_aggro && dist > leashRange) {
      _aggro = false;
    }

    if (_aggro) {
      // 追击：直线朝玩家（分离力在 game 层统一做）
      if (dist > 1) {
        position += toPlayer.normalized() * _speed * dt;
      }
    } else {
      // 驻守：向驻守点缓慢归位 + 小幅游荡
      final toHome = home - position;
      if (toHome.length > 4) {
        position += toHome.normalized() * _speed * 0.4 * dt;
      }
    }
    position.x =
        position.x.clamp(radius, game.worldSize - radius);
    position.y =
        position.y.clamp(radius, game.worldSize - radius);
  }

  @override
  void render(Canvas canvas) {
    // 局部坐标绘制（画布已平移到本组件位置），禁止叠加 position。
    final isBoss = model.isBoss;
    // 精灵优先（monster_<code>.svg，64 视箱）；失败回落几何占位；
    // 妖王渲染倍数高于普通怪，体型压制感明显
    final pic = JourneySprites.get(JourneySprites.monster(model.code));
    if (pic != null) {
      final size = radius * (isBoss ? 3.6 : 3.0);
      JourneySprites.draw(
        canvas,
        pic,
        dstRect: Rect.fromCenter(
          center: Offset(0, radius * 0.35),
          width: size,
          height: size,
        ),
        srcWidth: 64,
        srcHeight: 64,
      );
    } else {
      final isElite = model.isElite;
      final body = isBoss
          ? const Color(0xFF8E2F3C)
          : isElite
              ? const Color(0xFFA85C3A)
              : const Color(0xFF8A4A4A);
      canvas.drawCircle(Offset.zero, radius, Paint()..color = body);
      canvas.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..color = isBoss
              ? const Color(0xFFE8C470)
              : const Color(0xFFFFFFFF).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isBoss ? 2.4 : 1.2,
      );
    }
    // 血条口径：妖王常显；普通怪受击显示、2.5s 无新受击后 0.6s 渐隐
    if (hp < maxHp && (isBoss || _hpBarTimer > 0)) {
      final alpha = isBoss
          ? 1.0
          : (_hpBarTimer / 0.6).clamp(0.0, 1.0);
      final w = radius * 2.2;
      final rect = Rect.fromCenter(
        center: Offset(0, -radius - 9),
        width: w,
        height: 4,
      );
      canvas.drawRect(rect, Paint()..color = const Color(0x66000000));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, w * (hp / maxHp), 4),
        Paint()
          ..color = (isBoss
                  ? const Color(0xFFE8C470)
                  : const Color(0xFFD4593F))
              .withValues(alpha: alpha),
      );
    }
  }

  /// 多场妖王战的逐场伤害增强（+25%/场，血量由 buffMult 承担）。
  void scaleStageDamage(int stage) {
    if (stage <= 0) return;
    _contactDamageVal = _contactDamageVal * (1.0 + stage * 0.25);
  }

  void takeDamage(double amount) {
    if (isDead) return;
    hp -= amount;
    _hpBarTimer = 2.5;
    if (hp <= 0) {
      isDead = true;
      game.onMonsterKilled(this);
      removeFromParent();
    }
  }
}
