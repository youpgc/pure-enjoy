part of 'tetris_game.dart';

// 棋盘绘制器：主画布 / 炸弹与重块标记 / 迷你预览。

class _TetrisBoardPainter extends CustomPainter {
  final List<List<int?>> board;

  /// 棋盘内容版本号（board 原地写改时递增，见宿主 [_TetrisGameState._boardRev]）
  final int boardRev;
  final Piece? current;
  final int? ghostY;

  /// 消行闪烁中的满行行号与相位（0..3，一亮一暗交替，空=无动画）
  final List<int> flashRows;
  final int flashPhase;

  _TetrisBoardPainter({
    required this.board,
    required this.boardRev,
    required this.current,
    required this.ghostY,
    this.flashRows = const <int>[],
    this.flashPhase = 0,
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
    // 已落块（消行闪烁时：被消行的格子自身向白色插值，一亮一暗两轮后消失）
    for (var r = 0; r < kTetrisRows; r++) {
      final flashing = flashRows.contains(r);
      final t = flashing ? (flashPhase.isEven ? 0.85 : 0.12) : 0.0;
      for (var c = 0; c < kTetrisCols; c++) {
        final v = board[r][c];
        if (v == null) continue;
        if (v == kGarbageColorIndex) {
          if (flashing) {
            _drawCell(canvas, c * cell, r * cell, cell,
                Color.lerp(kGarbageColor, Colors.white, t)!);
          } else {
            _drawGarbageCell(canvas, c * cell, r * cell, cell);
          }
        } else {
          final base = kTetrominoColors[v];
          _drawCell(canvas, c * cell, r * cell, cell,
              flashing ? Color.lerp(base, Colors.white, t)! : base);
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
        final px = (cur.x + p.x) * cell;
        final py = y * cell;
        _drawCell(canvas, px, py, cell, color);
        // 特殊块标记（三期 T3-02）：炸弹=深色圆心+火花，重块=四角铆钉
        if (cur.special == TetrisSpecial.bomb) {
          _drawBombMark(canvas, px, py, cell);
        } else if (cur.special == TetrisSpecial.weight) {
          _drawWeightMark(canvas, px, py, cell);
        }
      }
    }
    // 消行高亮由被消行格子自身向白色插值实现，在上方「已落块」绘制循环内处理。
  }
  /// 炸弹标记：格心深色圆 + 橙色火花点（警示注入的特殊块）。
  void _drawBombMark(Canvas canvas, double x, double y, double cell) {
    canvas.drawCircle(
      Offset(x + cell / 2, y + cell / 2),
      cell * 0.22,
      Paint()..color = const Color(0xFF263238),
    );
    canvas.drawCircle(
      Offset(x + cell * 0.58, y + cell * 0.34),
      cell * 0.09,
      Paint()..color = const Color(0xFFFFB300),
    );
  }

  /// 重块标记：格内四角铆钉灰点（厚重质感）。
  void _drawWeightMark(Canvas canvas, double x, double y, double cell) {
    final paint = Paint()..color = const Color(0xFF546E7A);
    final d = cell * 0.10;
    final o = cell * 0.24;
    canvas.drawCircle(Offset(x + o, y + o), d, paint);
    canvas.drawCircle(Offset(x + cell - o, y + o), d, paint);
    canvas.drawCircle(Offset(x + o, y + cell - o), d, paint);
    canvas.drawCircle(Offset(x + cell - o, y + cell - o), d, paint);
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
      old.flashPhase != flashPhase ||
      old.flashRows.length != flashRows.length ||
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
