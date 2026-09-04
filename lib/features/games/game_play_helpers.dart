import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'models/game_dimension_model.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'services/game_reward_service.dart';
import 'services/game_score_service.dart';
import 'services/game_service.dart';

/// 游戏结果（供游戏页回传结算）
class GamePlayOutcome {
  /// 是否通关
  final bool cleared;

  /// 成绩维度取值（维度编码 → 数值），如 {'score': 2048, 'duration_ms': 12345}
  final Map<String, num> values;

  /// 本次游玩耗时（毫秒）
  final int durationMs;

  const GamePlayOutcome({
    required this.cleared,
    required this.values,
    required this.durationMs,
  });
}

/// 游戏封面 SVG 资源路径（games.icon 存 SVG 文件名，如 'g2048'）。
/// 兼容旧 Material 名（grid_on/grid_4x4/casino）向后回落，避免改名前 DB 值空窗。
String gameCoverAsset(String? code) {
  const Map<String, String> legacy = <String, String>{
    'grid_on': 'sheep',
    'grid_4x4': 'g2048',
    'casino': 'match3',
  };
  const Set<String> known = <String>{'g2048', 'sheep', 'match3'};
  final String c = (code != null && code.isNotEmpty) ? code : 'g2048';
  final String name = known.contains(c) ? c : (legacy[c] ?? 'g2048');
  return 'assets/games/icons/$name.svg';
}

/// 模式图标 SVG 资源路径（game_modes.icon 存 SVG 文件名，如 'mode_classic'）。
String modeIconAsset(String? code) {
  final String c = (code != null && code.isNotEmpty) ? code : 'mode_classic';
  return 'assets/games/icons/$c.svg';
}

/// 解析当前要游玩的关卡：取后台第一个启用关卡；无配置则合成占位关卡
/// （levelId 为空，不计入每日首通，需后台配置关卡后才发放首通奖励）。
GameLevelModel resolveLevel(GameModel game) {
  final levels =
      GameService.instance.cachedConfig.levelsOf(game.id);
  if (levels.isNotEmpty) return levels.first;
  return GameLevelModel(
    id: '',
    gameId: game.id,
    levelNo: 1,
    name: '默认关卡',
    countForDailyClear: false,
  );
}

/// 取当前关卡的下一个启用关卡（按 sort_order 升序）；无后续则返回 null。
/// 顺序通关与结算页「下一关」按钮共用：通关当前关后推进到下一关。
///
/// [modeId] 非空时只在同模式内推进（模式网格 → 选关 → 对局 的闭环语义：
/// 「下一关」是同一模式的下一关，不会跨模式跳变）。
GameLevelModel? nextLevelOf(GameModel game, GameLevelModel current,
    {String? modeId}) {
  var levels = GameService.instance.cachedConfig.levelsOf(game.id);
  if (modeId != null && modeId.isNotEmpty) {
    final scoped = levels.where((l) => l.modeId == modeId).toList();
    if (scoped.isNotEmpty) levels = scoped;
  }
  for (int i = 0; i < levels.length; i++) {
    if (levels[i].id == current.id) {
      return i + 1 < levels.length ? levels[i + 1] : null;
    }
  }
  return null;
}

/// 构建游戏页 AppBar（含右上角「看板」入口）
AppBar buildGameAppBar(
  BuildContext context,
  GameModel game,
  VoidCallback onDashboard,
) {
  return AppBar(
    title: Text(game.name),
    actions: <Widget>[
      IconButton(
        icon: const Icon(Icons.bar_chart),
        tooltip: '成绩看板',
        onPressed: onDashboard,
      ),
    ],
  );
}

