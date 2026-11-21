part of 'journey_flame_game.dart';

/// 光束闪光持续时长（秒）。
const double kBeamFlashSec = 0.18;

/// 光束扇形半角（弧度）：命中判定与视觉绘制共用，保证判定范围与视觉张角一致。
const double kBeamHalfAngle = 0.42;

/// 并行攻击单位的 beam 光束视觉：闪光强度、方向与射程按单位 code 分槽，
/// 逐帧衰减到期移除，并绘制扇形高亮。只承载视觉状态，不参与命中判定。
class JourneyAttackBeamFx {
  final Map<String, double> _flash = <String, double>{};
  final Map<String, Vector2> _dir = <String, Vector2>{};
  final Map<String, double> _range = <String, double>{};

  /// 记录一次光束闪光，覆盖该单位旧的方向与射程并重置强度。
  void trigger(String code, Vector2 dir, double range) {
    _dir[code] = dir;
    _range[code] = range;
    _flash[code] = kBeamFlashSec;
  }

  /// 逐帧衰减所有闪光，到期移除对应槽位，防止视觉残留。
  void update(double dt) {
    for (final code in _flash.keys.toList()) {
      final next = math.max(0.0, _flash[code]! - dt);
      if (next <= 0) {
        _flash.remove(code);
        _dir.remove(code);
        _range.remove(code);
      } else {
        _flash[code] = next;
      }
    }
  }

  /// 清空全部槽位，重建单位时调用。
  void clear() {
    _flash.clear();
    _dir.clear();
    _range.clear();
  }

  /// 以给定中心点绘制所有活跃光束的扇形高亮。
  void render(Canvas canvas, Offset center) {
    for (final entry in _flash.entries) {
      final dir = _dir[entry.key];
      final range = _range[entry.key];
      if (dir == null || range == null) continue;
      final alpha = (entry.value / kBeamFlashSec).clamp(0.0, 1.0);
      final angle = math.atan2(dir.y, dir.x);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: range),
        -kBeamHalfAngle,
        2 * kBeamHalfAngle,
        true,
        Paint()..color = const Color(0xFFE8C470).withValues(alpha: 0.18 * alpha),
      );
      canvas.restore();
    }
  }
}
