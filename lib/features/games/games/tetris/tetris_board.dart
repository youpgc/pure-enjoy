part of 'tetris_game.dart';

// 渲染层（part of _TetrisGameState）：Next/Hold 预览条、棋盘 CustomPaint
// （已落块/ghost/当前块/网格）、消行大字浮层。

extension _TetrisBoardOps on _TetrisGameState {
  /// Boss 血条（三期 T3-01，深色容器顶部）：黑底槽 + 红渐变剩余血量 +
  /// BOSS 标签。随伤害结算 setState 实时刷新。
  Widget _buildBossBar() {
    final ratio =
        _bossMaxHp <= 0 ? 0.0 : (_bossHp / _bossMaxHp).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: <Widget>[
          const Text('BOSS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCE93D8),
                  letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF171923),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF2E3245)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFFEF5350), Color(0xFFB71C1C)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$_bossHp/$_bossMaxHp',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCE93D8))),
        ],
      ),
    );
  }

  /// 顶部预览条：Hold 槽 + Next×N。
  /// 右列（深色容器内）：Hold 暂存 + Next×3 竖排 + 重开小圆钮。
  Widget _buildRightColumn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        children: <Widget>[
          if (_holdEnabled)
            _buildMiniBox(
                type: _held,
                special: _heldSpecial,
                size: 44,
                label: _holdUsed ? '·' : 'HOLD'),
          const SizedBox(height: 8),
          const Text('NEXT',
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A8FA3))),
          const SizedBox(height: 4),
          for (var i = 0; i < _nextPreview; i++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: _buildMiniBox(
                type: i < _queue.length ? _queue[i].type : null,
                special:
                    i < _queue.length ? _queue[i].special : TetrisSpecial.none,
                size: 44,
                label: '',
              ),
            ),
          const Spacer(),
          _buildRestartButton(),
          const SizedBox(height: 20),
          // 延迟结算（2026-10-10）：确认结算恒显示——达成通关条件高亮可点，
          // 未达成禁用置灰；位置在重开钮下方，间隔 20px
          _buildConfirmSettleButton(),
        ],
      ),
    );
  }

  /// 「确认结算」钮（延迟结算）：金底高亮，点击按累计值立即结算落袋。
  /// 未达成通关条件（[_goalReached] 为 false）时禁用置灰。
  Widget _buildConfirmSettleButton() {
    // 消行闪烁窗口（~360ms）内禁点：此时点结算会取消动画，
    // 正在闪烁的那波消行将不计入成绩
    final flashing = _flashTimer != null || _flashRows.isNotEmpty;
    final enabled = _goalReached && !_finished && !flashing;
    return Tooltip(
      message: enabled ? '确认结算' : '达成通关条件后可结算',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? () => _finish(true) : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFFFFD54F), Color(0xFFFFB300)],
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF5D4037)),
                  Text('结算',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037),
                          height: 1.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 「重新开始」小圆钮：二次确认后交宿主 _restartGame（aborted 口径不变）。
  Widget _buildRestartButton() {
    return Tooltip(
      message: '重新开始',
      child: Material(
        color: const Color(0xFF1E2230),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onRestart == null ? null : _confirmRestartViaHost,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.refresh,
                size: 24, color: Color(0xFF8A8FA3)),
          ),
        ),
      ),
    );
  }

  /// 紧凑预览面板（深色容器内，深底与容器融合 + 微标签）。
  /// [special] 非空时右上角叠特殊标记点（炸弹橙 / 重块灰，三期 T3-02）。
  Widget _buildMiniBox({
    required String label,
    required Tetromino? type,
    required double size,
    TetrisSpecial special = TetrisSpecial.none,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF171923),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF2E3245)),
      ),
      child: Stack(
        children: <Widget>[
          SizedBox.expand(
            child: CustomPaint(
              painter: _MiniPiecePainter(type: type),
            ),
          ),
          if (special != TetrisSpecial.none)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: special == TetrisSpecial.bomb
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF90A4AE),
                ),
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
                      flashRows: _flashRows,
                      flashPhase: _flashPhase,
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

/// 棋盘画笔：网格 + 已落块 + ghost + 当前方块 + 消行闪烁覆盖。
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
    // 消行闪烁覆盖层已移除（2026-10-10 用户反馈样式太花哨）：
    // 改为被消行格子自身向白色插值，在上方「已落块」绘制循环内处理
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
