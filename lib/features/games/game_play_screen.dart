import 'package:flutter/material.dart';

import 'flow/game_flow_runner.dart';
import 'flow/game_registry.dart';
import 'game_play_helpers.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'play/game_best_screen.dart';
import 'play/game_history_screen.dart';

/// 主动放弃计入游戏记录的最短时长下限：低于此值（如误触返回）不落 game_scores、
/// 不结算发分，避免拉低正常通关率等统计数据。
const int _minRecordDurationMs = 10000; // 10s

/// 游戏承载页：流程体系（GameFlow）统一承载选关/结算/降级，
/// 引擎视图由 [GameFlowRegistry] 按游戏适配器构建——本页不再按 game.code 分叉。
class GamePlayScreen extends StatefulWidget {
  /// 要游玩的游戏
  final GameModel game;

  /// 指定关卡（选关/模式入口传入）；为 null 时由流程体系解析默认关
  /// （frontier 或内置经典模式合成关，见 GameFlowRunner.resolvePlayPlan）。
  final GameLevelModel? level;

  const GamePlayScreen({super.key, required this.game, this.level});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  GameLevelModel? _level;

  /// 结算门禁（开局时解析）：false = 默认流程，只记成绩不发分不发成就。
  bool _rewardsAllowed = true;

  late final DateTime _enterTime;
  GamePlayOutcome? _outcome;
  int _restartNonce = 0;

  @override
  void initState() {
    super.initState();
    _enterTime = DateTime.now();
    final plan = GameFlowRunner.instance.resolvePlayPlan(
      widget.game,
      explicit: widget.level,
    );
    _level = plan.level;
    _rewardsAllowed = plan.rewardsAllowed;
  }

  /// 返回键拦截：对局进行中弹「放弃本局」确认；确认后上报 status=aborted
  /// （只记成绩不结算发分），再退出。结算页已弹出（_outcome != null）时直接放行。
  Future<void> _onPopInvokedWithResult(bool didPop, Object? result) async {
    if (didPop) return;
    if (_level == null) {
      // 尚未完成开局解析（理论上不会发生：解析为同步兜底）直接放行返回
      Navigator.of(context).pop();
      return;
    }
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
    final durationMs = DateTime.now().difference(_enterTime).inMilliseconds;
    // 极短时长（<10s）的主动放弃视为误触/异常退出，不计入游戏记录
    // （不写 game_scores、不结算发分），避免拉低正常通关率等统计。
    if (durationMs < _minRecordDurationMs) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level!,
      scoreValuesByCode: <String, num>{'level': _level!.levelNo},
      durationMs: durationMs,
      cleared: false,
      aborted: true,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _onFinished(GamePlayOutcome outcome) async {
    if (_outcome != null) return; // 防重复结算
    setState(() => _outcome = outcome);
    // 注入关卡号维度（后台已配置则参与成绩/奖励判定）
    final values = <String, num>{...outcome.values, 'level': _level!.levelNo};
    // 结算弹窗内的「下一关 / 再玩一次 / 返回大厅」统一由结算页承载，
    // 不再另弹居中卡片，避免与结算页重复。
    final next = nextLevelOf(widget.game, _level!, modeId: _level!.modeId);
    final canNext = outcome.cleared && next != null;
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level!,
      scoreValuesByCode: values,
      durationMs: outcome.durationMs,
      cleared: outcome.cleared,
      rewardsAllowed: _rewardsAllowed,
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
    final adapter = GameFlowRegistry.adapterOf(widget.game.code);
    if (adapter == null) {
      return const Center(child: Text('该游戏暂未实现'));
    }
    // 引擎 Key 随重玩 nonce 变化、随普通 setState 稳定（重建语义由本页控制）
    return adapter.buildEngine(
      key: ValueKey<int>(_restartNonce),
      game: widget.game,
      level: _level!,
      onFinished: _onFinished,
      onRestart: () => setState(() {
        _outcome = null;
        _restartNonce++;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        // 游戏记录与最佳记录拆分为两个独立入口（原成绩看板聚合页已拆分）
        appBar: AppBar(
          title: Text(widget.game.name),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: '最佳记录',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameBestScreen(game: widget.game),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: '游戏记录',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameHistoryScreen(game: widget.game),
                ),
              ),
            ),
          ],
        ),
        // 开局解析（resolvePlayPlan）为同步兜底，_level 恒非空——无 loading 态
        body: _buildGame(),
      ),
    );
  }
}
