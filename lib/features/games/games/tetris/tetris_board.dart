part of 'tetris_game.dart';

// 渲染层（part of _TetrisGameState）：Next/Hold 预览条、棋盘 CustomPaint
// （已落块/ghost/当前块/网格）、消行大字浮层。

extension _TetrisBoardOps on _TetrisGameState {
  /// 顶部预览条：Hold 槽 + Next×N。
  Widget _buildNextHoldBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Row(
        children: <Widget>[
          if (_holdEnabled)
            _buildMiniBox(type: _held, size: 44, label: _holdUsed ? '·' : 'HOLD'),
          const Spacer(),
          for (var i = 0; i < _nextPreview; i++)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: _buildMiniBox(
                type: i < _queue.length ? _queue[i] : null,
                size: 44,
                label: i == 0 ? 'NEXT' : '',
              ),
            ),
          const SizedBox(width: 6),
          _buildRestartButton(),
        ],
      ),
    );
  }

  /// 「重新开始」小圆钮：二次确认后交宿主 _restartGame（aborted 口径不变）。
  Widget _buildRestartButton() {
    return Tooltip(
      message: '重新开始',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onRestart == null ? null : _confirmRestartViaHost,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.refresh, size: 24),
          ),
        ),
      ),
    );
  }

  /// 紧凑预览面板：mini 画布 + 底部 7px 微标签（可选，2026-10-10 铺满优化）。
  Widget _buildMiniBox({
    required String label,
    required Tetromino? type,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF171923),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Stack(
        children: <Widget>[
          SizedBox.expand(
            child: CustomPaint(
              painter: _MiniPiecePainter(type: type),
            ),
          ),
          if (label.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A8FA3),
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 棋盘（含手势），按可用空间计算单格尺寸。
  Widget _buildGestureBoard() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cell = min(
          constraints.maxWidth / kTetrisCols,
          constraints.maxHeight / kTetrisRows,
        );
        _cellExtent = cell;
        return Center(
          child: Container(
            width: cell * kTetrisCols,
            height: cell * kTetrisRows,
            decoration: BoxDecoration(
              color: const Color(0xFF101220),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2D3A), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.5),
                child: _buildTetrisGestureArea(
                  child: CustomPaint(
                    size: Size(cell * kTetrisCols, cell * kTetrisRows),
                    painter: _TetrisBoardPainter(
                      board: _board,
                      boardRev: _boardRev,
                      current: _current,
                      ghostY: _ghostEnabled && _current != null ? _ghostY() : null,
                    ),
                  ),
                ),
            ),
          ),
        );
      },
    );
  }

  /// 消行大字浮层（最新一条居中放大，其余上移淡出）。
  Widget _buildFxOverlay() {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey<String>(
                '${_fxMessages.last.text}_${_fxMessages.last.at.millisecondsSinceEpoch}'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _fxMessages.last.text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD54F),
                shadows: <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 棋盘画笔：网格 + 已落块 + ghost + 当前方块。
class _TetrisBoardPainter extends CustomPainter {
  final List<List<int?>> board;

  /// 棋盘内容版本号（board 原地写改时递增，见宿主 [_TetrisGameState._boardRev]）
  final int boardRev;
  final Piece? current;
  final int? ghostY;

  _TetrisBoardPainter({
    required this.board,
    required this.boardRev,
    required this.current,
    required this.ghostY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / kTetrisCols;
    // 网格线
    final gridPaint = Paint()
      ..color = const Color(0xFF1C1F2E)
      ..strokeWidth = 0.5;
    for (var c = 1; c < kTetrisCols; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), gridPaint);
    }
    for (var r = 1; r < kTetrisRows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), gridPaint);
    }
    // 已落块
    for (var r = 0; r < kTetrisRows; r++) {
      for (var c = 0; c < kTetrisCols; c++) {
        final v = board[r][c];
        if (v != null) {
          if (v == kGarbageColorIndex) {
            _drawGarbageCell(canvas, c * cell, r * cell, cell);
          } else {
            _drawCell(canvas, c * cell, r * cell, cell, kTetrominoColors[v]);
          }
        }
      }
    }
    // ghost 落点投影（描边 + 极淡填充）
    final cur = current;
    if (cur != null && ghostY != null && ghostY! > cur.y) {
      final ghostPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = kTetrominoColors[cur.type.index].withValues(alpha: 0.45);
      for (final p in _kCells[cur.type]![cur.rot]) {
        final rect = Rect.fromLTWH(
          (cur.x + p.x) * cell + 2,
          (ghostY! + p.y) * cell + 2,
          cell - 4,
          cell - 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0), Radius.circular(cell * 0.18)),
          ghostPaint,
        );
      }
    }
    // 当前方块
    if (cur != null) {
      final color = kTetrominoColors[cur.type.index];
      for (final p in _kCells[cur.type]![cur.rot]) {
        final y = cur.y + p.y;
        if (y < 0) continue; // 顶缓冲区不绘制
        _drawCell(canvas, (cur.x + p.x) * cell, y * cell, cell, color);
      }
    }
  }

  /// 单格：圆角矩形 + 左上高光（Block Blast 式爽感反馈的最小实现）。
  void _drawCell(Canvas canvas, double x, double y, double cell, Color color) {
    final rect = Rect.fromLTWH(x + 1, y + 1, cell - 2, cell - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 3, y + 3, cell * 0.35, cell * 0.22),
        Radius.circular(cell * 0.1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  /// 垃圾砖：哑光灰 + 裂纹点（与普通块明显区分，无高光）。
  void _drawGarbageCell(Canvas canvas, double x, double y, double cell) {
    final rect = Rect.fromLTWH(x + 1, y + 1, cell - 2, cell - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
      Paint()..color = kGarbageColor,
    );
    canvas.drawCircle(
      Offset(x + cell * 0.35, y + cell * 0.62),
      cell * 0.07,
      Paint()..color = const Color(0xFF4B5563),
    );
    canvas.drawCircle(
      Offset(x + cell * 0.66, y + cell * 0.38),
      cell * 0.055,
      Paint()..color = const Color(0xFF4B5563),
    );
  }

  @override
  bool shouldRepaint(_TetrisBoardPainter old) =>
      old.boardRev != boardRev ||
      old.current != current ||
      old.ghostY != ghostY ||
      !identical(old.board, board);
}

/// Next/Hold 预览画笔：单块居中（按 4×2 视口缩放）。
class _MiniPiecePainter extends CustomPainter {
  final Tetromino? type;

  _MiniPiecePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final t = type;
    if (t == null) return;
    final cells = _kCells[t]![0];
    final xs = cells.map((c) => c.x).toList();
    final ys = cells.map((c) => c.y).toList();
    final minX = xs.reduce(min), maxX = xs.reduce(max);
    final minY = ys.reduce(min), maxY = ys.reduce(max);
    final w = maxX - minX + 1, h = maxY - minY + 1;
    final cell = min(size.width / 4.2, size.height / 2.4);
    final ox = (size.width - w * cell) / 2 - minX * cell;
    final oy = (size.height - h * cell) / 2 - minY * cell;
    for (final p in cells) {
      final rect = Rect.fromLTWH(ox + p.x * cell + 1, oy + p.y * cell + 1,
          cell - 2, cell - 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
        Paint()..color = kTetrominoColors[t.index],
      );
    }
  }

  @override
  bool shouldRepaint(_MiniPiecePainter old) => old.type != type;
}
