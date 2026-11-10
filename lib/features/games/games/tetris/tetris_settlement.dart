part of 'tetris_game.dart';

// 结算域：_finish 落库 / 天赋点 / 成绩上报 + 宿主确认重开。
// 注：part + extension 中分析器不识别 extension 成员调用宿主 setState 的
// @protected 规则，会误报 invalid_use_of_protected_member；运行期语义安全，故文件级豁免。
// ignore_for_file: invalid_use_of_protected_member

extension _TetrisSettlement on _TetrisGameState {
  void _finish(bool cleared, {String? reason}) {
    if (_finished) return;
    _finished = true;
    _pausedAt = null; // 结束即脱离暂停态（恢复路径全部失效）
    _gravityTimer?.cancel();
    _cancelLockTimer();
    _tickTimer?.cancel();
    _garbageTimer?.cancel();
    _flashTimer?.cancel();
    _flashTimer = null;
    _flashRows = <int>[];
    if (cleared) {
      GameAudio.instance.win();
      // 每日挑战：通关写本地完成标记（当日模式卡置灰；奖励走 daily_first_clear
      // 的 claim_key 日期幂等，本地标记仅控制展示）
      if (_seedDaily && _dailyDateKey.isNotEmpty) {
        SharedPreferences.getInstance().then((sp) => sp.setString(
            'tetris_daily_done_$_dailyDateKey', '1'));
      }
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      reason: reason,
      values: <String, num>{
        'score': _score,
        'lines': _linesTotal,
        'duration_ms': elapsed,
        'pieces': _piecesPlaced,
        'tetris_count': _tetrisCount,
        'tspin_count': _tspinCount,
        'max_b2b': _maxB2b,
        'max_combo': _maxCombo,
        'perfect_clears': _perfectClears,
        'level_reached': _scoreLevel,
        if (_garbageCleared > 0) 'garbage_cleared': _garbageCleared,
      },
      durationMs: elapsed,
    ));
  }

  /// 重新开始：二次确认后交宿主 _restartGame（aborted 上报 + 引擎重建）。
  Future<void> _confirmRestartViaHost() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃当前游戏？'),
        content: const Text('点击「重新开始」将放弃当前进度，确定要重新开始吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃并重新开始'),
          ),
        ],
      ),
    );
    if (sure == true && mounted) widget.onRestart?.call();
  }

  // ───────── HUD 文案 ─────────

  String get _targetLabel {
    // 达成后仍显示初始目标值：不切「已达成 ✓」，
    // 达成状态由右下角结算钮点亮 + 「目标达成」fx 提示承载
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        // 目标固定显示总量，不随消行递减
        return '$_linesTarget 行';
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        return '$_scoreTarget 分';
      case TetrisMode.dig:
        // 挖掘固定显示预填总量；现场剩余量在 fx/玩法中呈现
        return '$_digRows 行垃圾';
      case TetrisMode.boss:
        return '血量 $_bossHp';
    }
  }

  /// Frenzy 当前倍率（blitz 专属；×1 不展示；终局最后 10s 归 1 与计分同口径）。
  bool get _frenzyActive =>
      _frenzyEnabled &&
      _combo >= 1 &&
      !(_timeLimit != null && _remainingSeconds() <= 10);

  double get _frenzyMult => 1 + 0.5 * min(_combo, 6);
}
