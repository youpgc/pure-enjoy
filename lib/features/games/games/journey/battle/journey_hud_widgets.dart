import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import 'journey_battle_controller.dart';

/// 妖王大血条（节点11）：6+6 槽栏正下方 40px 居中位，宽 81% 屏、
/// 金框暗底、左侧妖王名 + 红金渐变填充，300ms 宽度隐式动画。
/// 显示条件：hasBoss 且 bossEngaged（玩家进入妖王侦测圈）且 ratio>0
/// （开局驻守不显示，进入领地才亮；妖王倒下/脱战/无妖章回隐藏）。
class JourneyBossHpBar extends StatelessWidget {
  const JourneyBossHpBar({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    final hud = controller.hud;
    return ValueListenableBuilder<bool>(
      valueListenable: hud.hasBoss,
      builder: (context, hasBoss, _) => !hasBoss
          ? const SizedBox.shrink()
          : ValueListenableBuilder<bool>(
              valueListenable: hud.bossEngaged,
              builder: (context, engaged, _) => !engaged
                  ? const SizedBox.shrink()
                  : ValueListenableBuilder<double>(
                      valueListenable: hud.bossHpRatio,
                      builder: (context, ratio, _) => ratio <= 0
                          ? const SizedBox.shrink()
                          : ValueListenableBuilder<String>(
                              valueListenable: hud.bossName,
                              builder: (context, name, _) {
                                final label = name.isEmpty ? '妖王' : name;
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.81,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: JourneyTheme.gold,
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: JourneyTheme.faint.copyWith(
                                    color: JourneyTheme.goldSoft,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(end: ratio.clamp(0.0, 1.0)),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  builder: (context, v, _) => ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 10,
                                          color: Colors.black
                                              .withValues(alpha: 0.45),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor:
                                                v.clamp(0.0, 1.0),
                                            child: Container(
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: <Color>[
                                                    Color(0xFFB93A4A),
                                                    Color(0xFFE8C470),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            ),
    );
  }
}

/// 小地图点阵窗（节点11）：右下角（摇杆区上方、暂停键避让位），
/// 半径 66 半透明暗底金环；CustomPaint 直读 notifier 画怪点/妖王/
/// 玩家朝向箭头，无 setState。
class JourneyMinimapWindow extends StatelessWidget {
  const JourneyMinimapWindow({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<JourneyMinimapData?>(
      valueListenable: controller.hud.minimap,
      builder: (context, data, _) => SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _MinimapPainter(data)),
            ),
            Center(
              // 玩家标记：恒向上白箭头（input.vector 为普通字段非 notifier，
              // 逐帧读取需轮询，口径取规格允许的恒向上）
              child: Icon(
                Icons.navigation,
                size: 18,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 点阵画笔：暗底金环；红点=怪（offset/span×半径，钳在环内），
/// 红大点白描边=妖王（超范围时贴环缘示方向）。
class _MinimapPainter extends CustomPainter {
  const _MinimapPainter(this.data);

  final JourneyMinimapData? data;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final bg = Paint()
      ..color = const Color(0x9916121F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, bg);
    final ring = Paint()
      ..color = JourneyTheme.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, r, ring);

    final d = data;
    if (d == null) return;
    final span = d.span <= 0 ? 1000.0 : d.span;
    final k = (r - 5) / span;

    final monsterPaint = Paint()..color = const Color(0xFFD4593F);
    for (final off in d.monsterOffsets) {
      final p = _clampInside(center, center + Offset(off.x, off.y) * k, r - 4);
      canvas.drawCircle(p, 2.5, monsterPaint);
    }

    final bp = d.bossPos;
    if (bp != null) {
      final p = _clampInside(center, center + Offset(bp.x, bp.y) * k, r - 6);
      final bossPaint = Paint()..color = const Color(0xFF8E2F3C);
      final bossRing = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(p, 5, bossPaint);
      canvas.drawCircle(p, 5, bossRing);
    }
  }

  /// 点钳在圆内（方向不变，长度贴缘）。
  Offset _clampInside(Offset center, Offset p, double maxR) {
    final v = p - center;
    final len = v.distance;
    if (len <= maxR) return p;
    return center + v / len * maxR;
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter old) => old.data != data;
}

/// 对局横幅（节点11）：开场难名/妖王降临/里程碑共用位；屏幕上 1/3 居中
/// 大字金描边横幅，出现 2.4s 后自动隐去；短间隔先后触发后者覆盖重启计时。
class JourneyBattleBanner extends StatefulWidget {
  const JourneyBattleBanner({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  State<JourneyBattleBanner> createState() => _JourneyBattleBannerState();
}

class _JourneyBattleBannerState extends State<JourneyBattleBanner> {
  Timer? _timer;
  String? _text;

  static const Duration _showDuration = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    widget.controller.hud.banner.addListener(_onBanner);
    widget.controller.hud.milestoneText.addListener(_onMilestone);
    // 挂载前已写入的横幅（_setup 尾部先赋值后建图）补播一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _show(widget.controller.hud.banner.value);
      }
    });
  }

  void _onBanner() => _show(widget.controller.hud.banner.value);

  void _onMilestone() {
    // 里程碑只播一次：展示后清回 null（口径见 hud.milestoneText 注释）；
    // 清写调度到帧尾——引擎可能在构建期写入（防 markNeedsBuild during build）
    _show(widget.controller.hud.milestoneText.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.hud.milestoneText.value = null;
    });
  }

  void _show(String? text) {
    if (text == null || text.isEmpty) return;
    _timer?.cancel();
    // 构建期内引擎写入横幅（GameWidget 首帧 tick 同步于布局阶段）时，
    // setState 调度到帧尾执行，防 markNeedsBuild during build 异常
    void apply() {
      if (!mounted) return;
      setState(() => _text = text);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
    _timer = Timer(_showDuration, () {
      if (mounted) {
        setState(() => _text = null);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.hud.banner.removeListener(_onBanner);
    widget.controller.hud.milestoneText.removeListener(_onMilestone);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 无定位的 Align 不会拦截面板外的手势，摇杆可边看边玩
    return Align(
      alignment: const Alignment(0, -0.38),
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _text == null ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          child: _text == null
              ? const SizedBox.shrink()
              : JourneyBanner(title: _text!, color: JourneyTheme.gold),
        ),
      ),
    );
  }
}
