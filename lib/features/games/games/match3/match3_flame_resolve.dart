part of 'match3_flame_game.dart';

/// 消消乐连锁消除与结算（part of match3_flame_game，共享引擎私有状态）。
///
/// 从 match3_flame_game.dart 抽离（审查 P1 单文件超 500 行）：连锁检测→特殊糖
/// 生成→道具引爆→计分与特效→重力补位，以及按目标判定结算。
/// 纯代码搬迁，算法、特效与结算字段零变更。
extension _Match3Resolve on Match3FlameGame {
  // ---------- 连锁消除 ----------

  void _resolveCascade(int sr1, int sc1, int sr2, int sc2, [int depth = 0]) {
    if (depth > 200) {
      _busy = false;
      return;
    }
    final runs = findRuns(grid, rows, cols);
    if (runs.isEmpty) {
      // 本步连锁结束：单次操作得分计入最高纪录
      if (_moveScore > maxSingle) maxSingle = _moveScore;
      _moveScore = 0;
      _syncHud();
      // 目标达成即刻通关；资源（步数/时间）耗尽则按目标判定成败；
      // 残局判定：盘面无任何可消交换 → 交残局处理器（洗牌道具等，未注入
      // 则判负，用户 2026-09-09 拍板 B 方案）
      if (objective.achieved || objective.exhausted) {
        _finishByObjective();
      } else if (!hasAnyMove(grid, rows, cols)) {
        final handler = stalemateHandler;
        if (handler == null) {
          _finishByObjective(failReason: '无可消组合，对局结束');
        } else {
          // 释放操作锁：洗牌路径 doShuffle 需要可执行；处理器弹窗为模态，
          // 期间玩家触不到盘面，拒绝处理后立即判负
          _busy = false;
          handler().then((handled) {
            if (!handled && isMounted && !_over) {
              _finishByObjective(failReason: '无可消组合，对局结束');
            }
          });
        }
      } else {
        _busy = false;
      }
      return;
    }

    final toClear = <(int, int)>{};
    final created = <(int, int), String>{};
    final swapped = {(sr1, sc1), (sr2, sc2)};

    for (final run in runs) {
      String? sp;
      if (run.cells.length >= 5) {
        sp = 'bomb';
      } else if (run.cells.length == 4) {
        sp = run.orient == 'h' ? 'row' : 'col';
      }
      for (final cell in run.cells) {
        toClear.add(cell);
      }
      if (sp != null) {
        final spot = run.cells.firstWhere(
          (cell) => swapped.contains(cell),
          orElse: () => run.cells[run.cells.length ~/ 2],
        );
        // 目标位已是特殊糖（道具方块）：优先消耗旧道具（留在 toClear 触发
        // 引爆），不覆盖生成新道具——防止旧道具免爆换皮（2026-09-07）
        final existing = grid[spot.$1][spot.$2];
        if (existing == null || existing.special.isEmpty) {
          created[spot] = sp;
        }
      }
    }

    // L/T 交叉 → 包装糖
    final hCells = <(int, int)>{};
    final vCells = <(int, int)>{};
    for (final run in runs) {
      for (final cell in run.cells) {
        if (run.orient == 'h') {
          hCells.add(cell);
        } else {
          vCells.add(cell);
        }
      }
    }
    for (final cell in hCells) {
      if (!vCells.contains(cell)) continue;
      // 目标位已是特殊糖：不覆盖生成，按普通消除引爆旧道具
      final existing = grid[cell.$1][cell.$2];
      if (existing == null || existing.special.isEmpty) {
        created[cell] = 'wrap';
      }
    }

    for (final cell in created.keys) {
      toClear.remove(cell);
    }
    _applySpecials(toClear, created);
    _clearedBlocks += toClear.length;

    score += toClear.length * 10 * combo;
    _moveScore += toClear.length * 10 * combo;
    if (combo > maxCombo) maxCombo = combo;

    // 目标进度累计（果冻清除 / 冰块削层 / 收集计数 / Boss 掉血）
    final clearedCells = <ClearedCell>[];
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      clearedCells.add(ClearedCell(
        cell.$1,
        cell.$2,
        cand.type,
        special: cand.special.isNotEmpty,
      ));
    }
    objective.onCleared(clearedCells);
    _syncHud();

    GameAudio.instance.match();
    GameAudio.instance.haptic(GameHaptic.medium);

