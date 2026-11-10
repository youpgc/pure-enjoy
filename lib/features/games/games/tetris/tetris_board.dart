part of 'tetris_game.dart';

// 渲染层（part of _TetrisGameState）：Next/Hold 预览条、棋盘 CustomPaint
// （已落块/ghost/当前块/网格）、消行大字浮层。
// ignore_for_file: invalid_use_of_protected_member
// （extension 内调宿主 setState 属 analyzer 已知误报，garbage/props 同款处理）

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
  /// 右列（深色容器内）：Hold 暂存 + Next×3 竖排 + 重开/结算/暂停圆钮。
  Widget _buildRightColumn() {
    // 列底边（暂停钮）与「棋盘游戏容器」底边持平（2026-10-11 口径：不是
    // 整个深色背景容器）：棋盘在中间区垂直居中，底边距 = (行高 - 棋盘高) / 2。
    // cell 由棋盘的 LayoutBuilder 在同帧先布局算出（Row 子级按序布局），
    // 此处直接读 _cellExtent 即为本帧值；棋盘占满高度时 gap=0 退化为贴底。
    return LayoutBuilder(
      builder: (ctx, cons) {
        final boardH = _cellExtent * kTetrisRows;
        final gap = (cons.maxHeight.isFinite && boardH > 0)
            ? ((cons.maxHeight - boardH) / 2).clamp(0.0, double.infinity)
            : 0.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, gap),
          child: Column(
        children: <Widget>[
          if (_holdEnabled)
            _buildMiniBox(
                type: _held,
                special: _heldSpecial,
                size: 44,
                label: _holdUsed ? '·' : 'HOLD'),
          const SizedBox(height: 20),
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
          // 未达成禁用置灰；重开钮下方间隔 20px
          _buildConfirmSettleButton(),
          // 暂停钮（2026-10-12 用户需求）：结算钮下方，接管列底边贴齐
          const SizedBox(height: 16),
          _buildPauseButton(),
        ],
          ),
        );
      },
    );
  }

  /// 「暂停/继续」圆钮（重开钮同款深底灰图标）：对局中切换暂停态。
  /// 暂停中图标切播放，与棋盘浮层（点任意处继续）双入口。
  Widget _buildPauseButton() {
    final paused = _isPaused;
    return Tooltip(
      message: paused ? '继续' : '暂停',
      child: Material(
        color: const Color(0xFF1E2230),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _finished ? null : _togglePause,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              paused ? Icons.play_arrow : Icons.pause,
              size: 24,
              color: paused ? const Color(0xFFFFD54F) : const Color(0xFF8A8FA3),
            ),
          ),
        ),
      ),
    );
  }

  /// 暂停浮层：盖住棋盘区（右列结算/重开/暂停钮仍可点），点任意处继续。
  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: InkWell(
          onTap: _resumeGame,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.pause_circle_outline,
                    size: 56, color: Color(0xFFFFD54F)),
                const SizedBox(height: 12),
                const Text('已暂停',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _resumeGame,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFFFFD54F), Color(0xFFFFB300)],
                        ),
                      ),
                      child: const Text('继续游戏',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // 右列（非 flex 子级）在 Row 中先于本 Expanded 布局，读到的
        // _cellExtent 是上一帧值：尺寸变化（进局/旋转/分屏）当帧让位会差
        // 一帧，挂机时无后续 setState 就一直错——变化帧排一个末帧回调
        // 补一次 rebuild 自愈（稳态值不变不排，零额外开销）
        final cellChanged = cell != _cellExtent;
        _cellExtent = cell;
        if (cellChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
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
