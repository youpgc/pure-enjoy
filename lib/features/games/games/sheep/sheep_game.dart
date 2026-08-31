import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';

/// 羊了个羊（简化版，纯 Widget 实现）
///
/// 玩法：点击棋盘上的方块放入底部 7 个槽位；槽位中凑齐 3 个相同即消除。
/// 清空棋盘 = 通关；槽位满 7 个且无法消除 = 失败。
/// 注：原版「分层遮挡」机制本版未实现（v1 聚焦核心消除循环），可作为后续增强。
class SheepGame extends StatefulWidget {
  /// 结束回调（通关/失败均触发一次）
  final void Function(GamePlayOutcome) onFinished;

  const SheepGame({super.key, required this.onFinished});

  @override
  State<SheepGame> createState() => _SheepGameState();
}

class _SheepGameState extends State<SheepGame> {
  static const List<String> _tiles = <String>[
    '🍎', '🍊', '🍇', '🍉', '🥝', '🍓', '🍌', '🍑'
  ];
  static const int _slotCapacity = 7;

  late List<String> _board;
  late List<String> _slots;
  late final DateTime _startTime;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initLevel();
  }

  void _initLevel() {
    // 每类 3 张（保证可完全消除），共 24 张
    final list = <String>[];
    for (final t in _tiles) {
      list.add(t);
      list.add(t);
      list.add(t);
    }
    list.shuffle();
    _board = list;
    _slots = <String>[];
  }

  void _clearTriples() {
    var changed = true;
    while (changed) {
      changed = false;
      for (final t in <String>{..._slots}) {
        if (_slots.where((s) => s == t).length >= 3) {
          var removed = 0;
          _slots.removeWhere((s) {
            if (s == t && removed < 3) {
              removed++;
              return true;
            }
            return false;
          });
          changed = true;
          break;
        }
      }
    }
  }

  void _tapTile(int index) {
    if (_finished) return;
    setState(() {
      final t = _board.removeAt(index);
      _slots.add(t);
      _clearTriples();

      final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
      if (_board.isEmpty && _slots.isEmpty) {
        _finish(true, elapsed);
      } else if (_slots.length > _slotCapacity) {
        _finish(false, elapsed);
      }
    });
  }

  void _finish(bool cleared, int elapsed) {
    _finished = true;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{'duration_ms': elapsed},
      durationMs: elapsed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              itemCount: _board.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (ctx, i) => InkWell(
                onTap: () => _tapTile(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.warmWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.neutral300),
                  ),
                  alignment: Alignment.center,
                  child: Text(_board[i], style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: AppTheme.neutral300)),
          ),
          child: Row(
            children: <Widget>[
              const Text('槽位', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              ...List<Widget>.generate(_slotCapacity, (i) {
                final has = i < _slots.length;
                return Expanded(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: has ? AppTheme.warmWhite : AppTheme.neutral200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.neutral300),
                    ),
                    alignment: Alignment.center,
                    child: has
                        ? Text(_slots[i], style: const TextStyle(fontSize: 20))
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
