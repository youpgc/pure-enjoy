import 'dart:math';

import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../services/game_item_service.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_icons.dart';
import '../../shared/game_shell.dart';
import './sheep_layout.dart';
import './sheep_props.dart';
import './sheep_tile.dart';

/// 羊了个羊（成熟手感版）
///
/// - 多层堆叠遮挡：上层方块盖住下层，仅「未遮挡」方块可点（原版核心机制）。
/// - **紧凑团簇布局**：牌堆聚成一团、层间错半格形成遮挡（布局算法见 [SheepLayout]）。
/// - 7 槽位 + 三连消除：凑齐 3 个同类自动消除；槽位溢出即失败；清空棋盘通关。
/// - 三道具（每局各 1 次）：移出 / 撤回 / 洗牌，统一收纳在底部控制栏。
/// - 公平难度：按关卡 config 的「类型数/层数/每类数」程序化生成，并用贪心模拟
///   校验可解性（保证每类数量为 3 的倍数，存在可通关顺序）。
/// - 音效 + 触感 + 方块飞入槽位动画。
class SheepGame extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 关卡（读取 config 决定难度；为 null 用默认难度）
  final GameLevelModel? level;

  const SheepGame({super.key, required this.onFinished, this.level});

  @override
  State<SheepGame> createState() => _SheepGameState();
}

class _SheepGameState extends State<SheepGame> {
  static const int _slotCapacity = 7;

  List<SheepTile> _tiles = <SheepTile>[];
  List<SheepTile> _slots = <SheepTile>[];
  /// 道具 -> 本局剩余免费次数（来自 game_items.free_per_game）
  final Map<SheepProp, int> _freeLeft = <SheepProp, int>{};
  /// 道具 -> 本局剩余购买次数（来自库存，受 per_game_limit 截断）
  final Map<SheepProp, int> _ownedLeft = <SheepProp, int>{};
  /// 道具 -> 目录 item_id（消耗库存用）
  final Map<SheepProp, String> _itemIds = <SheepProp, String>{};
  /// 道具 -> 单局使用上限（来自 game_items.per_game_limit）
  final Map<SheepProp, int> _perGameLimits = <SheepProp, int>{};
  final List<Map<int, (SheepTileState, int)>> _snapshots =
      <Map<int, (SheepTileState, int)>>[];
  bool _finished = false;
  bool _busy = false;
  late final DateTime _startTime;
  final Random _rng = Random();

  // 难度参数（来自关卡 config，带默认）
  late int _types;
  late int _layers;
  late int _perType;
  late double _overlap;

