import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import 'match3_flame_game.dart';

/// 消消乐 Flutter 承载组件：嵌入 Flame 游戏 + 分数/步数/目标叠加层。
class Match3Game extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 关卡（读取 config 的 goal/steps 决定目标与步数；为 null 用默认）
  final GameLevelModel? level;

  const Match3Game({super.key, required this.onFinished, this.level});

  @override
  State<Match3Game> createState() => _Match3GameState();
}

class _Match3GameState extends State<Match3Game> {
  late final ValueNotifier<int> _score;
  late final ValueNotifier<int> _moves;
  late final ValueNotifier<int> _goal;
  late final Match3FlameGame _game;

  @override
  void initState() {
    super.initState();
    final cfg = widget.level?.config ?? const <String, dynamic>{};
    final steps = (cfg['steps'] as int?) ?? 20;
    final goal = (cfg['goal'] as int?) ?? 1000;
    _score = ValueNotifier<int>(0);
    _moves = ValueNotifier<int>(steps);
    _goal = ValueNotifier<int>(goal);
    _game = Match3FlameGame(
      onFinished: widget.onFinished,
      scoreNotifier: _score,
      movesNotifier: _moves,
      steps: steps,
      goal: goal,
    );
  }

  @override
  void dispose() {
    _score.dispose();
    _moves.dispose();
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GameWidget(game: _game),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ValueListenableBuilder<int>(
                valueListenable: _score,
                builder: (_, v, __) => Chip(label: Text('得分 $v')),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _goal,
                builder: (_, v, __) => Chip(label: Text('目标 $v')),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _moves,
                builder: (_, v, __) =>
                    Chip(label: Text('剩余步数 $v')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
