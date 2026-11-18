import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import 'journey_battle_controller.dart';
import 'journey_hp_bar_fx.dart';

/// 妖王大血条组：6+6 槽栏正下方居中，自上而下叠加当前交战妖王，
/// 一妖一条、最多三条、条间 10px。顺序由引擎维护稳定序，横幅以妖王实体
/// 为 ValueKey，保证顺位变化时受击/回血动画不串台。
class JourneyBossHpBar extends StatelessWidget {
  const JourneyBossHpBar({super.key, required this.controller});

  /// 相邻横幅上下间距。
  static const double gap = 10;

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<JourneyBossHudBar>>(
      valueListenable: controller.hud.bossBars,
      builder: (context, bars, _) {
        if (bars.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < bars.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: gap),
              JourneyBossHpBarItem(
                key: ValueKey<Object>(bars[i].key),
                bar: bars[i],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 单条妖王血条：金框暗底、左侧妖王名 + 红金渐变填充 + 条内右端绝对血量；
/// 条体复用 [JourneyHpBarFx] 的受击/回血双向动画。
class JourneyBossHpBarItem extends StatelessWidget {
  const JourneyBossHpBarItem({super.key, required this.bar});

  final JourneyBossHudBar bar;

  @override
  Widget build(BuildContext context) {
    final ratio = bar.ratio;
    final label = bar.name.isEmpty ? '妖王' : bar.name;
    final hpText = bar.maxHp > 0 ? '${bar.hp}/${bar.maxHp}' : '';
    return Container(
      width: MediaQuery.of(context).size.width * 0.81,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JourneyTheme.gold, width: 1.4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 名字按容器可用宽度定上限：超长妖王名才会走 ellipsis，
          // 血条才能拿到剩余全部空间；不设上限时 Row 的非弹性子项
          // 拿到无限宽，长名会挤空血条并溢出横幅。
          final nameMaxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth * 0.32
              : double.infinity;
          return Row(
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: nameMaxWidth),
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
                child: SizedBox(
                  height: 16,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: JourneyHpBarFx(
                          value: ratio,
                          height: 16,
                          radius: 999,
                          foregroundGradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFFB93A4A),
                              Color(0xFFE8C470),
                            ],
                          ),
                          lagColor: const Color(0xFFFFD08A),
                        ),
                      ),
                      if (hpText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              hpText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: <Shadow>[
                                  Shadow(color: Colors.black, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 小地图点阵窗（节点11）：右下角（摇杆区上方、暂停键避让位），
/// 半径 66 半透明暗底金环；CustomPaint 直读 notifier 画怪点/妖王/
/// 玩家朝向箭头，无 setState。
class JourneyMinimapWindow extends StatelessWidget {
  const JourneyMinimapWindow({super.key, required this.controller});

  /// 点阵窗边长：左上状态面板高度与之共用，保证两块 HUD 板等高。
  static const double size = 132;

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<JourneyMinimapData?>(
      valueListenable: controller.hud.minimap,
      builder: (context, data, _) => SizedBox(
        width: size,
        height: size,
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

    // 妖王大红点（全部存活妖王，含妖王潮多妖王）：双环样式突出位置
    final bossPaint = Paint()..color = const Color(0xFF8E2F3C);
    final bossRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final bp in d.bossPositions) {
      final p = _clampInside(center, center + Offset(bp.x, bp.y) * k, r - 6);
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

/// 对局横幅（节点11）：开场难名/妖王降临/伏诛/里程碑各自成条、互不覆盖，
/// 屏幕上 1/3 居中自上而下堆叠，条间 [gap]，最多 [maxEntries] 条，
/// 每条展示 [showDuration]（末段 [fadeDuration] 淡出）后移除；
/// 条身份用递增序号，顺位变化时已有横幅不重建。
class JourneyBattleBanner extends StatefulWidget {
  const JourneyBattleBanner({super.key, required this.controller});

  /// 相邻横幅上下间距。
  static const double gap = 8;

  /// 同屏条数上限，超出淘汰最旧条，避免堆叠遮挡战斗区。
  static const int maxEntries = 4;

  /// 单条横幅总展示时长。
  static const Duration showDuration = Duration(milliseconds: 2400);

  /// 到期淡出时长，计入 [showDuration]。
  static const Duration fadeDuration = Duration(milliseconds: 240);

  final JourneyBattleController controller;

  @override
  State<JourneyBattleBanner> createState() => _JourneyBattleBannerState();
}

/// 一条横幅：序号作稳定身份；到期先标记淡出、淡完才移除，
/// 到期计时器与淡出计时器各自只作用于本条。
class _BannerEntry {
  _BannerEntry(this.id, this.text);

  final int id;
  final String text;
  bool fading = true; // 新条目首帧透明，帧尾翻起触发淡入；到期另置 expiring 淡出
  bool expiring = false;
  Timer? timer;
  Timer? fadeTimer;
}

class _JourneyBattleBannerState extends State<JourneyBattleBanner> {
  final List<_BannerEntry> _entries = <_BannerEntry>[];
  int _nextId = 0;
  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.hud.banner.addListener(_onBanner);
    widget.controller.hud.milestoneText.addListener(_onMilestone);
    // 挂载前已写入的开场横幅补播一次，并清回槽位供后续同文事件触发
    _consumeBanner();
  }

  void _onBanner() => _consumeBanner();

  /// 读横幅槽位入列并清回 null——槽位留空，下次写入相同文本才会再触发通知
  void _consumeBanner() {
    final text = widget.controller.hud.banner.value;
    if (text == null || text.isEmpty) return;
    _add(text);
    // 清槽调度到帧尾——引擎可能在构建期写入（防 markNeedsBuild during build）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.hud.banner.value = null;
    });
  }

  void _onMilestone() {
    final text = widget.controller.hud.milestoneText.value;
    if (text == null || text.isEmpty) return;
    _add(text);
    // 里程碑只播一次：清回 null 调度到帧尾——引擎可能在构建期写入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.hud.milestoneText.value = null;
    });
  }

  void _add(String text) {
    while (_entries.length >= JourneyBattleBanner.maxEntries) {
      _drop(_entries.first);
    }
    final entry = _BannerEntry(_nextId++, text);
    _entries.add(entry);
    entry.timer = Timer(
      JourneyBattleBanner.showDuration - JourneyBattleBanner.fadeDuration,
      () {
        entry.expiring = true;
        _scheduleRebuild();
        entry.fadeTimer = Timer(JourneyBattleBanner.fadeDuration, () {
          _drop(entry);
          _scheduleRebuild();
        });
      },
    );
    _scheduleRebuild();
  }

  void _drop(_BannerEntry entry) {
    entry.timer?.cancel();
    entry.fadeTimer?.cancel();
    _entries.removeWhere((item) => item.id == entry.id);
  }

  /// 帧尾统一重建——引擎在 tick / build 期均可能写入 notifier；
  /// 顺带翻起新入列条目的淡入标记（首帧透明、下一帧起渐变到不透明）
  void _scheduleRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (!mounted) return;
      setState(() {
        for (final entry in _entries) {
          if (!entry.expiring) entry.fading = false;
        }
      });
    });
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.timer?.cancel();
      entry.fadeTimer?.cancel();
    }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < _entries.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: JourneyBattleBanner.gap),
              AnimatedOpacity(
                key: ValueKey<int>(_entries[i].id),
                opacity:
                    _entries[i].fading || _entries[i].expiring ? 0 : 1,
                duration: JourneyBattleBanner.fadeDuration,
                child: JourneyBanner(
                  title: _entries[i].text,
                  color: JourneyTheme.gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
