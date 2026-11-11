import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../utils/cache_helper.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import 'journey_battle_controller.dart';

/// 对局页覆盖组件集：虚拟摇杆 / 暂停菜单 / 还魂·炼化弹窗 / 三步引导。
/// 拆出独立文件以控制对局页行数（≤500 约定）。

/// 虚拟摇杆（左下角，触点动态浮现）：拖移驱动摇杆帽，输入向量直写
/// controller.input（引擎每帧读取），本组件自管手势状态。
class JourneyJoystick extends StatefulWidget {
  const JourneyJoystick({
    super.key,
    required this.controller,
    this.onEngage,
  });

  final JourneyBattleController controller;

  /// 玩家按下摇杆：对局页据此结束等待接管态并恢复对局运行。
  final VoidCallback? onEngage;

  @override
  State<JourneyJoystick> createState() => _JourneyJoystickState();
}

class _JourneyJoystickState extends State<JourneyJoystick> {
  Offset _stickDelta = Offset.zero;
  Offset? _stickBase; // 底座浮现位置（跟随触点，动态摇杆）

  void _onStickUpdate(DragUpdateDetails d) {
    if (_stickBase == null) return;
    final delta = d.localPosition - _stickBase!;
    const maxR = 46.0;
    final clamped =
        delta.distance <= maxR ? delta : delta / delta.distance * maxR;
    setState(() => _stickDelta = clamped);
    widget.controller.input.vector = clamped / maxR;
  }

