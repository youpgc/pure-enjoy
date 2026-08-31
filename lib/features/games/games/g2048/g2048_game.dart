import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_shell.dart';
import '../../models/game_level_model.dart';
import 'g2048_tile.dart';

/// 2048（成熟手感版）
///
/// 操作方式：**在棋盘上朝上/下/左/右拖动（滑动）**，同方向所有数字整体推移，
/// 相邻且数字相同的两块合并成一块（2+2=4）。本游戏**没有点击操作**。
///
/// - 滑动判定用「拖动总位移」而非抬手瞬时速度，慢速拖动同样生效（v2 修复）。
/// - 方块用 [G2048Tile] 做丝滑滑动 + 出现/合并弹跳。
/// - 触感 + 音效：每次移动轻触感 + 点击音；合并中触感 + 合并音。
/// - 最高分本地持久化（shared_preferences）。
/// - 到达 2048 记「通关」；无可移动空间记「失败」。成绩维度：score + duration_ms。
class G2048Game extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 当前关卡（含 size / target 配置）
  final GameLevelModel level;

  G2048Game({super.key, required this.onFinished, required this.level});

  @override
  State<G2048Game> createState() => _G2048GameState();
}

class _G2048GameState extends State<G2048Game> {
  late int _size;
  late int _target;
  static const Duration _slide = Duration(milliseconds: 120);

  /// 判定为「一次滑动」的最小拖动距离（逻辑像素）。
  /// 取 24：既能过滤误触抖动，又让短距离轻扫可用。
  static const double _swipeThreshold = 24.0;

  /// 本次拖动的累计位移（onPanStart 归零，onPanUpdate 累加，onPanEnd 判方向）
  Offset _dragDelta = Offset.zero;

  /// 本次拖动是否已经触发过移动（防止一次长拖连续触发多次）
  bool _dragConsumed = false;

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

  /// 最高分持久化 key（按关卡号区分，避免不同关卡共用同一最高分）
  String get _bestKey => 'g2048_best_${widget.level.levelNo}';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // 从后台关卡配置读取棋盘尺寸与目标分（含安全边界，异常值回退默认）
    final cfgSize = widget.level.config['size'];
    final cfgTarget = widget.level.config['target'];
    final parsedSize = cfgSize is int
        ? cfgSize
        : (cfgSize is num ? cfgSize.toInt() : 4);
    _size = (parsedSize >= 3 && parsedSize <= 8) ? parsedSize : 4;
    final parsedTarget = cfgTarget is int
        ? cfgTarget
        : (cfgTarget is num ? cfgTarget.toInt() : 2048);
    _target = parsedTarget > 0 ? parsedTarget : 2048;
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    _loadBest();
    _reset();
  }

  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      _best = sp.getInt(_bestKey) ?? 0;
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

  /// 按累计位移判定滑动方向。
  /// 原实现只看抬手瞬时速度（velocity），慢速拖动抬手时速度≈0 → 永远不触发，
  /// 表现为「点击不行、滑动也不行」。改为总位移判定后任意速度均可操作。
  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragConsumed) return;
    _dragDelta += d.delta;
    // 拖动过程中一旦越过阈值立即响应，手感更即时（不必等抬手）
    if (_dragDelta.distance >= _swipeThreshold) {
      _dragConsumed = true;
      _applySwipe(_dragDelta);
    }
  }

  void _applySwipe(Offset delta) {
    if (delta.dx.abs() > delta.dy.abs()) {
      _move(delta.dx > 0 ? 'right' : 'left');
    } else {
      _move(delta.dy > 0 ? 'down' : 'up');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      statusItems: <Widget>[
        GameStatusItem(label: '得分', value: '$_score'),
        GameStatusItem(label: '最高分', value: '$_best'),
        GameStatusItem(label: '目标', value: '$_target'),
      ],
      hint: '在棋盘上朝上下左右拖动，相同数字相撞即合并（无需点击）',
      actions: <GameAction>[
        GameAction(
          icon: Icons.refresh,
          label: '新游戏',
          primary: true,
          onPressed: _finished ? null : () => setState(_reset),
        ),
      ],
      content: LayoutBuilder(
        builder: (ctx, constraints) {
          // 棋盘取正方形，居中显示，避免长屏被拉伸
          final board = min(constraints.maxWidth, constraints.maxHeight);
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

          return Center(
            child: GestureDetector(
              // opaque：棋盘空白处同样接收拖动，避免只有方块上能滑
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                _dragDelta = Offset.zero;
                _dragConsumed = false;
              },
              onPanUpdate: _onDragUpdate,
              onPanEnd: (_) {
                // 兜底：整段拖动都很短但已越过阈值时在抬手时判定
                if (!_dragConsumed && _dragDelta.distance >= _swipeThreshold) {
                  _applySwipe(_dragDelta);
                }
                _dragDelta = Offset.zero;
                _dragConsumed = false;
              },
              child: Container(
                width: board,
                height: board,
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(gap * 2),
                ),
                child: Stack(children: children),
              ),
            ),
          );
        },
      ),
    );
  }
}