/// 上报成绩 + 结算奖励 + 弹结算页。返回结算结果（未登录/失败可能为 null）。
///
/// [aborted] 为 true 表示用户中途主动放弃：只上报 status='aborted' 的成绩，
/// 不结算奖励、不弹结算页（放弃不发分，防止刷分）。
///
/// **结算弹窗在游戏结束立即弹出**：成绩上报与奖励结算在弹窗内异步进行，
/// 加载完成前展示 loading 且弹窗不可关闭（禁其他操作），完成后渲染奖励明细。
Future<GameSettlementResult?> reportAndSettle({
  required BuildContext context,
  required GameModel game,
  required GameLevelModel level,
  required Map<String, num> scoreValuesByCode,
  required int durationMs,
  bool cleared = true,
  bool aborted = false,
  VoidCallback? onReplay,
  VoidCallback? onNext,
  bool canNext = false,
  VoidCallback? onExit,
}) async {
  // 维度编码 → 维度 id（成绩表按维度 id 存值）
  final dims = GameService.instance.cachedConfig.dimensionsOf(game.id);
  final valuesById = <String, num>{};
  for (final entry in scoreValuesByCode.entries) {
    GameDimensionModel? dim;
    for (final d in dims) {
      if (d.code == entry.key) {
        dim = d;
        break;
      }
    }
    if (dim != null) valuesById[dim.id] = entry.value;
  }

  // 放弃：只上报成绩，不结算不弹窗（放弃不发分，防止刷分）
  if (aborted) {
    await GameScoreService.instance.submitScore(
      gameId: game.id,
      levelId: level.id.isEmpty ? null : level.id,
      modeId: level.modeId.isEmpty ? null : level.modeId,
      cleared: cleared,
      statusOverride: 'aborted',
      durationMs: durationMs,
      values: valuesById,
    );
    return null;
  }

  // 游戏结束立即弹出结算页；成绩上报 + 奖励结算在弹窗内异步进行，
  // 加载完成前展示 loading，期间弹窗不可点遮罩关闭/拖拽（禁其他操作）。
  final completer = Completer<GameSettlementResult?>();
  final settleFuture = () async {
    // 上报成绩（best-effort，失败仅记日志）
    await GameScoreService.instance.submitScore(
      gameId: game.id,
      levelId: level.id.isEmpty ? null : level.id,
      modeId: level.modeId.isEmpty ? null : level.modeId,
      cleared: cleared,
      durationMs: durationMs,
      values: valuesById,
    );
    // 结算奖励
    return GameRewardService.instance.settleGame(
      game: game,
      level: level,
      scoreValuesByCode: scoreValuesByCode,
      cleared: cleared,
    );
  }();

  if (context.mounted) {
    unawaited(showModalBottomSheet<GameSettlementResult?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SettlementSheet(
        game: game,
        cleared: cleared,
        scoreValuesByCode: scoreValuesByCode,
        settleFuture: settleFuture,
        onDismiss: (r) {
          if (!completer.isCompleted) completer.complete(r);
        },
        onReplay: onReplay,
        onNext: onNext,
        canNext: canNext,
        onExit: onExit,
      ),
    ));
  } else {
    // 上下文已失效（如页面被回收），仍尝试结算以发放奖励，但不再弹窗
    await settleFuture;
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

/// 结算页（底部弹窗）：先展示 loading，待结算接口返回后渲染成绩与奖励明细。
///
/// 弹窗不可点遮罩关闭、不可拖拽；加载期间无任何可点击操作 → 禁其他操作。
/// 结算（成绩上报 + 奖励发放）由 [settleFuture] 在弹窗内异步驱动。
class _SettlementSheet extends StatefulWidget {
  final GameModel game;
  final bool cleared;
  final Map<String, num> scoreValuesByCode;
  final Future<GameSettlementResult> settleFuture;
  final VoidCallback? onReplay;
  final VoidCallback? onNext;
  final bool canNext;
  final VoidCallback? onExit;
  final void Function(GameSettlementResult? result) onDismiss;

  const _SettlementSheet({
    required this.game,
    required this.cleared,
    required this.scoreValuesByCode,
    required this.settleFuture,
    this.onReplay,
    this.onNext,
    this.canNext = false,
    this.onExit,
    required this.onDismiss,
  });

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  bool _loading = true;
  GameSettlementResult? _result;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    widget.settleFuture.then((r) {
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      debugPrint('[SettlementSheet] 结算失败：$e');
      setState(() {
        _errored = true;
        _loading = false;
      });
    });
  }

  void _dismiss() {
    widget.onDismiss(_result);
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtDim(List<GameDimensionModel> dims, String code, num value) {
    if (code == 'duration_ms') {
      final sec = (value / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final dim = dims.where((d) => d.code == code).firstOrNull;
    return '${value.toInt()}${dim?.unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('结算中…', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final result = _result;
    final dims = GameService.instance.cachedConfig.dimensionsOf(widget.game.id);

    // 结算失败：成绩已记录但奖励发放异常，允许退出/重试
    if (_errored || result == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                Text('结算失败', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            const Text('本次成绩已记录，但奖励结算异常，可稍后重试或返回大厅。',
                style: TextStyle(fontSize: 14)),
            const Divider(height: 24),
            if (widget.onReplay != null)
              FilledButton(
                onPressed: () {
                  _dismiss();
                  widget.onReplay!();
                },
                child: const Text('再玩一次'),
              ),
            if (widget.onExit != null)
              TextButton(
                onPressed: () {
                  _dismiss();
                  widget.onExit!();
                },
                child: const Text('返回大厅'),
              ),
          ],
        ),
      );
    }

    // 单日游戏奖励是否已达上限（命中上限的奖励项 reason 含「上限」）
    final hitCap = result.items.any(
      (i) => i.reason != null && i.reason!.contains('上限'),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                !widget.cleared
                    ? Icons.cancel
                    : (result.hasGranted ? Icons.emoji_events : Icons.check_circle),
                color: !widget.cleared
                    ? AppTheme.error
                    : AppTheme.success,
              ),
              const SizedBox(width: 8),
              Text(
                !widget.cleared
                    ? '挑战失败'
                    : (result.hasGranted ? '通关结算' : '通关'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          if (!widget.cleared)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '未达成通关条件，本次无奖励',
                style: TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          Text('本次成绩', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.scoreValuesByCode.entries
                .map((e) => Chip(
                      label: Text(
                          '${_dimName(dims, e.key)}  ${_fmtDim(dims, e.key, e.value)}'),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('奖励明细', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          // 仅展示「实际获得的明细」；通关奖励不论是否获得都展示（kind=level_clear），
          // 其余未获得的（已领取 / 不相关）不展示，避免结算页堆砌无效行。
          ...(() {
            final shown = result.items
                .where((i) => i.granted || i.kind == 'level_clear')
                .toList();
            if (shown.isEmpty) {
              return const <Widget>[
                Text('本次无奖励获得',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.neutral500)),
              ];
            }
            return shown
                .map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.granted ? Icons.check : Icons.close,
                        color: item.granted
                            ? AppTheme.success
                            : AppTheme.neutral500,
                        size: 18,
                      ),
                      title: Text(item.label),
                      subtitle: item.granted ? null : Text(item.reason ?? ''),
                      trailing: Text(
                        item.granted ? '+${item.points}' : '0',
                        style: TextStyle(
                          color: item.granted
                              ? AppTheme.success
                              : AppTheme.neutral500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                .toList();
          })(),
          if (hitCap) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '今日游戏奖励已达上限，本次积分暂未发放；明日上限刷新后，重新通关即可获得',
                      style: TextStyle(color: AppTheme.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('本局获得积分', style: TextStyle(fontSize: 16)),
              Text(
                '+${result.totalPoints}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              if (widget.onReplay != null)
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _dismiss();
                      widget.onReplay!();
                    },
                    child: const Text('再玩一次'),
                  ),
                ),
              if (widget.canNext && widget.onNext != null) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _dismiss();
                      widget.onNext!();
                    },
                    child: const Text('下一关'),
                  ),
                ),
              ],
            ],
          ),
          if (widget.onExit != null)
            TextButton(
              onPressed: () {
                _dismiss();
                widget.onExit!();
              },
              child: const Text('返回大厅'),
            ),
        ],
      ),
    );
  }
}

String _dimName(List<GameDimensionModel> dims, String code) {
  for (final d in dims) {
    if (d.code == code) return d.name;
  }
  return code;
}

/// 格式化维度值（用时转 mm:ss）
String formatDimensionValue(GameDimensionModel dim, num value) {
  if (dim.isDuration) {
    final sec = (value / 1000).floor();
    return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }
  return '${value.toInt()}${dim.unit ?? ''}';
}
