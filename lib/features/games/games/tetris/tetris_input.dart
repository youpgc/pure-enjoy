part of 'tetris_game.dart';

// 交互层（part of _TetrisGameState）：棋盘手势（点按旋转 / 拖动跟随 / 软降 /
// 甩下硬降）与底部辅助按钮行（Hold/⟲/←/↓/→，长按连发）。

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

  /// 底部操作按钮行（2026-10-10 市场风格重设计）：
  /// 五键大圆形（56px，无文字，位置固定便于盲操），「旋转」为最高频主键
  /// 用主题强调色填充，其余 tonal 浅底；config `buttons:false` 时整行不渲染。
  Widget _buildControlBar() {
    if (!_buttonsEnabled) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _TetrisRoundButton(
              icon: Icons.swap_vert_circle_outlined,
              tooltip: 'HOLD（暂存）',
              onPressed:
                  (_holdEnabled && !_holdUsed && _current != null && !_finished)
                      ? _holdPiece
                      : null,
            ),
            _TetrisRoundButton(
              icon: Icons.rotate_right,
              tooltip: '旋转',
              primary: true,
              big: true,
              onPressed: _finished ? null : () => _rotatePiece(1),
            ),
            _TetrisRepeatButton(
              icon: Icons.arrow_back,
              tooltip: '左移',
              step: () => _moveHorizontal(-1),
              enabled: !_finished,
            ),
            _TetrisRepeatButton(
              icon: Icons.arrow_downward,
              tooltip: '软降',
              step: _softDropStep,
              enabled: !_finished,
              interval: const Duration(milliseconds: 60),
            ),
            _TetrisRepeatButton(
              icon: Icons.arrow_forward,
              tooltip: '右移',
              step: () => _moveHorizontal(1),
              enabled: !_finished,
            ),
          ],
        ),
      ),
    );
  }
}

/// 大圆形操作按钮（56px / 主键 64px）：图标为主、无文字——
/// 参考热门俄罗斯方块手游的圆形触控钮设计；主键强调色填充。
class _TetrisRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final bool big;

  const _TetrisRoundButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.primary = false,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final size = big ? 64.0 : 56.0;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.10),
                border: Border.all(
                  color: primary
                      ? Colors.transparent
                      : theme.colorScheme.primary.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Icon(
                icon,
                size: big ? 32 : 26,
                color: primary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 长按连发圆形按钮（←/↓/→）：点按单步、长按 [interval] 连发。
class _TetrisRepeatButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;

  /// 单步动作
  final VoidCallback step;

  /// 是否启用（对局结束禁用）
  final bool enabled;

  /// 连发间隔（默认 110ms；软降更快 60ms）
  final Duration interval;

  const _TetrisRepeatButton({
    required this.icon,
    required this.tooltip,
    required this.step,
    required this.enabled,
    this.interval = const Duration(milliseconds: 110),
  });

  @override
  State<_TetrisRepeatButton> createState() => _TetrisRepeatButtonState();
}

class _TetrisRepeatButtonState extends State<_TetrisRepeatButton> {
  Timer? _timer;

  void _startRepeat() {
    if (!widget.enabled) return;
    widget.step();
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => widget.step());
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.step : null,
          onLongPressStart: widget.enabled ? (_) => _startRepeat() : null,
          onLongPressCancel: _stopRepeat,
          onLongPressEnd: widget.enabled ? (_) => _stopRepeat() : null,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Icon(widget.icon,
                    size: 26, color: theme.colorScheme.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
