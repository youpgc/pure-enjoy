part of 'journey_flame_game.dart';

/// 环绕武器渲染（世界坐标覆盖组件，同时推进旋转相位）：
/// - 受击环带：内环~外环淡金填充 + 边界细线（伤害区间可视化）；
/// - 扇叶（bladeCount 条，等角间隔）：径向光带 + 武器 SVG 绘图
///   （纯武器内容资源，尺寸随臂长**等比**增长——长宽同系数放大）。
class JourneyOrbitWeapons extends Component {
  JourneyOrbitWeapons({required this.game});

  final JourneyFlameGame game;

  /// 环带光效混合器：状态切换时颜色与亮度按帧插值，避免激活/失效首帧跳色。
  final JourneyAuraBlend _auraBlend = JourneyAuraBlend();

  @override
  void update(double dt) {
    // dt=0 的布局期空刷不推进相位（与主类 update 短路口径一致）
    if (dt <= 0) return;
    _auraBlend.advance(journeyWeaponAura(game), dt);
    final arm = game.weaponArm;
    if (arm == null) return;
    var speed = game.spinAmp; // 全局转速乘区（转速槽/天赋/避水珠）
    // 嗜血：血量越低档位越高，逐帧并入转速乘区；满配低血时与此前
    // 全部转速来源叠加后触达下方的 5 圈/秒硬上限。
    speed += game.bloodlustAmp;
    // 悟空「大圣威压」增益期间转速额外提升（光环参数 aura_params.spin_amp，
    // 后台可配；身外身法/三头六臂为特殊能力窗口，增量固定）
    if (game._wukongBuffTimer > 0) {
      speed += game.character.auraNum('spin_amp', 0.3);
    }
    // 身外身法（wukong 特殊能力）：增益期间转速额外 +30%
    if (game._shenfenTimer > 0) speed += 0.3;
    // 三头六臂（nezha 特殊能力）：增益期间转速额外 +40%
    if (game._nezhaWindow > 0) speed += 0.4;
    // 最终角速度统一钳 5 圈/秒（10π rad/s）：speedBase×乘区超过不再增加；
    // 方向由局外设置注入（spinDirection：1=顺时针，-1=逆时针）
    arm.angle += game.spinDirection *
        (arm.speedBase * speed).clamp(0.0, 10 * math.pi) *
        dt;
  }

  @override
  void render(Canvas canvas) {
    final arm = game.weaponArm;
    if (arm == null) return;
    final center = game.player.position.toOffset();
    final inner = arm.innerRadius;
    final outer = arm.outerRadius;
    final midR = (inner + outer) / 2;
    // 光效态按混合权重渐变：环带颜色、亮度与三处透明度同时向目标插值，
    // 激活/失效都不再出现整圈瞬间提亮或突然退回底色的跳变。
    final blend = _auraBlend;
    // 底色按混合权重回落到默认鎏金：权重归零后环带/边界/扇叶恢复原色，
    // 不残留最后一种增益态的取色（原逻辑只衰减 weight，颜色会永久停在末态）。
    final auraColor =
        Color.lerp(const Color(0xFFE8C470), blend.color, blend.weight)!;
    final weight = blend.weight;
    final bandAlpha = 0.09 + (0.22 * blend.strength - 0.09) * weight;
    final edgeAlpha = 0.24 + (0.55 * blend.strength - 0.24) * weight;
    final bladeAlpha = 0.18 + (0.42 * blend.strength - 0.18) * weight;

    // 受击环带填充（淡金）+ 内外边界细线
    final bandPaint = Paint()
      ..color = auraColor.withValues(alpha: bandAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = arm.bandWidth;
    canvas.drawCircle(center, midR, bandPaint);
    final edgePaint = Paint()
      ..color = auraColor.withValues(alpha: edgeAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, inner, edgePaint);
    canvas.drawCircle(center, outer, edgePaint);

    // 武器长度=臂长（内缘→外缘径向跨度），宽高同系数等比放大：
    // 精灵方形容器随臂长整体缩放，臂长增长武器随之变长变宽
    final glyph = arm.bandWidth;
    final visHalf = arm.halfWidth * 0.72;

    final pic = JourneySprites.get(JourneySprites.weapon(game.weaponCode));
    for (var i = 0; i < game.bladeCount; i++) {
      final a = arm.angle + i * math.pi * 2 / game.bladeCount;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(a);

      // 径向光带（扇叶从容器延伸到外环）
      canvas.drawRect(
        Rect.fromLTWH(inner, -visHalf, outer - inner, visHalf * 2),
        Paint()..color = auraColor.withValues(alpha: bladeAlpha),
      );
      // 扇叶外端提亮（锋线）
      canvas.drawRect(
        Rect.fromLTWH(outer - 10, -visHalf, 10, visHalf * 2),
        Paint()
          ..color = const Color(0xFFF6E3B4).withValues(
              alpha: 0.33 + (0.72 * blend.strength - 0.33) * weight),
      );

      if (pic != null) {
        canvas.translate(midR, 0);
        canvas.rotate(math.pi / 2);
        JourneySprites.draw(
          canvas,
          pic,
          dstRect: Rect.fromCenter(
            center: Offset.zero,
            width: glyph,
            height: glyph,
          ),
          srcWidth: 48,
          srcHeight: 48,
        );
      } else {
        // 精灵缺失回落：扇叶中点菱形锋刃（不退化为球/图标）
        canvas.translate(midR, 0);
        final path = Path()
          ..moveTo(0, -visHalf * 1.6)
          ..lineTo(visHalf * 1.6, 0)
          ..lineTo(0, visHalf * 1.6)
          ..lineTo(-visHalf * 1.6, 0)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFF6E3B4));
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFB98F3E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      canvas.restore();
    }
  }
}

