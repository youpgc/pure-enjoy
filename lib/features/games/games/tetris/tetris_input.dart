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

  /// 底部辅助按钮行（五键）。config `buttons:false` 时整行不渲染。
  List<Widget> _buildControlButtons() {
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _TetrisControlButton(
                icon: Icons.swap_vert_circle_outlined,
                label: 'HOLD',
                onPressed:
                    (_holdEnabled && !_holdUsed && _current != null && !_finished)
                        ? _holdPiece
                        : null,
              ),
            ),
            Expanded(
              child: _TetrisControlButton(
                icon: Icons.rotate_right,
                label: '旋转',
                onPressed: _finished ? null : () => _rotatePiece(1),
              ),
            ),
            Expanded(
              child: _TetrisRepeatButton(
                icon: Icons.arrow_back_ios_new,
                label: '左移',
                step: () => _moveHorizontal(-1),
                enabled: !_finished,
              ),
            ),
            Expanded(
              child: _TetrisRepeatButton(
                icon: Icons.arrow_downward,
                label: '软降',
                step: _softDropStep,
                enabled: !_finished,
                interval: const Duration(milliseconds: 60),
              ),
            ),
            Expanded(
              child: _TetrisRepeatButton(
                icon: Icons.arrow_forward_ios,
                label: '右移',
                step: () => _moveHorizontal(1),
                enabled: !_finished,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// 单发控制按钮（HOLD / 旋转）。
class _TetrisControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _TetrisControlButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 20),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 长按连发按钮（←/↓/→）：点按单步、长按 [interval] 连发。
class _TetrisRepeatButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// 单步动作
  final VoidCallback step;

  /// 是否启用（对局结束禁用）
  final bool enabled;

  /// 连发间隔（默认 110ms；软降更快 60ms）
  final Duration interval;

  const _TetrisRepeatButton({
    required this.icon,
    required this.label,
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
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? widget.step : null,
            onLongPressStart: widget.enabled ? (_) => _startRepeat() : null,
            onLongPressCancel: _stopRepeat,
            onLongPressEnd: widget.enabled ? (_) => _stopRepeat() : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(widget.icon, size: 20),
                  const SizedBox(height: 2),
                  Text(widget.label,
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
