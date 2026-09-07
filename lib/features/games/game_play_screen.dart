import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

import 'flow/game_flow_runner.dart';
import 'flow/game_registry.dart';
import 'game_play_helpers.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'services/game_service.dart';

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

  /// 无尽模式链式会话：局间不结算，多局成绩累加，用户选择「结束」时
  /// 以累计总分一次性上报并结算（参考用户 2026-09-07 拍板）。
  bool get _isEndless => _level?.id.startsWith('endless_2048') ?? false;
  int _endlessTotal = 0; // 已完成局的累计得分
  int _endlessRounds = 0; // 已完成局数

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
    // 无尽模式合成关不注入 level 维度（合成关号 10000+size 是内部隔离值，
    // 非真实关卡，展示/统计都会失真）
    final abandonValues = _isEndless
        ? <String, num>{}
        : <String, num>{'level': _level!.levelNo};
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level!,
      scoreValuesByCode: abandonValues,
      durationMs: durationMs,
      cleared: false,
      aborted: true,
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// 无尽模式局间结算：展示本局成绩与累计，由用户选择「继续下一局」
  /// （重开新局、成绩滚入累计）或「结束并结算」（以累计总分一次性上报结算）。
  Future<void> _showEndlessIntermission(GamePlayOutcome outcome) async {
    final roundScore = (outcome.values['score'] ?? 0).toInt();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => PopScope(
        canPop: false, // 局间必须二选一，不允许点遮罩/返回关闭
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.check_circle, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Text('第 ${_endlessRounds + 1} 局结束',
                      style: Theme.of(ctx).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text('本局得分  $roundScore')),
                  Chip(label: Text('累计得分  ${_endlessTotal + roundScore}')),
                  Chip(label: Text('已玩  ${_endlessRounds + 1} 局')),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop('continue'),
                      child: const Text('继续下一局'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop('finish'),
                      child: const Text('结束并结算'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'continue') {
      setState(() {
        _endlessTotal += roundScore;
        _endlessRounds += 1;
        _outcome = null; // 解锁结算门禁，重开下一局
        _restartNonce++;
      });
      return;
    }
    // 结束并结算：以累计总分一次性上报（多局成绩累加总结算）
    await _finishEndlessSession(roundScore);
  }

  /// 无尽会话终局：score = 各局累加总分；duration = 本次会话总时长；
  /// 不注入 level 维度（合成关号非真实关卡）；cleared=true（正常结束）。
  Future<void> _finishEndlessSession(int lastRoundScore) async {
    final totalScore = _endlessTotal + lastRoundScore;
    final totalDurationMs = DateTime.now().difference(_enterTime).inMilliseconds;
    await reportAndSettle(
      context: context,
      game: widget.game,
      level: _level!,
      scoreValuesByCode: <String, num>{
        'score': totalScore,
        'duration_ms': totalDurationMs,
      },
      durationMs: totalDurationMs,
      cleared: true,
      rewardsAllowed: _rewardsAllowed,
      endless: true,
      onExit: () => Navigator.of(context).pop(),
    );
  }

  void _onFinished(GamePlayOutcome outcome) async {
    if (_outcome != null) return; // 防重复结算
    setState(() => _outcome = outcome);
    // 无尽模式：局间不结算——弹「继续下一局 / 结束并结算」选择，
    // 多局成绩累加，结束时以总分一次性上报（不发本局 N 次奖励）。
    if (_isEndless) {
      await _showEndlessIntermission(outcome);
      return;
    }
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

  /// 对局页标题：游戏名 + 模式名 + 第 N 关（合成关显示「无尽」；无模式段省略）
  String get _titleText {
    final g = widget.game;
    final level = _level;
    if (level == null) return g.name;
    final parts = <String>[g.name];
    if (level.id.startsWith('endless_2048')) {
      parts.add('无尽');
    } else if (level.modeId.isNotEmpty) {
      String? modeName;
      for (final m in GameService.instance.cachedConfig.modesOf(g.id)) {
        if (m.id == level.modeId) {
          modeName = m.name;
          break;
        }
      }
      if (modeName != null) parts.add(modeName);
    }
    if (level.levelNo > 0 && level.levelNo < 10000) parts.add('第${level.levelNo}关');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        // 标题：游戏名+模式+第N关（不展示额外信息，避免溢出）；
        // 右上角不放任何入口（记录/最佳记录入口只保留在游戏主界面，2026-09-07 拍板）
        appBar: AppBar(title: Text(_titleText)),
        // 开局解析（resolvePlayPlan）为同步兜底，_level 恒非空——无 loading 态
        body: _buildGame(),
      ),
    );
  }
}
