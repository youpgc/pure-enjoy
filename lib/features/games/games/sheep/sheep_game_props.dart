part of 'sheep_game.dart';

// 本文件是 State 的 part + extension，其中的 setState 运行期完全合法（同库、
// 就是 _SheepGameState 的实例方法），但 @protected 规则不识别 extension 成员，
// 会误报 invalid_use_of_protected_member。搬回 State 类会顶破 500 行拆分，故整文件豁免。
// ignore_for_file: invalid_use_of_protected_member

/// 羊了个羊道具域（part of sheep_game，共享 State 私有状态）：
/// 确认弹窗 → 扣额度/扣库存 → 三种道具效果（移出 / 撤回 / 洗牌）。
extension _SheepPropOps on _SheepGameState {
  /// 使用道具前弹窗确认（免费次数或购买库存均先确认，避免误触消耗）。
  Future<void> _confirmUseProp(SheepProp p) async {
    if (_finished || _busy) return;
    final free = _freeLeft[p] ?? 0;
    final owned = _ownedLeft[p] ?? 0;
    if (free <= 0 && owned <= 0) return;
    final confirm =
        await confirmUsePropDialog(context, p, free, owned,
            iconAsset: _itemIcons[p]);
    if (confirm == true) {
      await _useProp(p);
    }
  }

  /// 使用道具：
  /// - 优先消耗免费额度（free_per_game），不扣库存；
  /// - 免费用尽后消耗购买库存（consumeItem 减 1 张），受 per_game_limit 截断。
  Future<void> _useProp(SheepProp p) async {
    if (_finished || _busy) return;
    final free = _freeLeft[p] ?? 0;
    final owned = _ownedLeft[p] ?? 0;
    final itemId = _itemIds[p];
    if (itemId == null) return;
    if (free <= 0 && owned <= 0) return;

    if (free > 0) {
      _freeLeft[p] = free - 1; // 免费使用
    } else {
      final ok = await GameItemService.instance.consumeItem(itemId);
      if (!ok) {
        if (mounted) setState(() => _ownedLeft[p] = 0);
        return;
      }
      _ownedLeft[p] = owned - 1;
    }

    switch (p) {
      case SheepProp.remove:
        _removeProp();
        break;
      case SheepProp.undo:
        _undo();
        break;
      case SheepProp.shuffle:
        _shuffle();
        break;
    }
  }

  void _removeProp() {
    // 「移出」= 把槽位前 3 张**放回盘面**（非删除）：
    // 全清玩法下每类卡总数为 3 的倍数，直接删除会令该类剩余数非 3 倍数，
    // 永远凑不齐三连导致必然死局（2026-09-09 用户报告）。放回时抬升到
    // 当前最高层之上，保证立即可见可点。
    final take = _slots.take(3).toList();
    if (take.isEmpty) return;
    final maxLayer = _tiles.fold<int>(0, (m, t) => t.layer > m ? t.layer : m);
    for (final t in take) {
      t.state = SheepTileState.board;
      t.slotIndex = -1;
      t.covered = false;
      t.layer = maxLayer + 1;
    }
    _slots.removeWhere((t) => take.contains(t));
    _reindexSlots();
    GameAudio.instance.prop();
    _afterProp();
  }

  void _undo() {
    if (_snapshots.isEmpty) return;
    final m = _snapshots.removeLast();
    for (final e in m.values) {
      final (t, st, idx) = e;
      // 被消除的卡补回 _tiles（对象引用恢复）
      if (!_tiles.contains(t)) _tiles.add(t);
      t.state = st;
      t.slotIndex = idx;
    }
    _rebuildSlotsFromTiles();
    _reindexSlots();
    GameAudio.instance.prop();
    _computeCoverage();
    setState(() {});
  }

  void _shuffle() {
    final board = _tiles.where((t) => t.state == SheepTileState.board).toList();
    if (board.isEmpty) return;
    final typesList = board.map((t) => t.type).toList()..shuffle(_rng);
    for (var i = 0; i < board.length; i++) {
      board[i].type = typesList[i];
    }
    GameAudio.instance.prop();
    _computeCoverage();
    setState(() {});
  }

  void _afterProp() {
    final boardLeft = _tiles.any((t) => t.state == SheepTileState.board);
    if (!boardLeft && _slots.isEmpty) {
      _finish(true);
      return;
    }
    _computeCoverage();
    setState(() {});
  }
}
