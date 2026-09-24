part of 'g2048_game.dart';

// 本文件是 State 的 part + extension，其中的 setState 运行期完全合法（同库、
// 就是 State 子类的实例方法），但 @protected 规则不识别 extension 成员，
// 会误报 invalid_use_of_protected_member。搬回 State 类会顶破 500 行拆分，故整文件豁免。
// ignore_for_file: invalid_use_of_protected_member

/// 2048 棋盘引擎（part of g2048_game，共享 State 私有状态）。
///
/// 从 g2048_game.dart 抽离（审查 P1 单文件超 500 行）：网格重建、随机生方、
/// 方向线构建、滑动合并与死局判定。纯代码搬迁，算法与日志零变更。
extension _G2048EngineOps on _G2048GameState {
  void _rebuildGrid() {
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    for (final t in _tiles) {
      if (!t.toRemove) _grid[t.row][t.col] = t;
    }
  }

  void _spawn() {
    final empties = <(int, int)>[];
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == null) empties.add((r, c));
      }
    }
    if (empties.isEmpty) return;
    final cell = empties[_rng.nextInt(empties.length)];
    final t = TileModel(
      _nextId++,
      _rng.nextInt(10) == 0 ? 4 : 2,
      cell.$1,
      cell.$2,
      isNew: true,
    );
    _tiles.add(t);
    _grid[cell.$1][cell.$2] = t;
  }

  List<List<(int, int)>> _linesFor(String dir) {
    final lines = <List<(int, int)>>[];
    if (dir == 'left' || dir == 'right') {
      for (var r = 0; r < _size; r++) {
        final cells = <(int, int)>[];
        for (var c = 0; c < _size; c++) {
          final cc = dir == 'left' ? c : _size - 1 - c;
          cells.add((r, cc));
        }
        lines.add(cells);
      }
    } else {
      for (var c = 0; c < _size; c++) {
        final cells = <(int, int)>[];
        for (var r = 0; r < _size; r++) {
          final rr = dir == 'up' ? r : _size - 1 - r;
          cells.add((rr, c));
        }
        lines.add(cells);
      }
    }
    return lines;
  }

  void _move(String dir) {
    if (_animating) {
      debugPrint('[G2048] _move 忽略：动画进行中 dir=$dir');
      return;
    }
    if (_finished) {
      debugPrint('[G2048] _move 忽略：本局已结束 dir=$dir');
      return;
    }
    debugPrint('[G2048] _move 开始 dir=$dir（size=$_size target=$_target）');
    // 关键：重置合并标记。merged 只在本回合合并判定中生效，若不重置，
    // 参与过合并的方块将永久失去合并资格 → 盘面「看似可并实则不可并」，
    // 各方向 changed=false 直接 return，表现为滑动几次后卡死无响应。
    for (final t in _tiles) {
      t.merged = false;
    }
    final lines = _linesFor(dir);
    var changed = false;
    var gain = 0;

    for (final cells in lines) {
      final lineTiles = <TileModel>[];
      for (final cell in cells) {
        final t = _grid[cell.$1][cell.$2];
        if (t != null) lineTiles.add(t);
      }
      final entries = <List<TileModel>>[];
      var i = 0;
      while (i < lineTiles.length) {
        if (i + 1 < lineTiles.length &&
            lineTiles[i].value == lineTiles[i + 1].value &&
            !lineTiles[i].merged) {
          lineTiles[i].value *= 2;
          lineTiles[i].merged = true;
          gain += lineTiles[i].value;
          _mergeCount++;
          if (lineTiles[i].value >= _target) {
            _reachedTarget = true;
          }
          entries.add([lineTiles[i], lineTiles[i + 1]]);
          i += 2;
        } else {
          entries.add([lineTiles[i]]);
          i += 1;
        }
      }
      for (var idx = 0; idx < entries.length; idx++) {
        final cell = cells[idx];
        final e = entries[idx];
        if (e.length == 2) {
          e[0].row = cell.$1;
          e[0].col = cell.$2;
          e[1].row = cell.$1;
          e[1].col = cell.$2;
          e[1].toRemove = true;
          changed = true;
        } else {
          if (e[0].row != cell.$1 || e[0].col != cell.$2) changed = true;
          e[0].row = cell.$1;
          e[0].col = cell.$2;
        }
      }
    }

    if (!changed) {
      // 无变化：不推进步数、不调度动画回调（此前 debugPrint 误放在 return
      // 之后，有变化时反而打印「无变化」，日志与实际路径相反、误导排查）
      return;
    }
    _movesUsed++;
    debugPrint('[G2048] _move 已移动 dir=$dir gain=$gain');

    if (gain > 0) {
      GameAudio.instance.merge();
      GameAudio.instance.haptic(GameHaptic.medium);
    } else {
      GameAudio.instance.tap();
      GameAudio.instance.haptic(GameHaptic.light);
    }
    _score += gain;
    if (_score > _best) {
      _best = _score;
      _persistBest();
    }
    _rebuildGrid();
    _animating = true;
    // 通关判定（双语义）：
    // - 分数目标模式（限时/挑战）：累计分达到 config.target 即通关；
    // - 方块目标模式（经典）：合成到目标方块 且 (未设分数门槛 或 累计分已达标)。
    final scoreTarget = _scoreTarget;
    _pendingWin = _isScoreGoal
        ? (_score >= _target)
        : (_reachedTarget && (scoreTarget == null || _score >= scoreTarget));
    // 无尽模式：无论是否达成目标都不通关，仅棋盘卡死时结束
    if (_noClear) _pendingWin = false;
    setState(() {});

    Future.delayed(_G2048GameState._slide + const Duration(milliseconds: 20), () {
      if (!mounted) return;
      final movesLimit = _effectiveMovesLimit;
      try {
        _tiles.removeWhere((t) => t.toRemove);
        _rebuildGrid();
        var lost = false;
        if (!_pendingWin) {
          _spawn();
          _rebuildGrid();
          if (!_hasMoves()) lost = true;
        }
        // 步数耗尽且未通关 → 失败（优先于棋盘卡死判定）
        if (!_pendingWin && movesLimit != null && _movesUsed >= movesLimit) {
          _finish(false);
        } else if (_pendingWin) {
          _finish(true);
        } else if (lost) {
          _finish(false);
        } else {
          // 动画期间缓存的滑动：立即补执行，保证输入不丢、不卡死。
          final buffered = _pendingDir;
          _pendingDir = null;
          if (buffered != null && !_finished) {
            _requestMove(buffered);
          } else {
            setState(() {});
          }
        }
      } catch (e, st) {
        // 兜底：任何异常都强制释放 _animating，避免棋盘永久冻结（滑动无响应）。
        debugPrint('[G2048] 动画回调异常，强制释放 _animating：$e');
        debugPrint('[G2048] $st');
        // 错误上报（2026-09-11）：此类异常会被静默吞掉、只表现为卡死，须后台可见
        ErrorReporter.report(e, st, module: 'games');
      } finally {
        _animating = false;
        if (mounted) setState(() {});
      }
    });
  }

  bool _hasMoves() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        // 空格存在即可动；邻居比较必须空安全——相邻格为空时 `!` 会崩
        // （Null check operator on null value），且异常被回调 catch 吞掉后
        // 连带跳过 lost 判定/结算/缓冲补执行
        final v = _grid[r][c]?.value;
        if (v == null) return true;
        if (c + 1 < _size && _grid[r][c + 1]?.value == v) {
          return true;
        }
        if (r + 1 < _size && _grid[r + 1][c]?.value == v) {
          return true;
        }
      }
    }
    return false;
  }
}
