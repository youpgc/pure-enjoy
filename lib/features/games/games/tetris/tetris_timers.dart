part of 'tetris_game.dart';

// 计时器域：垃圾砖 / 重力 / lock delay / tick 定时器 + 暂停恢复。
// 注：part + extension 中分析器不识别 extension 成员调用宿主 setState 的
// @protected 规则，会误报 invalid_use_of_protected_member；运行期语义安全，故文件级豁免。
// ignore_for_file: invalid_use_of_protected_member

extension _TetrisTimers on _TetrisGameState {
  void _startGarbageTimer() {
    _garbageTimer?.cancel();
    if (_garbageInterval <= 0) return;
    _garbageNextPushAt = DateTime.now().add(Duration(seconds: _garbageInterval));
    _garbageTimer = Timer.periodic(Duration(seconds: _garbageInterval), (_) {
      if (_finished) {
        _garbageTimer?.cancel();
        return;
      }
      if (_isPaused) return; // 暂停冻结（防御未在册重建，恢复时整体替换）
      _garbageNextPushAt = DateTime.now().add(Duration(seconds: _garbageInterval));
      if (!_pushGarbageRow()) {
        _onBlockOut();
      }
    });
  }

  void _restartGravityTimer() {
    _gravityTimer?.cancel();
    // 时缓卡生效期间下落间隔 ×2（与 marathon 局内加速叠加）
    final ms = _currentFallMs * (_isSlowed ? 2 : 1);
    _gravityTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _gravityTick();
    });
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(milliseconds: _TetrisGameState._kLockDelayMs), () {
      _lockPiece();
    });
  }

  void _restartLockTimer() => _startLockTimer();

  void _cancelLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  /// blitz 倒计时 / survival 顶起倒计时轮询（250ms 轮询、整秒变化才重建，g2048 同款节流）
  void _startTickTimer() {
    _tickTimer?.cancel();
    if (_timeLimit == null && _garbageInterval <= 0) return;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_finished) {
        timer.cancel();
        return;
      }
      if (_isPaused) return; // 暂停冻结（恢复时整体重启）
      if (_timeLimit != null && _remainingSeconds() <= 0) {
        _finish(_scoreTarget > 0 && _score >= _scoreTarget,
            reason: '时间到');
        return;
      }
      final s = _hudSecond();
      if (s != _lastTickSecond) {
        _lastTickSecond = s;
        if (mounted) setState(() {});
      }
    });
  }

  // ───────── 暂停 / 恢复 ─────────

  /// 暂停对局：取消全部周期 Timer；消行闪烁 Timer 保留但回调按 [_isPaused]
  /// 冻结（删行/计分/补块链不推进，恢复后动画续播）。截线制时刻在恢复时
  /// 统一平移，见 [_resumeGame]。
  void _pauseGame() {
    if (_finished || _isPaused || !mounted) return;
    _pausedAt = DateTime.now();
    _gravityTimer?.cancel();
    _cancelLockTimer();
    _tickTimer?.cancel();
    _garbageTimer?.cancel();
    if (mounted) setState(() {});
  }

  /// 恢复对局：暂停时长从全部截线制时刻中扣除（暂停不流逝）——blitz 倒计时
  /// 与结算用时（[_startTime] 基准）、survival 顶起点（[_garbageNextPushAt]）、
  /// 时缓卡截止（[_slowUntil]）。
  void _resumeGame() {
    if (_finished || !_isPaused || !mounted) return;
    final paused = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    _startTime = _startTime.add(paused);
    _garbageNextPushAt = _garbageNextPushAt.add(paused);
    _slowUntil = _slowUntil?.add(paused);
    _restartGravityTimer();
    _startTickTimer();
    _resumeGarbageTimer();
    // 暂停时已触底：锁定延迟冻结重启（悬空则由重力 tick 自然接管）
    if (_current != null && _isResting) _startLockTimer();
    if (mounted) setState(() {});
  }

  void _togglePause() => _isPaused ? _resumeGame() : _pauseGame();

  /// survival 顶起定时器恢复：按暂停冻结的剩余时间接续首个顶起点（暂停不
  /// 白送新周期），其后交回 [_startGarbageTimer] 恒定周期。
}
