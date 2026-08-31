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

/// 游戏图标映射（games.icon 存 material icon 名）
IconData gameIcon(String? code) {
  switch (code) {
    case 'grid_on':
      return Icons.grid_on;
    case 'grid_4x4':
      return Icons.grid_4x4;
    case 'casino':
      return Icons.casino;
    case 'extension':
      return Icons.extension;
    case 'sports_esports':
      return Icons.sports_esports;
    default:
      return Icons.games;
  }
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
GameLevelModel? nextLevelOf(GameModel game, GameLevelModel current) {
  final levels = GameService.instance.cachedConfig.levelsOf(game.id);
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

  // 上报成绩（best-effort，失败仅记日志）。放弃时状态记 aborted。
  await GameScoreService.instance.submitScore(
    gameId: game.id,
    levelId: level.id.isEmpty ? null : level.id,
    cleared: cleared,
    statusOverride: aborted ? 'aborted' : null,
    durationMs: durationMs,
    values: valuesById,
  );

  // 放弃：只上报，不结算不弹窗
  if (aborted) return null;

  // 结算奖励
    final result = await GameRewardService.instance.settleGame(
      game: game,
      level: level,
      scoreValuesByCode: scoreValuesByCode,
      cleared: cleared,
    );

  if (context.mounted) {
    showSettlementSheet(
      context,
      game,
      result,
      scoreValuesByCode,
      onReplay: onReplay,
      onNext: onNext,
      canNext: canNext,
      onExit: onExit,
    );
  }
  return result;
}

/// 弹出结算页（本次成绩 + 奖励明细 + 单日上限提醒 + 再玩/下一关/返回大厅）。
///
/// 统一为单个底部弹窗：成绩、奖励与「再玩一次」入口合并展示，解决旧实现中
/// 游戏页自带居中弹窗与结算页重复出现的问题。弹窗不可点遮罩关闭，必须选择
/// 一个操作退出，避免结算后停留在无操作的「死页」。
void showSettlementSheet(
  BuildContext context,
  GameModel game,
  GameSettlementResult result,
  Map<String, num> scoreValuesByCode, {
  VoidCallback? onReplay,
  VoidCallback? onNext,
  bool canNext = false,
  VoidCallback? onExit,
}) {
  final dims = GameService.instance.cachedConfig.dimensionsOf(game.id);
  String fmtDim(String code, num value) {
    if (code == 'duration_ms') {
      final sec = (value / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final dim = dims.where((d) => d.code == code).firstOrNull;
    return '${value.toInt()}${dim?.unit ?? ''}';
  }

  // 单日游戏奖励是否已达上限（命中上限的奖励项 reason 含「上限」）
  final hitCap = result.items.any(
    (i) => i.reason != null && i.reason!.contains('上限'),
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                result.hasGranted ? Icons.emoji_events : Icons.check_circle,
                color: result.hasGranted
                    ? AppTheme.success
                    : AppTheme.neutral500,
              ),
              const SizedBox(width: 8),
              Text(
                result.hasGranted ? '通关结算' : '本局结束',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('本次成绩', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: scoreValuesByCode.entries
                .map((e) => Chip(
                      label: Text('${_dimName(dims, e.key)}  ${fmtDim(e.key, e.value)}'),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('奖励明细', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...result.items.map((item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.granted ? Icons.check : Icons.close,
                  color: item.granted ? AppTheme.success : AppTheme.neutral500,
                  size: 18,
                ),
                title: Text(item.label),
                subtitle: item.granted ? null : Text(item.reason ?? ''),
                trailing: Text(
                  item.granted ? '+${item.points}' : '0',
                  style: TextStyle(
                    color: item.granted ? AppTheme.success : AppTheme.neutral500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
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
                      '今日游戏奖励已达上限，后续通关不再获得积分',
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
              if (onReplay != null)
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onReplay();
                    },
                    child: const Text('再玩一次'),
                  ),
                ),
              if (canNext && onNext != null) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onNext();
                    },
                    child: const Text('下一关'),
                  ),
                ),
              ],
            ],
          ),
          if (onExit != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onExit();
              },
              child: const Text('返回大厅'),
            ),
        ],
      ),
    ),
  );
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
