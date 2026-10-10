part of 'tetris_game.dart';

// 交互层（part of _TetrisGameState）：棋盘手势（点按旋转 / 拖动跟随 / 软降 /
// 甩下硬降）与底部操作按钮行（橘红方块圆角键 · 白色图标文案 · 按压反馈）。

extension _TetrisInputOps on _TetrisGameState {
  /// 棋盘手势包装：左右拖动跟随移动（跨一格动一步）、下拉软降、
  /// 快速下滑（fling）硬降、点按顺时针旋转。
  Widget _buildTetrisGestureArea({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (_) {
        _rotatePiece(1);
      },
      onPanStart: (_) {
        _dragDx = 0;
        _dragDy = 0;
      },
      onPanUpdate: (d) {
        if (_finished || _current == null) return;
        _dragDx += d.delta.dx;
        _dragDy += d.delta.dy;
        // 水平：每跨过一格宽度移动一步（拖动跟随，可一次跨多格）
        while (_dragDx.abs() >= _cellExtent) {
          final sign = _dragDx > 0 ? 1 : -1;
          if (!_moveHorizontal(sign)) break;
          _dragDx -= sign * _cellExtent;
        }
        // 垂直下拉：每跨过 1.2 格软降一步（按住持续下拉持续降）
        if (_dragDy >= _cellExtent * 1.2) {
          _softDropStep();
          _dragDy = 0;
        }
      },
      onPanEnd: (d) {
        // 快速下滑 = 硬降
        if (d.velocity.pixelsPerSecond.dy > 900) {
          _hardDrop();
        }
        _dragDx = 0;
        _dragDy = 0;
      },
      child: child,
    );
  }

  /// 底部操作按钮行（2026-10-10 市场风格二次设计）：
  /// 橘红渐变方块圆角键、白色图标+文案、按下缩放/变深+触觉反馈；
  /// 「旋转」为最高频主键（更大更亮），←/→/↓ 支持长按连发。
  /// config `buttons:false` 时整行不渲染。
  Widget _buildControlBar() {
    if (!_buttonsEnabled) return const SizedBox.shrink();
    final canHold =
        _holdEnabled && !_holdUsed && _current != null && !_finished;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _TetrisActionButton(
              icon: Icons.swap_vert_circle_outlined,
              label: '暂存',
              dimmed: !canHold,
              onTap: canHold ? _holdPiece : null,
            ),
            _TetrisActionButton(
              icon: Icons.rotate_right,
              label: '旋转',
              primary: true,
              onTap: _finished ? null : () => _rotatePiece(1),
            ),
            _TetrisActionButton(
              icon: Icons.arrow_back,
              label: '左移',
              onTap: _finished ? null : () => _moveHorizontal(-1),
              repeatStep: _finished ? null : () => _moveHorizontal(-1),
            ),
            _TetrisActionButton(
              icon: Icons.arrow_downward,
              label: '软降',
              onTap: _finished ? null : _softDropStep,
              repeatStep: _finished ? null : _softDropStep,
              repeatInterval: const Duration(milliseconds: 60),
            ),
            _TetrisActionButton(
              icon: Icons.arrow_forward,
              label: '右移',
              onTap: _finished ? null : () => _moveHorizontal(1),
              repeatStep: _finished ? null : () => _moveHorizontal(1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 橘红方块圆角操作键（休闲手游立体按键风格）：
/// - 渐变底（上亮下深）+ 顶部高光条 + 橘色投影 →「方块糖」质感；
/// - 白色图标 + 白色文案；
/// - 按下反馈：缩放至 0.88 + 渐变换深 + 轻触觉（AnimatedScale 平滑恢复）；
/// - [repeatStep] 非空支持长按连发（默认 110ms，软降 60ms）。
class _TetrisActionButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// 点按动作（null=禁用态）
  final VoidCallback? onTap;

  /// 长按连发的单步动作（null=无连发）
  final VoidCallback? repeatStep;
  final Duration repeatInterval;

  /// 主键（旋转）：更大、渐变更亮
  final bool primary;

  /// 置灰（如 HOLD 已用/对局结束）：保形降饱和
  final bool dimmed;

  const _TetrisActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.repeatStep,
    this.repeatInterval = const Duration(milliseconds: 110),
    this.primary = false,
    this.dimmed = false,
  });

  @override
  State<_TetrisActionButton> createState() => _TetrisActionButtonState();
}

class _TetrisActionButtonState extends State<_TetrisActionButton> {
  bool _pressed = false;
  Timer? _repeatTimer;

  static const Color _cTop = Color(0xFFFF9243);
  static const Color _cBottom = Color(0xFFF2571B);
  static const Color _cTopDeep = Color(0xFFE86A24);
  static const Color _cBottomDeep = Color(0xFFC93E0E);
  static const Color _cShadow = Color(0x40F2571B);

  double get _size => widget.primary ? 68 : 58;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) GameAudio.instance.haptic(GameHaptic.light);
  }

  void _startRepeat() {
    if (widget.repeatStep == null) return;
    _repeatTimer?.cancel();
    _repeatTimer =
        Timer.periodic(widget.repeatInterval, (_) => widget.repeatStep!());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final disabled = !_enabled || widget.dimmed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      onTap: disabled ? null : widget.onTap,
      onLongPressStart: disabled ? null : (_) => _startRepeat(),
      onLongPressEnd: disabled
          ? null
          : (_) {
              _setPressed(false);
              _stopRepeat();
            },
      onLongPressCancel: disabled
          ? null
          : () {
              _setPressed(false);
              _stopRepeat();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled && widget.dimmed ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.primary ? 20 : 17),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _pressed
                    ? const <Color>[_cTopDeep, _cBottomDeep]
                    : widget.primary
                        ? const <Color>[Color(0xFFFFA24F), _cBottom]
                        : const <Color>[_cTop, _cBottom],
              ),
              boxShadow: _pressed
                  ? null
                  : const <BoxShadow>[
                      BoxShadow(
                          color: _cShadow,
                          blurRadius: 6,
                          offset: Offset(0, 3)),
                    ],
            ),
            child: Stack(
              children: <Widget>[
                // 顶部高光条（立体质感，按下时隐去）
                if (!_pressed)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 4,
                    child: Container(
                      height: _size * 0.22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(widget.icon,
                          size: widget.primary ? 28 : 24,
                          color: Colors.white),
                      const SizedBox(height: 2),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
