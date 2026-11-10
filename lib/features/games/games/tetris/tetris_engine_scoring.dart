part of 'tetris_game.dart';

// 引擎·锁定与计分（lock/计分表/重力加速/通关检测/消行收尾/Block Out）。
// 注：part + extension 中分析器不识别 extension 成员调用宿主 setState 的
// @protected 规则，会误报 invalid_use_of_protected_member；运行期语义安全，故文件级豁免。
// ignore_for_file: invalid_use_of_protected_member

extension _TetrisEngineScoring on _TetrisGameState {
  /// 锁定当前块：写盘 → T-Spin 判定 → 满行检测。
  /// 有消行时先播放闪烁动画（_flashRows 白色高亮 4 相位 ~360ms，避免瞬间消失
  /// 过于生硬），动画结束在 [_finishLineClear] 真正删行计分；
  /// 无消行走原路径直接结算。
  void _lockPiece() {
    final p = _current;
    if (p == null || _finished || _isPaused) return;
    final spin = _detectTSpin(p);
    for (final c in _kCells[p.type]![p.rot]) {
      final r = p.y + c.y;
      final col = p.x + c.x;
      if (r >= 0 && r < kTetrisRows && col >= 0 && col < kTetrisCols) {
        _board[r][col] = p.type.index;
      }
    }
    _boardRev++;
    _current = null;
    _piecesPlaced++;
    _cancelLockTimer();
    _lockResets = 0;

    // 炸弹块引爆（三期 T3-02）：清除以锁定中心格为准的 3×3 邻域，
    // 固定 30×等级引爆分；引爆清格不算消行、不计 Boss 伤害（防刷），
    // 但可能连带拼出满行走下方正常消行流程（计分/计伤/B2B 断链照旧）。
    if (p.special == TetrisSpecial.bomb) {
      final cr = p.y + 1;
      final cc = p.x + 1;
      for (var r = cr - 1; r <= cr + 1; r++) {
        for (var c = cc - 1; c <= cc + 1; c++) {
          if (r >= 0 && r < kTetrisRows && c >= 0 && c < kTetrisCols) {
            _board[r][c] = null;
          }
        }
      }
      _score += 30 * _scoreLevel;
      _boardRev++;
      _pushFx('BOOM!');
      GameAudio.instance.haptic(GameHaptic.heavy);
    }

    // 满行检测
    final full = <int>[
      for (var r = 0; r < kTetrisRows; r++)
        if (_board[r].every((c) => c != null)) r,
    ];
    if (full.isNotEmpty) {
      // 消行动画：保留被消行原样，白色高亮一亮一暗闪 4 相位
      _flashRows = full;
      _flashPhase = 0;
      _boardRev++;
      GameAudio.instance.lineClear(full.length);
      GameAudio.instance
          .haptic(full.length >= 4 ? GameHaptic.heavy : GameHaptic.medium);
      if (mounted) setState(() {});
      _flashTimer?.cancel();
      _flashTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
        if (_isPaused) return; // 暂停冻结闪烁相位（恢复后续播，不推进删行链）
        _flashPhase++;
        if (_flashPhase >= 4) {
          t.cancel();
          _finishLineClear(spin);
          return;
        }
        _boardRev++;
        if (mounted) setState(() {});
      });
      return;
    }

    // 无消行：空锁定也要给 combo 断链语义（_applyClearScore(0)）
    GameAudio.instance.lock();
    _applyClearScore(0, spin);

    // 挑战模式块数耗尽：spawn 前结算
    if (_piecesLimit != null && _piecesPlaced >= _piecesLimit!) {
      _finish(_score >= _scoreTarget);
      return;
    }
    if (_checkWin()) return;
    _holdUsed = false;
    _spawnPiece();
  }

  /// 消行计分：基础表 × T-Spin/B2B × Combo × PC × Frenzy（blitz）。
  void _applyClearScore(int lines, _TetrisSpin? spin) {
    final lvl = _scoreLevel;
    var base = 0;
    if (spin == _TetrisSpin.full) {
      base = const <int>[400, 800, 1200, 1600][lines.clamp(0, 3)];
    } else if (spin == _TetrisSpin.mini) {
      base = const <int>[100, 200][lines.clamp(0, 1)];
    } else if (lines > 0) {
      base = const <int>[0, 100, 300, 500, 800][lines.clamp(0, 4)];
      if (lines == 4) _tetrisCount++;
    }
    if (spin != null) _tspinCount++;

    // B2B：本次为 Tetris 或任意 T-Spin 消行 → 维持/开启链；普通消行断链
    final isB2BMove = lines > 0 && (lines == 4 || spin != null);
    var b2bApplied = false;
    if (lines > 0) {
      if (isB2BMove) {
        if (_b2bActive) {
          b2bApplied = true;
          _b2bChain++;
          _maxB2b = max(_maxB2b, _b2bChain);
        } else {
          _b2bChain = 1;
        }
        _b2bActive = true;
      } else {
        _b2bChain = 0;
        _b2bActive = false;
      }
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
    } else {
      // 空锁定（如 T-Spin 0 行不消行）不推进也不打断 combo 语义：打断 combo
      _combo = 0;
    }

    var gain = 0;
    if (lines > 0 || spin != null) {
      gain = (base * lvl * (b2bApplied ? 1.5 : 1)).round();
      if (_combo >= 1) gain += 50 * _combo * lvl;
    }

    // Perfect Clear：消行后盘面全空
    if (lines > 0 && _board.every((row) => row.every((c) => c == null))) {
      gain += 3500 * lvl;
      _perfectClears++;
      _pushFx('PERFECT CLEAR!');
    }

    if (_frenzyEnabled && lines > 0) {
      // Frenzy 断连规则：倒计时最后 10s 倍率强制归 1（终局不加成）
      final mult = (_timeLimit != null && _remainingSeconds() <= 10)
          ? 1.0
          : 1 + 0.5 * min(_combo, 6);
      gain = (gain * mult).round();
    }

    _score += gain;
    if (lines > 0) {
      _linesTotal += lines;
      // 通关大字反馈（爽感反馈验收项）
      if (lines == 4) {
        _pushFx('TETRIS!');
      } else if (spin == _TetrisSpin.full) {
        _pushFx(lines > 0 ? 'T-SPIN $lines 行' : 'T-SPIN');
      } else if (spin == _TetrisSpin.mini) {
        _pushFx('T-SPIN MINI');
      } else if (_combo >= 2) {
        _pushFx('COMBO ×$_combo');
      }
      if (isB2BMove && b2bApplied) _pushFx('B2B');
      // 速度等级（仅 marathon 局内加速）：每 levelUpLines 行间隔 ×speedFactor
      _applyFallSpeed();
      // 消行音效/触觉已在闪烁动画开始时播放（_lockPiece），此处不重复
    }

    // 计分等级随消行增长（全模式）
    final newLevel = 1 + _linesTotal ~/ 10;
    if (newLevel > _scoreLevel) {
      _scoreLevel = newLevel;
      if (newLevel > 1) _pushFx('LEVEL $newLevel');
      GameAudio.instance.levelUp();
    }
    if (mounted) setState(() {});
  }

  /// 按 marathon 局内加速规则刷新重力间隔。
  void _applyFallSpeed() {
    if (_levelUpLines <= 0) return;
    final fallLevels = _linesTotal ~/ _levelUpLines;
    final ms = (_fallMsBase * pow(_speedFactor, fallLevels)).round();
    _currentFallMs = max(_fallMin, ms);
    _restartGravityTimer();
  }

  /// 通关检测（消行/计分后调用）。
  ///
  /// 延迟结算：马拉松/每日/闪电/挑战/生存五模式
  /// 首次达标不立即结束，置 [_goalReached] 继续游戏刷更高分——玩家可点
  /// 「确认结算」提前落袋，或玩到自然封顶（顶死/超时/块尽）按累计值
  /// 正常结算；竞速（用时语义）/挖掘（挖穿即胜）/Boss（血空即胜）
  /// 达标即结算不延续。
  bool _checkWin() {
    if (_finished) return true;
    if (_goalReached) return false; // 已达标待结算，不再重复判定
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        if (_linesTarget > 0 && _linesTotal >= _linesTarget) {
          if (_supportsContinue) {
            _goalReached = true;
            _pushFx('目标达成！可继续挑战');
            GameAudio.instance.levelUp();
            if (mounted) setState(() {});
            return false;
          }
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        if (_scoreTarget > 0 && _score >= _scoreTarget) {
          if (_supportsContinue) {
            _goalReached = true;
            _pushFx('目标达成！可继续挑战');
            GameAudio.instance.levelUp();
            if (mounted) setState(() {});
            return false;
          }
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.dig:
        // 挖掘：预填垃圾行全部清除即通关（挖光必然触达地板）
        if (_digRows > 0 && _garbageRowsRemaining == 0) {
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.boss:
        if (_bossMaxHp > 0 && _bossHp <= 0) {
          _finish(true);
          return true;
        }
        break;
    }
    return false;
  }

  /// 消行闪烁动画结束：真正删行（含垃圾砖统计）→ 计分 → 通关/续 spawn。
  void _finishLineClear(_TetrisSpin? spin) {
    if (_finished) return; // 闪烁期间对局可能已被超时/放弃路径结束
    // ⚠️ 必须 cancel 并把字段置 null：回调里的 t.cancel() 只取消 Timer 对象，
    // 字段仍非 null 会令「闪烁中禁点确认结算」判定恒真（按钮永远禁用）
    _flashTimer?.cancel();
    _flashTimer = null;
    final n = _flashRows.length;
    // 垃圾砖统计在删前进行（dig/digger 成就数据源）
    for (final r in _flashRows) {
      if (_board[r].contains(kGarbageColorIndex)) _garbageCleared++;
    }
    // 重建棋盘：剔除被消行、顶部补等量空行（保持行序，等价 removeAt+insert）
    final kept = <List<int?>>[
      for (var r = 0; r < kTetrisRows; r++)
        if (!_flashRows.contains(r)) _board[r],
    ];
    _board = <List<int?>>[
      for (var i = 0; i < n; i++) List<int?>.filled(kTetrisCols, null),
      ...kept,
    ];
    _flashRows = <int>[];
    _boardRev++;
    _applyClearScore(n, spin);

    // Boss 伤害结算（三期 T3-01）：普通消行 = 行数 ×1；T-Spin full +2 /
    // mini +1 额外加成；删行补空后盘面全空 = Perfect Clear，额外 +10% 最大
    // 血量。血条归零 → 通关。
    if (_bossMaxHp > 0 && n > 0) {
      var dmg = n;
      if (spin == _TetrisSpin.full) {
        dmg += 2;
      } else if (spin == _TetrisSpin.mini) {
        dmg += 1;
      }
      _bossHp = max(0, _bossHp - dmg);
      if (_board.every((row) => row.every((c) => c == null))) {
        _bossHp = max(0, _bossHp - (_bossMaxHp * 0.10).round());
        _pushFx('BOSS -10%');
      }
      if (mounted) setState(() {});
    }

    // 挑战模式块数耗尽：spawn 前结算（计分后用最新分判定，比一期更准确）
    if (_piecesLimit != null && _piecesPlaced >= _piecesLimit!) {
      _finish(_score >= _scoreTarget);
      return;
    }
    if (_checkWin()) return;
    _holdUsed = false;
    _spawnPiece();
  }

  /// Block Out（顶死）结算：达标仍算通关（最后一消恰好达标、顶死在后的情况）。
  void _onBlockOut() {
    final bool win;
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        win = _linesTarget > 0 && _linesTotal >= _linesTarget;
        break;
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        win = _scoreTarget > 0 && _score >= _scoreTarget;
        break;
      case TetrisMode.dig:
      case TetrisMode.boss:
        win = false; // 挖掘顶死=未挖穿；Boss 顶死=血量未清空
    }
    _finish(win, reason: win ? null : '方块堆到顶部，对局结束');
  }

  /// 消行大字反馈队列（board 上层浮现 1.2s 后淡出）。
  void _pushFx(String text) {
    final fx = _TetrisFx(text, DateTime.now());
    _fxMessages.add(fx);
    if (_fxMessages.length > 3) _fxMessages.removeAt(0);
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _fxMessages.isEmpty) return;
      _fxMessages.remove(fx);
      if (mounted) setState(() {});
    });
  }
}

/// 末次操作语义（T-Spin 判定依据：仅旋转末态成立）。