  void _onStickEnd(DragEndDetails d) {
    setState(() {
      _stickBase = null;
      _stickDelta = Offset.zero;
    });
    widget.controller.input.reset();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Positioned(
      left: 0,
      right: 0,
      top: screenH / 2,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 底座 104：触点贴边时中心钳进安全区，底座始终完整可见不截断
          const half = 52.0;
          double clampX(double x) =>
              x.clamp(half, math.max(half, constraints.maxWidth - half));
          double clampY(double y) =>
              y.clamp(half, math.max(half, constraints.maxHeight - half));
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _onStickStart(d, clampX, clampY),
            onPanUpdate: _onStickUpdate,
            onPanEnd: _onStickEnd,
            child: Container(
              color: Colors.transparent,
              child: _stickBase == null
                  ? const SizedBox.expand()
                  : Stack(
                      children: <Widget>[
                        Positioned(
                          left: _stickBase!.dx - 52,
                          top: _stickBase!.dy - 52,
                          child: SvgPicture.asset(
                            'assets/games/journey/stick_base.svg',
                            width: 104,
                            height: 104,
                          ),
                        ),
                        Positioned(
                          left: _stickBase!.dx + _stickDelta.dx - 24,
                          top: _stickBase!.dy + _stickDelta.dy - 24,
                          child: SvgPicture.asset(
                            'assets/games/journey/stick_cap.svg',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  void _onStickStart(
    DragStartDetails d,
    double Function(double) clampX,
    double Function(double) clampY,
  ) {
    setState(() {
      // 中心钳进安全区：贴边触点也完整显示底座；拖移 delta 以可见中心为基准
      _stickBase =
          Offset(clampX(d.localPosition.dx), clampY(d.localPosition.dy));
      _stickDelta = Offset.zero;
    });
    widget.onEngage?.call();
  }
}

/// 暂停菜单浮层：继续战斗 / 属性详情 / 提前结算（妖王伏诛后） / 放弃本难。
class JourneyPauseOverlay extends StatelessWidget {
  const JourneyPauseOverlay({
    super.key,
    required this.onResume,
    required this.onAttributes,
    required this.onQuit,
    this.onEarlySettle,
  });

  final VoidCallback onResume;
  final VoidCallback onAttributes;
  final VoidCallback onQuit;

  /// 妖王伏诛后的提前结算（null=隐藏按钮）；金色主按钮强调主动出口。
  final VoidCallback? onEarlySettle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: SizedBox(
        width: 240,
        child: JourneyPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('暂 停', style: JourneyTheme.titleLg),
              const SizedBox(height: 14),
              JourneyButton(text: '继续战斗', onTap: onResume),
              const SizedBox(height: 10),
              JourneyButton(
                text: '属性详情',
                secondary: true,
                onTap: onAttributes,
              ),
              if (onEarlySettle != null) ...<Widget>[
                const SizedBox(height: 10),
                JourneyButton(text: '提前结算', onTap: onEarlySettle),
              ],
              const SizedBox(height: 10),
              JourneyButton(text: '放弃本难', secondary: true, onTap: onQuit),
            ],
          ),
        ),
      ),
    );
  }
}

/// 还魂/炼化确认弹窗（节点5/8）：对局页注入引擎回调后以 Future<bool>
/// 结果接线；引擎侧弹窗期间已 pauseEngine，关闭必经按钮路径，UI 只返回
/// true=确认 / false=放弃。
abstract final class JourneyPromptSheets {
  /// 还魂复活确认：返回 true=确认扣功德复活。
  static Future<bool> showRevive(
    BuildContext context, {
    required int cost,
    required int meritBalance,
  }) {
    return _show(
      context,
      title: '还魂复活',
      lines: <String>[
        '消耗 $cost 功德还魂复活？（单局一次）',
        '当前功德余额 $meritBalance',
      ],
      confirmText: '还魂复活',
      confirmEnabled: meritBalance >= cost,
    );
  }

  /// 宝箱炼化确认：返回 true=确认炼化（false=放弃，宝箱已消耗不退）。
  static Future<bool> showAlchemy(
    BuildContext context, {
    required String resultName,
  }) {
    return _show(
      context,
      title: '法宝炼化',
      lines: <String>[
        '满足炼化条件，将「$resultName」进化为超武法宝？',
        '放弃将消耗宝箱且不退',
      ],
      confirmText: '确认炼化',
    );
  }

  static Future<bool> _show(
    BuildContext context, {
    required String title,
    required List<String> lines,
    required String confirmText,
    String cancelText = '放弃',
    bool confirmEnabled = true,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PopScope(
        canPop: false,
        child: _PromptSheetBody(
          title: title,
          lines: lines,
          confirmText: confirmText,
          cancelText: cancelText,
          confirmEnabled: confirmEnabled,
        ),
      ),
    );
    return confirmed ?? false;
  }
}

class _PromptSheetBody extends StatelessWidget {
  const _PromptSheetBody({
    required this.title,
    required this.lines,
    required this.confirmText,
    required this.cancelText,
    this.confirmEnabled = true,
  });

  final String title;
  final List<String> lines;
  final String confirmText;
  final String cancelText;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: JourneyTheme.bgDeep.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: JourneyTheme.gold, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                title,
                style: JourneyTheme.titleLg
                    .copyWith(color: JourneyTheme.goldSoft),
              ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: JourneyTheme.body),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: JourneyButton(
                    text: cancelText,
                    secondary: true,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JourneyButton(
                    text: confirmText,
                    enabled: confirmEnabled,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 首次进关三步引导（节点12）：轻引导不暂停引擎（边玩边看），逐页点按
/// 推进；完成后写 CacheHelper 'journey_guide_done'（标记不存在即展示）。
class JourneyGuideOverlay extends StatefulWidget {
  const JourneyGuideOverlay({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<JourneyGuideOverlay> createState() => _JourneyGuideOverlayState();
}

class _JourneyGuideOverlayState extends State<JourneyGuideOverlay> {
  static const List<String> _steps = <String>[
    '拖动左下摇杆移动取经人',
    '法宝自动收割妖魔，拾取香火升级三选一',
    '循妖王罗盘（右上箭头）找到据点亮剑',
  ];

  int _step = 0;
  bool _saved = false;

  void _advance() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    if (!_saved) {
      _saved = true;
      await CacheHelper.instance
          .saveMap('journey_guide_done', <String, dynamic>{'done': true});
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps.length - 1;
    return Align(
      alignment: const Alignment(0, -0.42),
      child: GestureDetector(
        onTap: _advance,
        child: SizedBox(
          width: 300,
          child: JourneyPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    '取经指南',
                    style: JourneyTheme.titleLg,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '第 ${_step + 1}/${_steps.length} 步',
                    style: JourneyTheme.faint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[_step],
                  style: JourneyTheme.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: JourneyButton(
                        text: '跳过',
                        secondary: true,
                        onTap: _finish,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: JourneyButton(
                        text: isLast ? '开始西行' : '下一步',
                        onTap: _advance,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