  /// 开局牌堆包围盒快照：视图缩放固定用它。若跟随消除动态重算，
  /// 边缘方块被消除后包围盒变小 → scale 变大 → 表现为「自动放大局部视图」。
  double _initMinX = 0, _initMinY = 0, _initMaxX = 1, _initMaxY = 1;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    final cfg = widget.level?.config ?? const <String, dynamic>{};
    _types = ((cfg['types'] as int?) ?? 8).clamp(3, GameIcons.fruits.length);
    _layers = ((cfg['layers'] as int?) ?? 3).clamp(1, 6);
    _perType = (((cfg['perType'] as int?) ?? 3) ~/ 3) * 3;
    if (_perType < 3) _perType = 3;
    _overlap = ((cfg['overlap'] as num?)?.toDouble() ?? 0.78).clamp(0.55, 0.95);
    _generate();
    _loadInventory();
  }

  /// 开局载入三道具：先免费用 free_per_game 次，超出部分消耗购买库存（最多 per_game_limit 次/局）。
  /// free=0 且无库存则本局不可用（对应「需购买道具卡」）。
  Future<void> _loadInventory() async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: 'sheep', mode: '');
      if (items.isEmpty) return;
      final inv = await GameItemService.instance.fetchInventory();
      for (final it in items) {
        final prop = sheepPropFromType(it.itemType);
        if (prop == null) continue;
        _itemIds[prop] = it.id;
        _perGameLimits[prop] = it.perGameLimit;
        final free = it.freePerGame;
        final limit = it.perGameLimit;
        // 本局可购买额度 = 单局上限 - 免费次数（保底 0）
        final purchasedBudget = (limit - free).clamp(0, limit);
        final owned = inv[it.id] ?? 0;
        _freeLeft[prop] = free;
        _ownedLeft[prop] = owned < purchasedBudget ? owned : purchasedBudget;
      }
      if (mounted) setState(() {});
    } catch (e) {
      // 载入失败不影响对局，仅道具不可用
    }
  }

  // ---------- 生成（可解性保证） ----------

  List<SheepTile> _buildTiles(List<(int, double, double)> pos) {
    final typeList = <int>[];
    for (var t = 0; t < _types; t++) {
      for (var k = 0; k < _perType; k++) {
        typeList.add(t);
      }
    }
    typeList.shuffle(_rng);
    final tiles = <SheepTile>[];
    for (var i = 0; i < pos.length; i++) {
      tiles.add(SheepTile(i + 1, typeList[i], pos[i].$1, pos[i].$2, pos[i].$3));
    }
    return tiles;
  }

  void _generate() {
    final total = _types * _perType;
    final layout = SheepLayout(layers: _layers, overlap: _overlap, rng: _rng);
    const solver = SheepSolver(slotCapacity: _slotCapacity);
    List<SheepTile>? result;
    for (var attempt = 0; attempt < 80; attempt++) {
      final tiles = _buildTiles(layout.generate(total));
      result = tiles;
      if (solver.solvable(tiles)) break;
    }
    _tiles = result!;
    _slots.clear();
    _snapshots.clear();
    // 道具数量改为开局从库存载入（见 _loadInventory），此处先清空
    _freeLeft.clear();
    _ownedLeft.clear();
    _finished = false;
    _busy = false;
    _computeCoverage();
    final b = SheepLayout.computeBounds(_tiles);
    _initMinX = b.$1;
    _initMinY = b.$2;
    _initMaxX = b.$3;
    _initMaxY = b.$4;
  }

  void _computeCoverage() => SheepSolver.computeCoverage(_tiles);

  // ---------- 交互 ----------

  void _pushSnapshot() {
    final m = <int, (SheepTileState, int)>{};
    for (final t in _tiles) {
      m[t.id] = (t.state, t.slotIndex);
    }
    _snapshots.add(m);
    if (_snapshots.length > 30) _snapshots.removeAt(0);
  }

  void _rebuildSlotsFromTiles() {
    _slots = _tiles
        .where((t) => t.state == SheepTileState.slot)
        .toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
  }

  void _reindexSlots() {
    for (var i = 0; i < _slots.length; i++) {
      _slots[i].slotIndex = i;
    }
  }

  void _tapTile(SheepTile tile) {
    if (_finished || _busy || tile.covered || tile.state != SheepTileState.board) {
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
    for (final t in _slots) counts[t.type] = (counts[t.type] ?? 0) + 1;
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
    final cleared = _clearTriples();
    if (cleared) {
      GameAudio.instance.match();
      GameAudio.instance.haptic(GameHaptic.medium);
    }
    final boardLeft = _tiles.any((t) => t.state == SheepTileState.board);
    if (!boardLeft && _slots.isEmpty) {
      _finish(true);
      return;
    }
    if (_slots.length > _slotCapacity) {
      _finish(false);
      return;
    }
    if (!boardLeft && _slots.isNotEmpty) {
      _finish(false); // 棋盘已空但槽位无解（死局）
      return;
    }
    _computeCoverage();
    setState(() {});
  }

  // ---------- 道具 ----------

  /// 使用道具前弹窗确认（免费次数或购买库存均先确认，避免误触消耗）。
  Future<void> _confirmUseProp(SheepProp p) async {
    if (_finished || _busy) return;
    final free = _freeLeft[p] ?? 0;
    final owned = _ownedLeft[p] ?? 0;
    if (free <= 0 && owned <= 0) return;
    final confirm = await confirmUsePropDialog(context, p, free, owned);
    if (confirm == true) {
      await _useProp(p);
    }
  }

  /// 使用道具：
  /// - 优先消耗免费额度（free_per_game），不扣库存；
  /// - 免费用尽后消耗购买库存（consumeItem 减 1 张），受 per_game_limit 截断。
  Future<void> _useProp(SheepProp p) async {
    if (_finished || _busy) return;
    var free = _freeLeft[p] ?? 0;
    var owned = _ownedLeft[p] ?? 0;
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
    final take = _slots.take(3).toList();
    if (take.isEmpty) return;
    for (final t in take) {
      t.state = SheepTileState.removing;
      _tiles.remove(t);
    }
    _slots.removeWhere((t) => take.contains(t));
    _reindexSlots();
    GameAudio.instance.prop();
    _afterProp();
  }

  void _undo() {
    if (_snapshots.isEmpty) return;
    final m = _snapshots.removeLast();
    for (final t in _tiles) {
      final s = m[t.id];
      if (s != null) {
        t.state = s.$1;
        t.slotIndex = s.$2;
      }
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

  void _finish(bool cleared) {
    if (_finished) return;
    _finished = true;
    if (cleared) {
      GameAudio.instance.win();
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{'duration_ms': elapsed},
      durationMs: elapsed,
    ));
  }

  // ---------- 布局 ----------

  @override
  Widget build(BuildContext context) {
    final boardLeft =
        _tiles.where((t) => t.state == SheepTileState.board).length;
    final nearFull = _slots.length >= _slotCapacity - 1;

    return GameShell(
      statusItems: <Widget>[
        GameStatusItem(label: '剩余方块', value: '$boardLeft'),
        GameStatusItem(
          label: '槽位',
          value: '${_slots.length}/$_slotCapacity',
          valueColor: nearFull ? AppTheme.error : null,
        ),
        GameStatusItem(label: '层数', value: '$_layers'),
      ],
      hint: '点击没被压住的方块送入下方槽位，凑齐 3 个同类自动消除；槽位放满即失败',
      // 三道具统一收纳到底部控制栏，不再叠在牌堆上方
      actions: SheepProp.values.map((p) {
        final avail = (_freeLeft[p] ?? 0) + (_ownedLeft[p] ?? 0);
        final free = _freeLeft[p] ?? 0;
        return GameAction(
          icon: p.icon,
          label: p.label,
          badge: '$avail',
          // 免费次数用角标区分：有免费剩余时提示「免」，否则显示可用数
          extraTag: free > 0 ? '免$free' : null,
          onPressed:
              (avail > 0 && !_finished && !_busy) ? () { _confirmUseProp(p); } : null,
        );
      }).toList(),
      content: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          const slotH = 82.0;
          final boardH = h - slotH;

          // 牌堆包围盒固定用开局快照 → 等比缩放居中，不随消除自动放大；
          // 0.92 整体再缩一档，方片高度更紧凑
          final minX = _initMinX;
          final minY = _initMinY;
          final pileW = max(_initMaxX - _initMinX, 0.001);
          final pileH = max(_initMaxY - _initMinY, 0.001);
          const pad = 12.0;
          final scale =
              min((w - 2 * pad) / pileW, (boardH - 2 * pad) / pileH) * 0.92;
          final drawW = pileW * scale;
          final drawH = pileH * scale;
          final offX = (w - drawW) / 2 - minX * scale;
          final offY = (boardH - drawH) / 2 - minY * scale;

          const slotPad = 8.0;
          final slotW = (w - 2 * slotPad) / _slotCapacity;
          final slotTile = min(scale, slotW * 0.86);
          final slotY = boardH + (slotH - slotTile) / 2;

          double slotCenterX(int i) => slotPad + (i + 0.5) * slotW;

          final ordered = [..._tiles]
            ..sort((a, b) {
              if (a.state == SheepTileState.board &&
                  b.state != SheepTileState.board) {
                return -1;
              }
              if (a.state != SheepTileState.board &&
                  b.state == SheepTileState.board) {
                return 1;
              }
              return a.layer.compareTo(b.layer);
            });

          final children = <Widget>[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E9DC),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            for (var i = 0; i < _slotCapacity; i++)
              Positioned(
                left: slotPad + i * slotW + 2,
                top: slotY - 4,
                width: slotW - 4,
                height: slotTile + 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                ),
              ),
            for (final t in ordered)
              buildSheepTileWidget(
                t: t,
                offX: offX,
                offY: offY,
                scale: scale,
                slotCenterX: slotCenterX,
                slotY: slotY,
                slotTile: slotTile,
                slots: _slots,
                slotCapacity: _slotCapacity,
                onTap: () => _tapTile(t),
              ),
          ];

          return Stack(children: children);
        },
      ),
    );
  }
}
