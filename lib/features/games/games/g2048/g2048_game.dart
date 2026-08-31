import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';

/// 2048（纯 Widget 实现）
///
/// 玩法：上下左右滑动合并相同数字，冲击 2048。到达 2048 记为「通关」，
/// 棋盘填满且无合并空间记为「失败」。成绩维度：score（累计得分）+ duration_ms。
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

  late List<List<int>> _grid;
  late int _score;
  late bool _reachedTarget;
  late final DateTime _startTime;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _reset();
  }

  void _reset() {
    _grid = List.generate(_size, (_) => List.filled(_size, 0));
    _score = 0;
    _reachedTarget = false;
    _spawn();
    _spawn();
  }

  void _spawn() {
    final empties = <Point>[];
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == 0) empties.add(Point(r, c));
      }
    }
    if (empties.isEmpty) return;
    final p = empties[DateTime.now().microsecondsSinceEpoch % empties.length];
    _grid[p.r][p.c] = (DateTime.now().microsecondsSinceEpoch % 10 == 0) ? 4 : 2;
  }

  List<int> _mergeLine(List<int> line) {
    final nums = line.where((n) => n != 0).toList();
    final res = <int>[];
    var i = 0;
    while (i < nums.length) {
      if (i + 1 < nums.length && nums[i] == nums[i + 1]) {
        final v = nums[i] * 2;
        res.add(v);
        _score += v;
        if (v >= _target) _reachedTarget = true;
        i += 2;
      } else {
        res.add(nums[i]);
        i++;
      }
    }
    while (res.length < _size) {
      res.add(0);
    }
    return res;
  }

  void _move(String dir) {
    if (_finished) return;
    var changed = false;
    if (dir == 'left' || dir == 'right') {
      for (var r = 0; r < _size; r++) {
        var row = <int>[_grid[r][0], _grid[r][1], _grid[r][2], _grid[r][3]];
        if (dir == 'right') row = row.reversed.toList();
        final merged = _mergeLine(row);
        final out = dir == 'right' ? merged.reversed.toList() : merged;
        for (var c = 0; c < _size; c++) {
          if (_grid[r][c] != out[c]) changed = true;
          _grid[r][c] = out[c];
        }
      }
    } else {
      for (var c = 0; c < _size; c++) {
        var col = <int>[_grid[0][c], _grid[1][c], _grid[2][c], _grid[3][c]];
        if (dir == 'down') col = col.reversed.toList();
        final merged = _mergeLine(col);
        final out = dir == 'down' ? merged.reversed.toList() : merged;
        for (var r = 0; r < _size; r++) {
          if (_grid[r][c] != out[r]) changed = true;
          _grid[r][c] = out[r];
        }
      }
    }
    if (!changed) return;
    _spawn();

    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    if (_reachedTarget) {
      _finish(true, elapsed);
    } else if (!_hasMoves()) {
      _finish(false, elapsed);
    }
  }

  bool _hasMoves() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == 0) return true;
        if (c + 1 < _size && _grid[r][c] == _grid[r][c + 1]) return true;
        if (r + 1 < _size && _grid[r][c] == _grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  void _finish(bool cleared, int elapsed) {
    _finished = true;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{
        'score': _score,
        'duration_ms': elapsed,
      },
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
        } else {
          _move(v.dy > 0 ? 'down' : 'up');
        }
        if (mounted) setState(() {});
      },
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text('2048', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Chip(label: Text('得分 $_score')),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _size * _size,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _size,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (ctx, idx) {
                  final r = idx ~/ _size;
                  final c = idx % _size;
                  final v = _grid[r][c];
                  return Container(
                    decoration: BoxDecoration(
                      color: _tileColor(v),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: v == 0
                        ? null
                        : Text('$v',
                            style: TextStyle(
                              fontSize: v >= 1000 ? 20 : 26,
                              fontWeight: FontWeight.bold,
                              color: v <= 4 ? AppTheme.neutral800 : Colors.white,
                            )),
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('滑动合并相同数字，凑出 2048'),
          ),
        ],
      ),
    );
  }

  Color _tileColor(int v) {
    switch (v) {
      case 2:
        return AppTheme.neutral200;
      case 4:
        return AppTheme.neutral300;
      case 8:
        return AppTheme.secondaryColor;
      case 16:
        return AppTheme.primaryLight;
      case 32:
        return AppTheme.primaryYellow;
      case 64:
        return AppTheme.warning;
      case 128:
        return AppTheme.primaryOrange;
      case 256:
        return AppTheme.accentColor;
      case 512:
        return AppTheme.info;
      default:
        return v >= 1024 ? AppTheme.success : AppTheme.neutral100;
    }
  }
}

class Point {
  final int r;
  final int c;
  const Point(this.r, this.c);
}