    // 消除特效：碎片迸发（特殊糖加倍）+ 特殊糖生成冲击波 + 连击飘字
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      cand.dying = true;
      final special = cand.special.isNotEmpty;
      final center = _cellCenter(cell.$1, cell.$2);
      effects.burst(
        center: center,
        color: _palette[cand.type],
        cell: _cell,
        power: special ? 1.8 : 1.0,
      );
      if (!special) continue;
      effects.shock(
          center: center, radius: _cell * 1.6, color: _palette[cand.type]);
      // 条纹糖：沿整行/整列射出光带
      final horiz = cand.special == 'row';
      if (horiz || cand.special == 'col') {
        effects.beam(
          horizontal: horiz,
          centerAlong: (horiz ? size.x : size.y) / 2,
          centerCross: horiz ? center.dy : center.dx,
          length: horiz ? size.x : size.y,
          thickness: _cell * 0.5,
          color: _palette[cand.type],
        );
      }
    }
    for (final e in created.entries) {
      final cand = grid[e.key.$1][e.key.$2];
      if (cand != null) cand.special = e.value;
      effects.shock(
        center: _cellCenter(e.key.$1, e.key.$2),
        radius: _cell * 1.2,
        color: Colors.white,
      );
    }
    if (combo >= 2) {
      effects.float(
        center: Offset(size.x / 2, _offsetY + rows * _cell * 0.42),
        text: '连击 ×$combo',
        color: const Color(0xFFFFB300),
        fontSize: _cell * 0.7,
      );
    }

    combo++;
    Future.delayed(Match3FlameGame._anim, () {
      if (!isMounted) return;
      _removeCleared(toClear);
      _applyGravity();
      Future.delayed(
          Match3FlameGame._anim, () => _resolveCascade(sr1, sc1, sr2, sc2, depth + 1));
    });
  }

  void _applySpecials(
    Set<(int, int)> toClear,
    Map<(int, int), String> created,
  ) {
    final queue = <(int, int)>[];
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand != null && cand.special.isNotEmpty) queue.add(cell);
    }
    final handled = <(int, int)>{};
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      if (handled.contains(cell)) continue;
      handled.add(cell);
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      for (final ac in effectCells(cand, cell.$1, cell.$2, grid, rows, cols)) {
        if (created.containsKey(ac)) continue;
        if (toClear.add(ac)) {
          final o = grid[ac.$1][ac.$2];
          if (o != null && o.special.isNotEmpty && !handled.contains(ac)) {
            queue.add(ac);
          }
        }
      }
    }
  }

  void _removeCleared(Set<(int, int)> toClear) => removeCleared(grid, toClear);

  /// 重力下落 + 顶部补充（盘面运算下沉至 match3_runs.applyGravity）
  void _applyGravity() => applyGravity(
        grid: grid,
        rows: rows,
        cols: cols,
        offsetX: _offsetX,
        offsetY: _offsetY,
        cell: _cell,
        spawn: (r, c, x, y) =>
            Candy(_rng.nextInt(typeCount.clamp(3, _palette.length)), r, c, x, y),
      );

  /// 按当前模式的目标判定通关/失败并结算。
  ///
  /// [failReason] 非残局外的自定义失败原因（当前仅残局判负传入），
  /// 透传至结算弹窗展示（null 时弹窗显示默认失败文案）。
  void _finishByObjective({String? failReason}) {
    if (_over) return;
    _over = true;
    _pendingSwipe = null; // 对局结束，丢弃未执行的缓冲滑动
    _syncHud();
    final cleared = objective.achieved;
    if (cleared) {
      GameAudio.instance.win();
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    // 已用步数：全模式由引擎累计（限时此前恒 0 的根因修复）
    final usedMoves = objective.movesUsed;
    // 限时等路径可能跳过连锁收尾分支：结算前补记单次最高分
    if (_moveScore > maxSingle) maxSingle = _moveScore;
    _moveScore = 0;
    onFinished(GamePlayOutcome(
      cleared: cleared,
      reason: failReason,
      values: <String, num>{
        'score': score,
        'duration_ms': elapsed,
        'moves': usedMoves,
        'max_combo': maxCombo,
        'max_single': maxSingle,
        'cleared_blocks': _clearedBlocks,
        // 本局清除的果冻块数（仅果冻/消除类玩法有果冻层；其余模式恒 0）
        'jelly_cleared': objective.jelly.isEmpty
            ? 0
            : objective.jellyCount - objective.jellyLeft,
        // 本局「收集/破冰」完成数：收集模式=已收集糖果数，破冰模式=已破冰格数
        // （Match3Objective.collectedTotal 跨多目标累加）。供成就 dimension
        // `collect_done` 判定「单局完成 N 个收集/破冰目标」（2026-09-15 新增）。
        kDimensionCollectDone: objective.collectedTotal,
      },
      durationMs: elapsed,
    ));
  }
}
