import 'package:flutter/foundation.dart';

import '../models/game_level_model.dart';
import '../models/game_mode_model.dart';
import '../models/game_model.dart';
import '../services/game_item_service.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';
import 'game_flow_config.dart';
import 'game_registry.dart';

/// 节点解析来源：配置成功 / 降级（关闭或异常）。
enum FlowSource { configured, fallback }

/// 单节点的解析结果（来源 + 备注），供调试与降级判定。
class FlowNodeState {
  final FlowSource source;

  /// 降级原因（configured 时为 null）。
  final String? reason;

  const FlowNodeState.configured() : source = FlowSource.configured, reason = null;
  const FlowNodeState.fallback(this.reason) : source = FlowSource.fallback;

  bool get isFallback => source == FlowSource.fallback;
}

/// 首页流程结果：模式 / 关卡 / 通关进度 / 商城 + 各节点状态。
///
/// UI 层不直接判配置，只消费本结果的派生 getter（modeGridAvailable 等），
/// 保证「配置 → 展示」的口径全 App 唯一。
class GameHomeFlow {
  /// 该游戏的流程配置（games.config['flow']）。
  final GameFlowConfig flow;

  /// 参与模式网格的模式（已按模式级开关 / modeGrid 节点开关过滤）。
  final List<GameModeModel> modes;

  /// 全量启用关卡（选关 / frontier 推进用）。
  final List<GameLevelModel> levels;

  /// 已通关关卡 id。
  final Set<String> clearedIds;

  /// 是否有道具商城。
  final bool hasShop;

  /// 节点状态（调试/排查用）。
  final Map<GameFlowNode, FlowNodeState> nodeStates;

  const GameHomeFlow({
    required this.flow,
    this.modes = const <GameModeModel>[],
    this.levels = const <GameLevelModel>[],
    this.clearedIds = const <String>{},
    this.hasShop = false,
    this.nodeStates = const <GameFlowNode, FlowNodeState>{},
  });

  /// 是否展示模式网格：modeGrid 节点开启 且 有可玩模式。
  bool get modeGridAvailable =>
      flow.nodeEnabled(GameFlowNode.modeGrid) && modes.isNotEmpty;

  /// 是否展示「选择关卡」入口：levelSelect 节点开启 且 游戏允许选关 且 多关。
  bool get levelSelectAvailable =>
      flow.nodeEnabled(GameFlowNode.levelSelect) &&
      levels.length > 1;

  /// 是否走默认流程开局：总开关关闭 / 无任何可玩内容（模式与关卡皆空）。
  bool get defaultPlayOnly =>
      !flow.enabled || (modes.isEmpty && levels.isEmpty);
}

/// 对局开局计划：进对局前由 runner 一次性解析。
class GamePlayPlan {
  /// 实际游玩的关卡（可能是配置关，也可能是默认合成关）。
  final GameLevelModel level;

  /// 是否允许结算发分/成就（配置关且 settlement 节点开启）。
  final bool rewardsAllowed;

  /// 关卡来源（configured=后台配置关 / fallback=默认合成关）。
  final FlowNodeState levelState;

  const GamePlayPlan({
    required this.level,
    required this.rewardsAllowed,
    required this.levelState,
  });
}

/// 游戏流程编排器（单例）。
///
/// 三游戏共用的流程骨架：首页加载（配置→模式→关卡→通关进度→商城）、
/// 开局解析（显式选关→模式 frontier→全局 frontier→默认关）、
/// 结算门禁（rewardsAllowed）。节点异常一律 try/catch 降级并记日志，不抛出。
class GameFlowRunner {
  GameFlowRunner._();

  static final GameFlowRunner instance = GameFlowRunner._();

