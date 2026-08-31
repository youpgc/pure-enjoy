import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../game_play_helpers.dart';

/// 消消乐（Flame 引擎实现）
///
/// 8x8 网格，点击两个相邻方块交换；若形成 ≥3 连则消除并计分，
/// 上方方块下落补充，连锁继续。剩余步数耗尽即结束（cleared=true，成绩=得分）。
class Match3FlameGame extends FlameGame with TapCallbacks {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 分数 / 步数通知（供 Flutter 层叠加展示）
  final ValueNotifier<int> scoreNotifier;
  final ValueNotifier<int> movesNotifier;

  final int rows;
  final int cols;
  final int moveLimit;

  List<List<int>> grid = <List<int>>[];
  int score = 0;
  int movesLeft = 0;
  final DateTime _startTime = DateTime.now();
  bool _finished = false;
  bool _loaded = false;

  int? _selectedR;
  int? _selectedC;
  late double _cell;
  final Random _rng = Random();
  final List<RectangleComponent> _comps = <RectangleComponent>[];
  final List<Color> _palette = <Color>[
    const Color(0xFFEF5350),
    const Color(0xFF42A5F5),
    const Color(0xFF66BB6A),
    const Color(0xFFFFEE58),
    const Color(0xFFAB47BC),
    const Color(0xFFFFA726),
  ];

  Match3FlameGame({
    required this.onFinished,
    required this.scoreNotifier,
    required this.movesNotifier,
    this.rows = 8,
    this.cols = 8,
    this.moveLimit = 20,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _cell = (size.x / cols).clamp(0, size.y / rows);
    _newBoard();
    movesLeft = moveLimit;
    movesNotifier.value = movesLeft;
    scoreNotifier.value = score;
    _rebuildTiles();
    _loaded = true;
  }

  Vector2 _cellCenter(int r, int c) =>
      Vector2(c * _cell + _cell / 2, r * _cell + _cell / 2);

  void _newBoard() {
    do {
      grid = List.generate(
        rows,
        (_) => List.generate(cols, (_) => _rng.nextInt(_palette.length)),
      );
    } while (_findMatches().isNotEmpty);
  }

  Set<Point> _findMatches() {
    final s = <Point>{};
    // 水平
    for (var r = 0; r < rows; r++) {
      var runStart = 0;
      for (var c = 1; c <= cols; c++) {
        if (c < cols && grid[r][c] != 0 && grid[r][c] == grid[r][runStart]) {
          continue;
        }
        final len = c - runStart;
        if (grid[r][runStart] != 0 && len >= 3) {
          for (var k = runStart; k < c; k++) {
            s.add(Point(r, k));
          }
        }
        runStart = c;
      }
    }
    // 垂直
    for (var c = 0; c < cols; c++) {
      var runStart = 0;
      for (var r = 1; r <= rows; r++) {
        if (r < rows && grid[r][c] != 0 && grid[r][c] == grid[runStart][c]) {
          continue;
        }
        final len = r - runStart;
        if (grid[runStart][c] != 0 && len >= 3) {
          for (var k = runStart; k < r; k++) {
            s.add(Point(k, c));
          }
        }
        runStart = r;
      }
    }
    return s;
  }

  void _applyGravity() {
    for (var c = 0; c < cols; c++) {
      final remain = <int>[];
      for (var r = 0; r < rows; r++) {
        if (grid[r][c] != 0) remain.add(grid[r][c]);
      }
      var idx = remain.length - 1;
      for (var r = rows - 1; r >= 0; r--) {
        grid[r][c] = idx >= 0 ? remain[idx--] : _rng.nextInt(_palette.length);
      }
    }
  }

  void _resolveBoard() {
    var any = true;
    while (any) {
      any = false;
      final matches = _findMatches();
      if (matches.isEmpty) break;
      any = true;
      score += matches.length * 10;
      for (final p in matches) {
        grid[p.r][p.c] = 0;
      }
      _applyGravity();
    }
    scoreNotifier.value = score;
    _rebuildTiles();
  }

  void _rebuildTiles() {
    if (_comps.isNotEmpty) removeAll(_comps);
    _comps.clear();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final comp = RectangleComponent(
          position: _cellCenter(r, c),
          size: Vector2(_cell * 0.92, _cell * 0.92),
          anchor: Anchor.center,
          paint: Paint()..color = _palette[grid[r][c]],
        );
        _comps.add(comp);
        add(comp);
      }
    }
  }

  void _trySwap(int r1, int c1, int r2, int c2) {
    final tmp = grid[r1][c1];
    grid[r1][c1] = grid[r2][c2];
    grid[r2][c2] = tmp;
    if (_findMatches().isNotEmpty) {
      movesLeft--;
      movesNotifier.value = movesLeft;
      _resolveBoard();
      if (movesLeft <= 0) _finish();
    } else {
      // 无可消除，换回
      final back = grid[r1][c1];
      grid[r1][c1] = grid[r2][c2];
      grid[r2][c2] = back;
      _rebuildTiles();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    onFinished(GamePlayOutcome(
      cleared: true,
      values: <String, num>{
        'score': score,
        'duration_ms': elapsed,
      },
      durationMs: elapsed,
    ));
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_loaded || _finished) return;
    final c = (event.canvasPosition.x / _cell).floor();
    final r = (event.canvasPosition.y / _cell).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;

    if (_selectedR == null) {
      _selectedR = r;
      _selectedC = c;
      return;
    }
    final sr = _selectedR!;
    final sc = _selectedC!;
    _selectedR = null;
    _selectedC = null;
    if (sr == r && sc == c) return; // 取消选择
    final adjacent =
        (sr - r).abs() + (sc - c).abs() == 1; // 仅相邻可交换
    if (!adjacent) return;
    _trySwap(sr, sc, r, c);
  }
}

class Point {
  final int r;
  final int c;
  const Point(this.r, this.c);
}
