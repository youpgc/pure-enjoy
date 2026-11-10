part of 'sheep_game.dart';

// 消除规则域：点击拾取、三消判定与走子后的死局/结算判定；与主文件同库、共享其 import。
// 【误报说明】extension 内调用 _pushSnapshot/_finish 等 State 私有成员，分析器对
// part+extension 的隐式引用计数有漏计，可能误报 unused_element；extension 内调
// setState 与 @protected 规则不识别 extension 成员，运行期语义安全，一并豁免。
// ignore_for_file: unused_element, invalid_use_of_protected_member

extension _SheepGameRules on _SheepGameState {
  void _tapTile(SheepTile tile) {
    if (_finished || _busy) return;
    // 槽位已满（7/7）：不允许再放入任何方块，仅道具（移出/撤回）腾位后恢复点击。
    // 无可用错误音效，重触感提示即可。
    if (_slots.length >= _SheepGameState._slotCapacity) {
      GameAudio.instance.haptic(GameHaptic.heavy);
      return;
    }
    if (tile.covered || tile.state != SheepTileState.board) {
      return;
    }
    _pushSnapshot();
    tile.state = SheepTileState.slot;
    // 按类型归组：插入到同类方块之后（无同类则追加到末尾），保证同类三连在槽位中相邻
    var insertAt = _slots.length;
    for (var i = _slots.length - 1; i >= 0; i--) {
      if (_slots[i].type == tile.type) {
        insertAt = i + 1;
        break;
      }
    }
    _slots.insert(insertAt, tile);
    _reindexSlots();
    // 满槽（7/7）记一次失误：火眼金睛成就判定口径（mistakes ≤ 0 通关）
    if (_slots.length >= _SheepGameState._slotCapacity) {
      _mistakes++;
    }
    GameAudio.instance.select();
    GameAudio.instance.haptic(GameHaptic.light);
    _computeCoverage();
    setState(() {});
    _busy = true;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _busy = false;
      _resolveAfterMove();
    });
  }

  bool _clearTriples() {
    final counts = <int, int>{};
    for (final t in _slots) {
      counts[t.type] = (counts[t.type] ?? 0) + 1;
    }
    int? type;
    for (final e in counts.entries) {
      if (e.value >= 3) {
        type = e.key;
        break;
      }
    }
    if (type == null) return false;
    final toRemove = <SheepTile>[];
    var r = 0;
    _slots.removeWhere((t) {
      if (t.type == type && r < 3) {
        r++;
        toRemove.add(t);
        return true;
      }
      return false;
    });
    for (final t in toRemove) {
      _tiles.remove(t);
    }
    _reindexSlots();
    return true;
  }

  void _resolveAfterMove() {
    // ★ 循环消除：道具撤回等路径可在槽内同时存在两组三连，
    //   单次只清一组会让另一组滞留到下一次点击
    var clearedAny = false;
    while (_clearTriples()) {
      clearedAny = true;
      GameAudio.instance.match();
      GameAudio.instance.haptic(GameHaptic.medium);
    }
    final boardLeft = _tiles.any((t) => t.state == SheepTileState.board);
    if (!boardLeft && _slots.isEmpty) {
      _finish(true);
      return;
    }
    if (_slots.length > _SheepGameState._slotCapacity) {
      _finish(false);
      return;
    }
    if (!boardLeft && _slots.isNotEmpty) {
      _finish(false); // 棋盘已空但槽位无解（死局）
      return;
    }
    // ★ 满槽死局兜底：槽满、盘面未清、本步无可消，
    //   且移出/撤回/洗牌均无免费额度无库存 → 对局不可推进，判负
    //   （对齐原版满槽判负；持有任一道具时保留腾位机会，不触发）
    if (_slots.length >= _SheepGameState._slotCapacity && boardLeft && !clearedAny && !_hasAnySlotRelief()) {
      _finish(false);
      return;
    }
    _computeCoverage();
    setState(() {});
  }
}