  /// 首页加载：按节点解析并逐节点降级。从不抛异常（失败=默认流程）。
  Future<GameHomeFlow> loadHome(GameModel game, {bool force = false}) async {
    final flow = GameFlowConfig.of(game);
    final states = <GameFlowNode, FlowNodeState>{};

    // 总开关关闭：跳过全部配置节点，直接默认流程（商城/记录与流程无关，照常提供）
    if (!flow.enabled) {
      final shop = await _resolveShop(game);
      return GameHomeFlow(flow: flow, hasShop: shop, nodeStates: states);
    }

    // 节点：配置快照（force 拉最新，后台改动即时可见）
    GameConfigSnapshot snapshot;
    try {
      snapshot = await GameService.instance.fetchConfig(force: force);
      states[GameFlowNode.modeGrid] = const FlowNodeState.configured();
      states[GameFlowNode.levelSelect] = const FlowNodeState.configured();
    } catch (e) {
      debugPrint('[GameFlow] 配置节点异常，降级默认流程：$e');
      states[GameFlowNode.modeGrid] = FlowNodeState.fallback('配置拉取异常');
      states[GameFlowNode.levelSelect] = FlowNodeState.fallback('配置拉取异常');
      final shop = await _resolveShop(game);
      return GameHomeFlow(flow: flow, hasShop: shop, nodeStates: states);
    }

    // 节点：模式网格（模式级开关过滤；nodeGrid 关闭则不产出任何模式）
    var modes = <GameModeModel>[];
    if (flow.nodeEnabled(GameFlowNode.modeGrid)) {
      try {
        modes = snapshot
            .modesOf(game.id)
            .where(modeFlowEnabled)
            .toList(growable: false);
      } catch (e) {
        debugPrint('[GameFlow] 模式节点异常，隐藏网格：$e');
        states[GameFlowNode.modeGrid] = FlowNodeState.fallback('模式解析异常');
      }
    } else {
      states[GameFlowNode.modeGrid] = FlowNodeState.fallback('节点关闭');
    }

    // 节点：关卡（levelSelect 关闭仍需关卡数据做 frontier 开局）
    var levels = <GameLevelModel>[];
    try {
      levels = snapshot.levelsOf(game.id);
    } catch (e) {
      debugPrint('[GameFlow] 关卡节点异常：$e');
      states[GameFlowNode.levelSelect] = FlowNodeState.fallback('关卡解析异常');
      levels = const <GameLevelModel>[];
    }

    // 节点：通关进度（选关/已通关 N/M 展示用，失败仅影响展示）
    var cleared = const <String>{};
    try {
      cleared = await GameScoreService.instance.fetchClearedLevelIds(game.id);
    } catch (e) {
      debugPrint('[GameFlow] 通关进度节点异常：$e');
    }

    final shop = await _resolveShop(game);
    return GameHomeFlow(
      flow: flow,
      modes: modes,
      levels: levels,
      clearedIds: cleared,
      hasShop: shop,
      nodeStates: states,
    );
  }

  /// 开局解析（统一入口）：
  /// 1. [explicit] 非空 → 直接用（选关/无尽合成关/下一关）；
  /// 2. 否则按模式范围（[modeId]）取全局第一个未通关 frontier，全通关取末关；
  /// 3. 无任何配置关 → 适配器合成默认关（内置经典模式）。
  ///
  /// [rewardsAllowed] = flow.enabled && settlement 节点开 && 关卡属于配置流程：
  /// 配置关（level.id 非空）或显式传入的模式合成关（无尽模式，modeId 非空）。
  /// 默认关（模式与关卡均无配置）不发分不发成就（参考文档 §16.2）。
  GamePlayPlan resolvePlayPlan(
    GameModel game, {
    GameLevelModel? explicit,
    String? modeId,
    List<GameLevelModel>? levels,
    Set<String>? clearedIds,
  }) {
    final flow = GameFlowConfig.of(game);
    final settlementOn = flow.nodeEnabled(GameFlowNode.settlement);

    GameLevelModel? level;
    FlowNodeState state = const FlowNodeState.fallback('无可用关卡，使用默认流程');
    if (explicit != null) {
      level = explicit;
      state = const FlowNodeState.configured();
    } else {
      try {
        var scoped = levels ?? GameService.instance.cachedConfig.levelsOf(game.id);
        if (modeId != null && modeId.isNotEmpty) {
          final inMode = scoped.where((l) => l.modeId == modeId).toList();
          if (inMode.isNotEmpty) scoped = inMode;
        }
        if (scoped.isNotEmpty) {
          final cleared = clearedIds ?? const <String>{};
          level = scoped.firstWhere(
            (l) => !cleared.contains(l.id),
            orElse: () => scoped.last,
          );
          state = const FlowNodeState.configured();
        }
      } catch (e) {
        debugPrint('[GameFlow] frontier 解析异常，使用默认关：$e');
      }
    }

    if (level == null) {
      final adapter = GameFlowRegistry.adapterOf(game.code);
      if (adapter == null) {
        // 未注册的游戏：合成通用空关（引擎层会展示「暂未实现」）。
        level = GameLevelModel(
          id: '',
          gameId: game.id,
          levelNo: 1,
          name: '默认关卡',
        );
      } else {
        level = adapter.defaultLevel(game);
      }
      state = FlowNodeState.fallback('无配置关卡，使用默认流程');
    }

    // 结算门禁：默认关（id 与 modeId 均空）不发分；配置关与无尽等
    // 显式模式合成关（modeId 来自后台）照常发分。
    final configuredFlow =
        level.id.isNotEmpty || (explicit != null && level.modeId.isNotEmpty);
    final rewardsAllowed = flow.enabled && settlementOn && configuredFlow;
    return GamePlayPlan(
      level: level,
      rewardsAllowed: rewardsAllowed,
      levelState: state,
    );
  }

  /// 商城可用性（与流程节点无关，失败=无商城）。
  Future<bool> _resolveShop(GameModel game) async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: game.code);
      return items.isNotEmpty;
    } catch (e) {
      debugPrint('[GameFlow] 商城节点异常：$e');
      return false;
    }
  }
}