/// 西游扩展特效触发（金刚琢/阴阳二气瓶）：周期结算，目标取玩家武器
/// 臂长内最近存活怪（臂长受可见屏约束，不索敌屏外目标）；对局暂停时
/// 随引擎冻结（挂在伤害节拍前每帧推进）。
extension JourneyTriggerWeapons on JourneyFlameGame {
  /// 金刚琢：每 12s 套取最近怪，受 250% 武器伤害且接触伤害减半 5s；
  /// 阴阳二气瓶：每 18s 吸纳最近怪定身 2.5s，灼烧由臂展驻留判定点燃。
  /// 无目标时约 1s 后重试（计时回退到阈值前 1s，不白等一整轮）。
  void updateTriggerWeapons(double dt) {
    if (_ended) return;
    final arm = weaponArm;
    if (arm == null) return;
    final hasZhuo = effectWeapons.contains('jinggang_zhuo');
    final hasPing = effectWeapons.contains('yinyang_ping');
    if (!hasZhuo && !hasPing) return;

    JourneyMonsterComponent? nearest;
    // 索敌范围钳制在武器臂长内：臂长已被 maxArmDiameter/2 限在可见屏内，
    // 触发目标不会落在玩家看不到的屏外区域。
    var best = arm.outerRadius;
    for (final m in monsters) {
      if (m.isDead) continue;
      final d = (m.position - player.position).length;
      if (d < best) {
        best = d;
        nearest = m;
      }
    }

    if (hasZhuo) {
      final period = weaponParam('jinggang_zhuo', 'period', 12);
      if (_zhuoTimer < period) {
        _zhuoTimer = math.min(period, _zhuoTimer + dt);
      }
      final target = nearest;
      if (_zhuoTimer >= period && target != null && !target.isDead) {
        _zhuoTimer = 0;
        target.takeDamage(
          hitDamageBase * weaponParam('jinggang_zhuo', 'damage', 2.5),
        );
        target.weakenTimer = weaponParam('jinggang_zhuo', 'weak', 5);
        fxLayer.spawnRing(target.position, 26);
        spawnFloatText(
          target.position + Vector2(0, -target.radius - 14),
          '金刚琢！',
          const Color(0xFFE8C470),
        );
      }
    }

    if (hasPing) {
      final period = weaponParam('yinyang_ping', 'period', 18);
      if (_pingTimer < period) {
        _pingTimer = math.min(period, _pingTimer + dt);
      }
      final target = nearest;
      if (_pingTimer >= period && target != null && !target.isDead) {
        _pingTimer = 0;
        target.rootTimer = weaponParam('yinyang_ping', 'root', 2.5);
        fxLayer.spawnRing(target.position, 30);
        spawnFloatText(
          target.position + Vector2(0, -target.radius - 14),
          '入瓶！',
          const Color(0xFF9AD5C3),
        );
      }
    }
  }
}

