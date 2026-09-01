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
  late final DateTime _enterTime;
  GamePlayOutcome? _outcome;
  int _restartNonce = 0;

  @override
  void initState() {
    super.initState();
    // 选关界面已指定关卡则直接用；否则回退到「第一个启用关卡」
    _level = widget.level ?? resolveLevel(widget.game);
    _enterTime = DateTime.now();
  }

  /// 返回键拦截：对局进行中弹「放弃本局」确认；确认后上报 status=aborted
  /// （只记成绩不结算发分），再退出。结算页已弹出（_outcome != null）时直接放行。
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    if (_outcome != null) {
      Navigator.of(context).pop();
      return;
    }
    final abandon = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃本局？'),
        content: const Text('退出将记为一次「放弃」，本局不获得积分奖励'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续游戏'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃退出'),
          ),
        ],
      ),
    );
    if (abandon != true || !mounted) return;
    // 弹窗停留期间对局可能已自然结束（如限时模式倒计时归零触发 _onFinished），
    // 此时结算已由 _onFinished 接管，不能再补一条 aborted 成绩造成双路结算。
    if (_outcome != null) {
      Navigator.of(context).pop();
      return;
    }
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level,
      scoreValuesByCode: <String, num>{'level': _level.levelNo},
      durationMs: DateTime.now().difference(_enterTime).inMilliseconds,
      cleared: false,
      aborted: true,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _onFinished(GamePlayOutcome outcome) async {
    if (_outcome != null) return; // 防重复结算
    setState(() => _outcome = outcome);
    // 注入关卡号维度（后台已配置则参与成绩/奖励判定）
    final values = <String, num>{...outcome.values, 'level': _level.levelNo};
    // 结算弹窗内的「下一关 / 再玩一次 / 返回大厅」统一由结算页承载，
    // 不再另弹居中卡片，避免与结算页重复。
    final next = nextLevelOf(widget.game, _level);
    final canNext = outcome.cleared && next != null;
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level,
      scoreValuesByCode: values,
      durationMs: outcome.durationMs,
      cleared: outcome.cleared,
      onReplay: () => setState(() {
        _outcome = null;
        _restartNonce++;
      }),
      onNext: canNext
          ? () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GamePlayScreen(game: widget.game, level: next),
                ),
              )
          : null,
      canNext: canNext,
      onExit: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildGame() {
    switch (widget.game.code) {
      case 'sheep':
        return SheepGame(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
          level: _level,
        );
      case 'g2048':
        return G2048Game(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
          level: _level,
        );
      case 'match3':
        return Match3Game(
          key: ValueKey(_restartNonce),
          onFinished: _onFinished,
          level: _level,
          onRestart: () => setState(() {
            _outcome = null;
            _restartNonce++;
          }),
        );
      default:
        return const Center(child: Text('该游戏暂未实现'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        appBar: buildGameAppBar(
          context,
          widget.game,
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameSingleDashboard(game: widget.game),
            ),
          ),
        ),
        body: _buildGame(),
      ),
    );
  }
}
