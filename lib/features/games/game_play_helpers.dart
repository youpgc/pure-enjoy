import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/game_dimension_model.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'play/game_settlement_sheet.dart';
import 'services/game_reward_service.dart';
import 'services/game_score_service.dart';
import 'services/game_service.dart';

/// 打包进本 App 的资源清单缓存（进程内一次加载）。
Set<String>? _bundledAssetCache;

/// 判断本 App 是否打包了某游戏的图标资源（`assets/games/icons/<icon>.svg`）。
///
/// 用途：**测试环境判定**（2026-09-10）——后台 games.test_only=true 的游戏
/// 只在「打包了对应资源」的测试/开发包里展示（资源能匹配 = 本包是为该游戏
/// 打的测试包）；生产包未打包其资源 → 不展示。
/// [icon] 为 games.icon 原始文件名（不做 legacy 回退——回退会让资源判定失真）。
Future<bool> hasBundledGameAsset(String? icon) async {
  if (icon == null || icon.isEmpty) return false;
  final asset = 'assets/games/icons/$icon.svg';
  final cache = _bundledAssetCache;
  if (cache == null) {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundledAssetCache = manifest.listAssets().toSet();
    } catch (e) {
      debugPrint('[game_play_helpers] 资源清单加载失败：$e');
      _bundledAssetCache = <String>{};
    }
  }
  return _bundledAssetCache!.contains(asset);
}

/// 游戏结果（供游戏页回传结算）
class GamePlayOutcome {
  /// 是否通关
  final bool cleared;

  /// 失败原因（可选）：如残局判负的「无可消组合，对局结束」；
  /// 非空且 [cleared] 为 false 时结算弹窗优先展示该文案。
  final String? reason;

  /// 成绩维度取值（维度编码 → 数值），如 {'score': 2048, 'duration_ms': 12345}
  final Map<String, num> values;

  /// 本次游玩耗时（毫秒）
  final int durationMs;

  const GamePlayOutcome({
    required this.cleared,
    this.reason,
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

/// 上报成绩 + 结算奖励 + 弹结算页。返回结算结果（未登录/失败可能为 null）。
///
/// [aborted] 为 true 表示用户中途主动放弃：只上报 status='aborted' 的成绩，
/// 不结算奖励、不弹结算页（放弃不发分，防止刷分）。
///
/// [rewardsAllowed] 为 false（默认流程：流程总开关关闭 / settlement 节点关闭 /
/// 默认合成关）时：成绩照常上报，但**不走奖励结算**——不发积分、不发成就，
/// 结算页仅展示成绩（参考文档 §16.2）。
///
/// **结算弹窗在游戏结束立即弹出**：成绩上报与奖励结算在弹窗内异步进行，
/// 加载完成前展示 loading 且弹窗不可关闭（禁其他操作），完成后渲染明细。
Future<GameSettlementResult?> reportAndSettle({
  required BuildContext context,
  required GameModel game,
  required GameLevelModel level,
  required Map<String, num> scoreValuesByCode,
  required int durationMs,
  bool cleared = true,
  bool aborted = false,
  bool rewardsAllowed = true,

  /// 失败原因（来自引擎 outcome.reason，如残局判负），结算弹窗展示。
  String? failReason,

  /// 无尽模式会话结算：弹窗标题「无尽模式 · 结算」，无通关/失败语义。
  bool endless = false,
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

  // 失败记录门槛（2026-09-10 用户拍板）：非通关对局，当局步数 <5 不计入
  // 成绩记录（防秒败刷记录）。以 moves 维度取值为准——无 moves 维度的
  // 游戏（sheep 等）不适用此门槛；放弃路径另有 ≥10s 时长门槛。
  final failedMoves = cleared ? null : scoreValuesByCode['moves'];
  final belowMoveFloor = !cleared && failedMoves != null && failedMoves < 5;

  // 放弃：只上报成绩，不结算不弹窗（放弃不发分，防止刷分）
  if (aborted) {
    if (!belowMoveFloor) {
      await GameScoreService.instance.submitScore(
        gameId: game.id,
        levelId: level.id.isEmpty ? null : level.id,
        modeId: level.modeId.isEmpty ? null : level.modeId,
        cleared: cleared,
        statusOverride: 'aborted',
        durationMs: durationMs,
        values: valuesById,
      );
    }
    return null;
  }

  // 游戏结束立即弹出结算页；成绩上报 + 奖励结算在弹窗内异步进行，
  // 加载完成前展示 loading，期间弹窗不可点遮罩关闭/拖拽（禁其他操作）。
  final completer = Completer<GameSettlementResult?>();
  final settleFuture = () async {
    // 成绩上报：通关 / 达标失败局始终记录；步数 <5 的失败局不计入
    //（默认流程也记录成绩，仅不发奖励）
    if (!belowMoveFloor) {
      await GameScoreService.instance.submitScore(
        gameId: game.id,
        levelId: level.id.isEmpty ? null : level.id,
        modeId: level.modeId.isEmpty ? null : level.modeId,
        cleared: cleared,
        durationMs: durationMs,
        values: valuesById,
      );
    }
    // 奖励结算门禁：默认流程跳过（claim_key 体系不触发 = 不发分不发成就）
    if (!rewardsAllowed) {
      return const GameSettlementResult(items: <GameSettlementItem>[]);
    }
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
      builder: (ctx) => GameSettlementSheet(
        game: game,
        cleared: cleared,
        failReason: failReason,
        scoreValuesByCode: scoreValuesByCode,
        settleFuture: settleFuture,
        scoreOnly: !rewardsAllowed,
        endless: endless,
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
