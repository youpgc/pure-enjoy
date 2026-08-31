import 'package:flutter/material.dart';

import 'game_play_helpers.dart';
import 'games/g2048/g2048_game.dart';
import 'games/match3/match3_game.dart';
import 'games/sheep/sheep_game.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'play/game_single_dashboard.dart';

/// 游戏承载页：按 game.code 分发对应游戏组件，统一处理结算与重玩。
class GamePlayScreen extends StatefulWidget {
  /// 要游玩的游戏
  final GameModel game;

  /// 指定关卡（选关界面传入）；为 null 时自动取第一个启用关卡。
  final GameLevelModel? level;

  const GamePlayScreen({super.key, required this.game, this.level});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  late final GameLevelModel _level;
  GamePlayOutcome? _outcome;
  int _restartNonce = 0;

  @override
  void initState() {
    super.initState();
    // 选关界面已指定关卡则直接用；否则回退到「第一个启用关卡」
    _level = widget.level ?? resolveLevel(widget.game);
  }

  void _onFinished(GamePlayOutcome outcome) async {
    if (_outcome != null) return; // 防重复结算
    setState(() => _outcome = outcome);
    // 注入关卡号维度（后台已配置则参与成绩/奖励判定）
    final values = <String, num>{...outcome.values, 'level': _level.levelNo};
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level,
      scoreValuesByCode: values,
      durationMs: outcome.durationMs,
      cleared: outcome.cleared,
    );
  }

  Widget _buildGame() {
    switch (widget.game.code) {
      case 'sheep':
        return SheepGame(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
        );
      case 'g2048':
        return G2048Game(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
        );
      case 'match3':
        return Match3Game(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
        );
      default:
        return const Center(child: Text('该游戏暂未实现'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 顺序通关 / 选关模式下，通关当前关后是否可推进到下一关
    final next = nextLevelOf(widget.game, _level);
    final canNext = _outcome?.cleared == true && next != null;

    return Scaffold(
      appBar: buildGameAppBar(
        context,
        widget.game,
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameSingleDashboard(game: widget.game),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          _buildGame(),
          if (_outcome != null)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _outcome!.cleared ? '🎉 通关！' : '本局结束',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (canNext)
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => setState(() {
                                      _outcome = null;
                                      _restartNonce++;
                                    }),
                                    child: const Text('再玩一次'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.of(context)
                                        .pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => GamePlayScreen(
                                          game: widget.game,
                                          level: next,
                                        ),
                                      ),
                                    ),
                                    child: const Text('下一关'),
                                  ),
                                ),
                              ],
                            )
                          else
                            FilledButton(
                              onPressed: () => setState(() {
                                _outcome = null;
                                _restartNonce++;
                              }),
                              child: const Text('再玩一次'),
                            ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('返回大厅'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
