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
Future<GameSettlementResult?> reportAndSettle({
  required BuildContext context,
  required GameModel game,
  required GameLevelModel level,
  required Map<String, num> scoreValuesByCode,
  required int durationMs,
  bool cleared = true,
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

  // 上报成绩（best-effort，失败仅记日志）
  await GameScoreService.instance.submitScore(
    gameId: game.id,
    levelId: level.id.isEmpty ? null : level.id,
    cleared: cleared,
    durationMs: durationMs,
    values: valuesById,
  );

  // 结算奖励
  final result = await GameRewardService.instance.settleGame(
    game: game,
    level: level,
    scoreValuesByCode: scoreValuesByCode,
  );

  if (context.mounted) {
    showSettlementSheet(context, game, result, scoreValuesByCode);
  }
  return result;
}

/// 弹出结算页（本次成绩 + 奖励明细 + 总积分）
void showSettlementSheet(
  BuildContext context,
  GameModel game,
  GameSettlementResult result,
  Map<String, num> scoreValuesByCode,
) {
  final dims = GameService.instance.cachedConfig.dimensionsOf(game.id);
  String fmtDim(String code, num value) {
    if (code == 'duration_ms') {
      final sec = (value / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final dim = dims.where((d) => d.code == code).firstOrNull;
    return '${value.toInt()}${dim?.unit ?? ''}';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好的'),
            ),
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
