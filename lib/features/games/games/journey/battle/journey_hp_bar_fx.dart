import 'package:flutter/material.dart';

/// 血量条冲击动画（玩家血条与妖王大血条共用）：
/// 前景跟随真实血量缓动；掉血时背后点亮一段高亮残影，短暂延迟后
/// 渐变收缩到新血量，让被扣段可见、突出受击冲击；吸血/回血增长不
/// 产生残影、前景直接动画增长。
///
/// 本组件只画条体（底色 + 残影 + 前景三层），数值文案位置由调用方
/// 决定（玩家血条置条下、妖王血条叠在条内右端）。渐变前景锚定整条
/// 满宽坐标系：低血量只显示起始段（红），不把完整渐变压缩进短条。
/// 把满宽坐标系下的渐变截断到 [0, ratio] 段，使填充宽度内只显示
/// 满宽渐变的起始部分——血量越低越接近起始色（红），而非把完整
/// 渐变压缩进短条。两色等分渐变下结果与满宽采样严格一致。
LinearGradient _gradientUpTo(LinearGradient src, double ratio) {
  final colors = src.colors;
  if (colors.length < 2 || ratio <= 0 || ratio >= 1) return src;
  final stops =
      src.stops ?? List<double>.generate(colors.length, (i) => i / (colors.length - 1));

  Color sampleAt(double t) {
    if (t <= stops.first) return colors.first;
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i]) {
        final span = stops[i] - stops[i - 1];
        final local = span > 0 ? (t - stops[i - 1]) / span : 0.0;
        return Color.lerp(colors[i - 1], colors[i], local) ?? colors[i];
      }
    }
    return colors.last;
  }

  final keptColors = <Color>[];
  final keptStops = <double>[];
  for (var i = 0; i < stops.length && stops[i] < ratio; i++) {
    keptColors.add(colors[i]);
    keptStops.add(stops[i] / ratio);
  }
  keptColors.add(sampleAt(ratio));
  keptStops.add(1);
  return LinearGradient(
    begin: src.begin,
    end: src.end,
    colors: keptColors,
    stops: keptStops,
    tileMode: src.tileMode,
    transform: src.transform,
  );
}

class JourneyHpBarFx extends StatefulWidget {
  const JourneyHpBarFx({
    super.key,
    required this.value,
    this.height = 9,
    this.radius = 4,
    this.foregroundColor = const Color(0xFFE0604C),
    this.foregroundGradient,
    this.lagColor = const Color(0xFFF0A070),
  });

  /// 血量比例 0~1。
  final double value;

  /// 条高与圆角（玩家血条 9/4、妖王血条 16/999）。
  final double height;
  final double radius;

  /// 前景填充：妖王传渐变、玩家传纯色。
  final Color foregroundColor;
  final Gradient? foregroundGradient;

  /// 残影高亮色（玩家橙、妖王亮金）。
  final Color lagColor;

  @override
  State<JourneyHpBarFx> createState() => _JourneyHpBarFxState();
}

class _JourneyHpBarFxState extends State<JourneyHpBarFx>
    with SingleTickerProviderStateMixin {
  static double _clamped(double v) => v.clamp(0.0, 1.0);

  /// 残影收缩动画：前 18% 时间停在掉血前血量（露出被扣段），
  /// 其余时间缓动收缩到新血量；前景同步已缩到新值，形成冲击感。
  late final AnimationController _lagController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _impacting = false);
      }
    });

  late final Animation<double> _lagTween = CurvedAnimation(
    parent: _lagController,
    curve: const Interval(0.18, 1.0, curve: Curves.easeOut),
  );

  double _lagFrom = 0;
  double _lagTo = 0;
  bool _impacting = false;

  @override
  void initState() {
    super.initState();
    _lagFrom = _lagTo = _clamped(widget.value);
  }

  @override
  void didUpdateWidget(covariant JourneyHpBarFx oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = _clamped(widget.value);
    final prev = _clamped(oldWidget.value);
    if (v < prev - 0.001) {
      // 掉血：残影从旧血量延迟收缩到新血量
      _lagFrom = prev;
      _lagTo = v;
      _impacting = true;
      _lagController
        ..reset()
        ..forward();
    } else if (v > prev + 0.001) {
      // 吸血/回血：残影直接跟随，不产生冲击段
      _impacting = false;
      _lagController.reset();
      _lagFrom = _lagTo = v;
    }
  }

  @override
  void dispose() {
    _lagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
            AnimatedBuilder(
              animation: _lagController,
              builder: (context, _) {
                final lag = _impacting
                    ? _lagFrom + (_lagTo - _lagFrom) * _lagTween.value
                    : _clamped(widget.value);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: lag,
                    child: Container(color: widget.lagColor),
                  ),
                );
              },
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _clamped(widget.value)),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              builder: (context, v, _) {
                final ratio = v.clamp(0.0, 1.0);
                final src = widget.foregroundGradient;
                final fg = src is LinearGradient
                    ? BoxDecoration(gradient: _gradientUpTo(src, ratio))
                    : BoxDecoration(color: widget.foregroundColor);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(decoration: fg),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
