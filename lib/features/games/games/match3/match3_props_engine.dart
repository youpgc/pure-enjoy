part of match3_flame_game;

/// 消消乐道具能力（part of match3_flame_game，共享引擎私有状态）。
///
/// 六道具引擎侧：doShuffle / smashAt / highlightHint / forceSwap /
/// magicAt / addSteps，以及 armed 待命体系与死局检测复用。
extension Match3PropsEngine on Match3FlameGame {
  // ---------- 道具能力（道具商城扩展预留，2026-09-09；入口开关见宿主页） ----------

  /// 洗牌：特殊糖原位保留，普通糖随机重排直至「无现成三连且有解」。
  ///
  /// 成功后糖果经 px/py 缓动自动滑到新格（无需额外动画）；失败（200 次
  /// 重排仍无解，极小概率）返回 false，盘面保持原状，由调用方回退处理。
  bool doShuffle() {
    if (_over || _busy) return false;
    if (!shuffleGrid(grid, rows, cols, _rng)) return false;
    _busy = true;
    GameAudio.instance.select();
    _syncHud();
    Future.delayed(Match3FlameGame._anim, () {
      if (isMounted) _busy = false;
    });
    return true;
  }

  /// 局部破坏（锤子）：直接清除指定格（特殊糖按效果引爆），目标进度/
  /// 得分/特效与普通消除同口径，随后下落补位并连锁检测。不计步数。
  void smashAt(int r, int c) {
    if (_over || _busy) return;
    final cand = grid[r][c];
    if (cand == null) return;
    _busy = true;
    final toClear = <(int, int)>{(r, c)};
    _applySpecials(toClear, const {});
    score += toClear.length * 10;
    final clearedCells = <ClearedCell>[];
    for (final cell in toClear) {
      final o = grid[cell.$1][cell.$2];
      if (o == null) continue;
      clearedCells.add(ClearedCell(
        cell.$1,
        cell.$2,
        o.type,
        special: o.special.isNotEmpty,
      ));
    }
    objective.onCleared(clearedCells);
    _syncHud();
    GameAudio.instance.match();
    GameAudio.instance.haptic(GameHaptic.medium);
    for (final cell in toClear) {
      final o = grid[cell.$1][cell.$2];
      if (o == null) continue;
      o.dying = true;
      effects.burst(
        center: _cellCenter(cell.$1, cell.$2),
        color: _palette[o.type],
        cell: _cell,
        power: o.special.isNotEmpty ? 1.8 : 1.0,
      );
    }
    combo = 1;
    Future.delayed(Match3FlameGame._anim, () {
      if (!isMounted) return;
      _removeCleared(toClear);
      _applyGravity();
      // (-1,-1,-1,-1)：swapped 空集——连锁特殊糖生成位置取 run 中位
      Future.delayed(Match3FlameGame._anim, () => _resolveCascade(-1, -1, -1, -1));
    });
  }

  /// 提示：随机高亮一组可消交换的两颗糖（各 2.5 秒脉动描边）。
  /// 无可消交换（死局）时飘字提示，不产生高亮。
  void highlightHint() {
    if (_over || _busy) return;
    final moves = findAllMoves(grid, rows, cols);
    if (moves.isEmpty) {
      effects.float(
        center: Offset(size.x / 2, _offsetY + rows * _cell * 0.42),
        text: '无可消组合',
        color: Colors.white,
        fontSize: _cell * 0.6,
      );
      return;
    }
    final (r1, c1, r2, c2) = moves[_rng.nextInt(moves.length)];
    grid[r1][c1]?.hintT = 2.5;
    grid[r2][c2]?.hintT = 2.5;
  }

  /// 强制交换：无视三连规则交换相邻两颗糖（开心消消乐同款）。
  ///
  /// 不消耗步数；交换后若形成连线照常连锁结算，未形成也生效不回退。
  /// 仅允许相邻格。返回是否执行。
  bool forceSwap(int r1, int c1, int r2, int c2) {
    if (_over || _busy) return false;
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return false;
    if (r1 < 0 || r1 >= rows || c1 < 0 || c1 >= cols) return false;
    if (r2 < 0 || r2 >= rows || c2 < 0 || c2 >= cols) return false;
    final a = grid[r1][c1];
    final b = grid[r2][c2];
    if (a == null || b == null) return false;
    _busy = true;
    grid[r1][c1] = b;
    grid[r2][c2] = a;
    a.row = r2;
    a.col = c2;
    b.row = r1;
    b.col = c1;
    GameAudio.instance.select();
    GameAudio.instance.haptic(GameHaptic.light);
    Future.delayed(Match3FlameGame._anim, () {
      if (!isMounted) return;
      if (findRuns(grid, rows, cols).isEmpty) {
        // 未形成连线：交换生效即结束
        _busy = false;
        _checkStalemate();
      } else {
        combo = 1;
        _moveScore = 0;
        _resolveCascade(r1, c1, r2, c2);
      }
    });
    return true;
  }

  /// 强制交换的两段式点击：第一次选中糖（长亮标记），第二次点相邻糖执行。
  void _handleForceSwapTap(int r, int c) {
    if (_fsR == null) {
      if (grid[r][c] == null) return;
      _fsR = r;
      _fsC = c;
      grid[r][c]?.hintT = 30; // 选中标记，长亮直至执行/取消
      return;
    }
    final fr = _fsR!;
    final fc = _fsC!;
    final adjacent = (fr - r).abs() + (fc - c).abs() == 1;
    if (!adjacent) {
      effects.float(
        center: _cellCenter(r, c),
        text: '需相邻两颗',
        color: Colors.white,
        fontSize: _cell * 0.5,
      );
      return; // 保持选中，等待合法相邻格
    }
    grid[fr][fc]?.hintT = 0;
    _fsR = _fsC = null;
    forceSwapArmed = false;
    if (forceSwap(fr, fc, r, c)) {
      onPropExecuted?.call('force_swap');
    }
    onPropStateChanged?.call();
  }

  /// 魔法棒：把指定糖变为横向条纹特效（不立即引爆，由后续消除触发）。
  /// 已是特殊糖/空格返回 false（保持待命重选）。
  bool magicAt(int r, int c) {
    if (_over || _busy) return false;
    final cand = grid[r][c];
    if (cand == null || cand.special.isNotEmpty) return false;
    cand.special = 'row';
    effects.shock(
      center: _cellCenter(r, c),
      radius: _cell * 1.2,
      color: Colors.white,
    );
    GameAudio.instance.select();
    return true;
  }

  /// 加步卡：限步模式剩余步数 +n（与 [addTime] 同构；不限步/限时忽略）。
  void addSteps(int n) {
    if (_over || objective.isTimed) return;
    if (objective.steps <= 0) return; // 不限步模式无步数概念
    movesLeft += n;
    _syncHud();
  }

  /// 死局检测（道具执行后盘面可能变化，独立于连锁稳定分支复用）。
  void _checkStalemate() {
    if (_over || objective.achieved || objective.exhausted) return;
    if (hasAnyMove(grid, rows, cols)) return;
    final handler = stalemateHandler;
    if (handler == null) {
      _finishByObjective(failReason: '无可消组合，对局结束');
    } else {
      _busy = false;
      handler().then((handled) {
        if (!handled && isMounted && !_over) {
          _finishByObjective(failReason: '无可消组合，对局结束');
        }
      });
    }
  }


}
