import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_icons.dart';
import './sheep_props.dart';
import './sheep_tile.dart';

/// 羊了个羊（成熟手感版）
///
/// - 多层堆叠遮挡：上层方块盖住下层，仅「未遮挡」方块可点（原版核心机制）。
/// - 7 槽位 + 三连消除：凑齐 3 个同类自动消除；槽位溢出即失败；清空棋盘通关。
/// - 三道具（每局各 1 次）：移出 / 撤回 / 洗牌，缓解死局。
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
  Map<SheepProp, int> _propRemaining = <SheepProp, int>{};
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
  }

  // ---------- 生成（可解性保证） ----------

  List<(int, double, double)> _generatePositions(int total) {
    final step = _overlap;
    final perLayer = (total / _layers).ceil();
    final area = (perLayer * step).clamp(5.0, 14.0);
    final cols = (area / step).ceil() + 1;
    final positions = <(int, double, double)>[];
    for (var l = 0; l < _layers; l++) {
      final cells = <(double, double)>[];
      for (var cx = 0; cx < cols; cx++) {
        for (var cy = 0; cy < cols; cy++) {
          cells.add((cx * step + l * 0.12, cy * step + l * 0.12));
        }
      }
      cells.shuffle(_rng);
      final take = perLayer.clamp(0, cells.length);
      for (var k = 0; k < take; k++) {
        positions.add((l, cells[k].$1, cells[k].$2));
      }
    }
    while (positions.length > total) positions.removeLast();
    while (positions.length < total) {
      positions.add((0, _rng.nextDouble() * area, _rng.nextDouble() * area));
    }
    positions.sort((a, b) => a.$1.compareTo(b.$1));
    return positions;
  }

  List<SheepTile> _buildTiles(List<(int, double, double)> pos) {
    final typeList = <int>[];
    for (var t = 0; t < _types; t++) {
      for (var k = 0; k < _perType; k++) typeList.add(t);
    }
    typeList.shuffle(_rng);
    final tiles = <SheepTile>[];
    for (var i = 0; i < pos.length; i++) {
      tiles.add(SheepTile(i + 1, typeList[i], pos[i].$1, pos[i].$2, pos[i].$3));
    }
    return tiles;
  }

  bool _rectsOverlap(SheepTile a, SheepTile b) =>
      a.x < b.x + 1 && a.x + 1 > b.x && a.y < b.y + 1 && a.y + 1 > b.y;

  void _computeCoverageOn(List<SheepTile> list) {
    for (final t in list) {
      if (t.state == SheepTileState.board) t.covered = false;
    }
    for (final a in list) {
      if (a.state != SheepTileState.board) continue;
      for (final b in list) {
        if (b.layer > a.layer &&
            b.state == SheepTileState.board &&
            _rectsOverlap(a, b)) {
          a.covered = true;
        }
      }
    }
  }

  /// 贪心模拟校验可解性（7 槽位，优先完成三连）
  bool _solvable(List<SheepTile> src) {
    final board = src
        .map((t) => SheepTile(t.id, t.type, t.layer, t.x, t.y))
        .toList();
    _computeCoverageOn(board);
    final slots = <SheepTile>[];
    var guard = 0;
    while (guard++ < 10000) {
      final counts = <int, int>{};
      for (final s in slots) counts[s.type] = (counts[s.type] ?? 0) + 1;
      int? t3;
      for (final e in counts.entries) {
        if (e.value >= 3) {
          t3 = e.key;
          break;
        }
      }
      if (t3 != null) {
        var r = 0;
        slots.removeWhere((s) {
          if (s.type == t3 && r < 3) {
            r++;
            return true;
          }
          return false;
        });
        continue;
      }
      final uncovered = board
          .where((t) => t.state == SheepTileState.board && !t.covered)
          .toList();
      if (uncovered.isEmpty) break;
      SheepTile? pick;
      for (final t in uncovered) {
        if ((counts[t.type] ?? 0) == 2) {
          pick = t;
          break;
        }
      }
      pick ??= uncovered.firstWhere(
        (t) => (counts[t.type] ?? 0) == 1,
        orElse: () => uncovered.first,
      );
      slots.add(pick);
      pick.state = SheepTileState.slot;
      _computeCoverageOn(board);
      if (slots.length > _slotCapacity) return false;
    }
    final counts = <int, int>{};
    for (final s in slots) counts[s.type] = (counts[s.type] ?? 0) + 1;
    for (final e in counts.entries) {
      if (e.value >= 3) return false;
    }
    return slots.isEmpty;
  }

  void _generate() {
    final total = _types * _perType;
    List<SheepTile>? result;
    for (var attempt = 0; attempt < 60; attempt++) {
      final pos = _generatePositions(total);
      final tiles = _buildTiles(pos);
      result = tiles;
      if (_solvable(tiles)) break;
    }
    _tiles = result!;
    _slots.clear();
    _snapshots.clear();
    _propRemaining = <SheepProp, int>{
      SheepProp.remove: 1,
      SheepProp.undo: 1,
      SheepProp.shuffle: 1,
    };
    _finished = false;
    _busy = false;
    _computeCoverage();
  }

  void _computeCoverage() => _computeCoverageOn(_tiles);

  // ---------- 交互 ----------

  void _pushSnapshot() {
    final m = <int, (SheepTileState, int)>{};
    for (final t in _tiles) m[t.id] = (t.state, t.slotIndex);
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
    for (var i = 0; i < _slots.length; i++) _slots[i].slotIndex = i;
  }

  void _tapTile(SheepTile tile) {
    if (_finished || _busy || tile.covered || tile.state != SheepTileState.board) {
      return;
    }
    _pushSnapshot();
    tile.state = SheepTileState.slot;
    tile.slotIndex = _slots.length;
    _slots.add(tile);
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
    for (final t in toRemove) _tiles.remove(t);
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

  void _useProp(SheepProp p) {
    if (_finished || _busy) return;
    if ((_propRemaining[p] ?? 0) <= 0) return;
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
    _propRemaining[SheepProp.remove] = _propRemaining[SheepProp.remove]! - 1;
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
    _propRemaining[SheepProp.undo] = _propRemaining[SheepProp.undo]! - 1;
    GameAudio.instance.prop();
    _computeCoverage();
    setState(() {});
  }

  void _shuffle() {
    final board = _tiles.where((t) => t.state == SheepTileState.board).toList();
    if (board.isEmpty) return;
    final typesList = board.map((t) => t.type).toList()..shuffle(_rng);
    for (var i = 0; i < board.length; i++) board[i].type = typesList[i];
    _propRemaining[SheepProp.shuffle] = _propRemaining[SheepProp.shuffle]! - 1;
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
    return Column(
      children: <Widget>[
        SheepPropBar(remaining: _propRemaining, onUse: _useProp),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              const slotH = 88.0;
              final boardH = h - slotH;

              double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
              for (final t in _tiles) {
                minX = min(minX, t.x);
                minY = min(minY, t.y);
                maxX = max(maxX, t.x + 1);
                maxY = max(maxY, t.y + 1);
              }
              final pileW = max(maxX - minX, 0.001);
              final pileH = max(maxY - minY, 0.001);
              const pad = 14.0;
              final scale = min((w - 2 * pad) / pileW, (boardH - 2 * pad) / pileH);
              final drawW = pileW * scale;
              final drawH = pileH * scale;
              final offX = (w - drawW) / 2 - minX * scale;
              final offY = (boardH - drawH) / 2 - minY * scale;

              final slotPad = 10.0;
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
                    margin: const EdgeInsets.all(8),
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
                  _tileWidget(t, offX, offY, scale, slotCenterX, slotY,
                      slotTile),
              ];

              return Stack(children: children);
            },
          ),
        ),
      ],
    );
  }

  Widget _tileWidget(
    SheepTile t,
    double offX,
    double offY,
    double scale,
    double Function(int) slotCenterX,
    double slotY,
    double slotTile,
  ) {
    double left;
    double top;
    double size;
    if (t.state == SheepTileState.slot) {
      final i = t.slotIndex.clamp(0, _slotCapacity - 1);
      left = slotCenterX(i) - slotTile / 2;
      top = slotY;
      size = slotTile;
    } else {
      left = offX + t.x * scale;
      top = offY + t.y * scale;
      size = scale;
    }
    return SheepTileWidget(
      key: ValueKey<int>(t.id),
      tile: t,
      left: left,
      top: top,
      size: size,
      onTap: () => _tapTile(t),
    );
  }
}
