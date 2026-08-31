import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import 'g2048_tile.dart';

/// 2048（成熟手感版）
///
/// - 滑动合并：方块用 [G2048Tile] 做丝滑滑动 + 出现/合并弹跳。
/// - 触感 + 音效：每次移动轻触感 + 点击音；合并中触感 + 合并音。
/// - 最高分本地持久化（shared_preferences）。
/// - 到达 2048 记「通关」；无可移动空间记「失败」。成绩维度：score + duration_ms。
class G2048Game extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  const G2048Game({super.key, required this.onFinished});

  @override
  State<G2048Game> createState() => _G2048GameState();
}

class _G2048GameState extends State<G2048Game> {
  static const int _size = 4;
  static const int _target = 2048;
  static const Duration _slide = Duration(milliseconds: 120);

  final List<TileModel> _tiles = <TileModel>[];
  late List<List<TileModel?>> _grid;
  int _score = 0;
  int _best = 0;
  bool _animating = false;
  bool _finished = false;
  bool _pendingWin = false;
  int _nextId = 1;
  late final DateTime _startTime;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    _loadBest();
    _reset();
  }

  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      _best = sp.getInt('g2048_best') ?? 0;
      setState(() {});
    }
  }

  void _persistBest() {
    SharedPreferences.getInstance().then((sp) => sp.setInt('g2048_best', _best));
  }

  void _reset() {
    _tiles.clear();
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    _score = 0;
    _animating = false;
    _finished = false;
    _pendingWin = false;
    _spawn();
    _spawn();
  }

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
    if (_animating || _finished) return;
    final lines = _linesFor(dir);
    var changed = false;
    var gain = 0;
    var reached = false;

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
          if (lineTiles[i].value >= _target) reached = true;
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

    if (!changed) return;

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
    _pendingWin = reached;
    setState(() {});

    Future.delayed(_slide + const Duration(milliseconds: 20), () {
      if (!mounted) return;
      _tiles.removeWhere((t) => t.toRemove);
      _rebuildGrid();
      var lost = false;
      if (!_pendingWin) {
        _spawn();
        _rebuildGrid();
        if (!_hasMoves()) lost = true;
      }
      _animating = false;
      if (_pendingWin) {
        _finish(true);
      } else if (lost) {
        _finish(false);
      } else {
        setState(() {});
      }
    });
  }

  bool _hasMoves() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == null) return true;
        if (c + 1 < _size && _grid[r][c]!.value == _grid[r][c + 1]!.value) {
          return true;
        }
        if (r + 1 < _size && _grid[r][c]!.value == _grid[r + 1][c]!.value) {
          return true;
        }
      }
    }
    return false;
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
      values: <String, num>{'score': _score, 'duration_ms': elapsed},
      durationMs: elapsed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        if (v.dx.abs() > v.dy.abs()) {
          _move(v.dx > 0 ? 'right' : 'left');
        } else if (v.dy.abs() > 1) {
          _move(v.dy > 0 ? 'down' : 'up');
        }
      },
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                const Text('2048',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Spacer(),
                _statChip('得分', _score),
                const SizedBox(width: 8),
                _statChip('最高', _best),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _finished ? null : _reset,
                  child: const Text('新游戏'),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final board = constraints.maxWidth;
                final gap = board * 0.03;
                final cell = (board - gap * (_size + 1)) / _size;
                double pos(int index) => gap + index * (cell + gap);

                final children = <Widget>[
                  // 棋盘底格
                  for (var r = 0; r < _size; r++)
                    for (var c = 0; c < _size; c++)
                      Positioned(
                        left: pos(c),
                        top: pos(r),
                        width: cell,
                        height: cell,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDC1B4),
                            borderRadius: BorderRadius.circular(cell * 0.14),
                          ),
                        ),
                      ),
                  // 方块
                  for (final t in _tiles)
                    G2048Tile(
                      key: ValueKey<int>(t.id),
                      value: t.value,
                      size: cell,
                      left: pos(t.col),
                      top: pos(t.row),
                      isNew: t.isNew,
                      merged: t.merged,
                      slide: _slide,
                    ),
                ];

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBADA0),
                    borderRadius: BorderRadius.circular(gap * 2),
                  ),
                  padding: EdgeInsets.zero,
                  child: Stack(
                    children: children,
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('滑动合并相同数字，凑出 2048'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Column(
      children: <Widget>[
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF776E65))),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF776E65)),
          ),
        ),
      ],
    );
  }
}
