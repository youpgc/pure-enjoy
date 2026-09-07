import 'package:flutter/material.dart';

import '../game_play_helpers.dart';
import '../games/g2048/g2048_game.dart';
import '../games/match3/match3_game.dart';
import '../games/sheep/sheep_game.dart';
import '../models/game_level_model.dart';
import '../models/game_model.dart';

/// 游戏流程适配器：新游戏接入 GameFlow 体系的唯一扩展点。
///
/// 体系（首页加载 / 选关 / 结算 / 奖励 / 成就）对三游戏通用；
/// 每游戏只需提供三件事：
/// 1. [defaultLevel] —— 默认流程的合成关卡（内置经典/常规模式，无 DB 依赖；
///    `level.id` 为空标识"非配置关"，结算层据此禁发积分/成就）；
/// 2. [buildEngine] —— 按关卡构建引擎视图（即游戏本体组件）；
/// 3. [code] —— 与 `games.code` 对齐的注册键。
///
/// 需要个性化的游戏可覆写更多行为或在 adapter 外自行编排；体系不强制。
abstract class GameFlowAdapter {
  /// 游戏编码（games.code）：'sheep' / 'g2048' / 'match3' / ...
  String get code;

  /// 默认流程合成关卡：内置经典/常规模式，无需选模式选关卡。
  ///
  /// [config] 可留空——各引擎对空配置均有兜底（sheep 自生成棋盘、
  /// g2048 经典判定、match3 回落计分模式），与既有 resolveLevel 行为一致。
  GameLevelModel defaultLevel(GameModel game);

  /// 构建引擎视图。[key] 由调用方提供（须随重玩 nonce 变化、随普通 setState 稳定，
  /// 如 `ValueKey(restartNonce)`——引擎重建语义完全由调用方控制）。
  /// [onRestart] 仅消消乐使用（引擎内重开按钮）。
  Widget buildEngine({
    required Key key,
    required GameModel game,
    required GameLevelModel level,
    required ValueChanged<GamePlayOutcome> onFinished,
    required VoidCallback onRestart,
  });
}

/// 羊了个羊适配器：经典模式 = 空配置自生成棋盘（引擎内置难度曲线）。
class _SheepAdapter extends GameFlowAdapter {
  @override
  String get code => 'sheep';

  @override
  GameLevelModel defaultLevel(GameModel game) => GameLevelModel(
        id: '',
        gameId: game.id,
        levelNo: 1,
        name: '经典模式',
      );

  @override
  @override
  Widget buildEngine({
    required Key key,
    required GameModel game,
    required GameLevelModel level,
    required ValueChanged<GamePlayOutcome> onFinished,
    required VoidCallback onRestart,
  }) {
    return SheepGame(key: key, onFinished: onFinished, level: level);
  }
}

/// 2048 适配器：默认流程 = 经典 4×4 合成 2048。
class _G2048Adapter extends GameFlowAdapter {
  @override
  String get code => 'g2048';

  @override
  GameLevelModel defaultLevel(GameModel game) => GameLevelModel(
        id: '',
        gameId: game.id,
        levelNo: 1,
        name: '经典模式',
        config: const <String, dynamic>{'size': 4, 'target': 2048},
      );

  @override
  @override
  Widget buildEngine({
    required Key key,
    required GameModel game,
    required GameLevelModel level,
    required ValueChanged<GamePlayOutcome> onFinished,
    required VoidCallback onRestart,
  }) {
    return G2048Game(key: key, onFinished: onFinished, level: level);
  }
}

/// 消消乐适配器：默认流程 = 计分模式兜底（play_kind/配置缺位时引擎回落 score）。
class _Match3Adapter extends GameFlowAdapter {
  @override
  String get code => 'match3';

  @override
  GameLevelModel defaultLevel(GameModel game) => GameLevelModel(
        id: '',
        gameId: game.id,
        levelNo: 1,
        name: '计分模式',
      );

  @override
  @override
  Widget buildEngine({
    required Key key,
    required GameModel game,
    required GameLevelModel level,
    required ValueChanged<GamePlayOutcome> onFinished,
    required VoidCallback onRestart,
  }) {
    return Match3Game(
      key: key,
      onFinished: onFinished,
      level: level,
      onRestart: onRestart,
    );
  }
}

/// 流程注册表：game.code → adapter。
///
/// 新游戏接入：实现 [GameFlowAdapter] 后在此注册一行即可复用全链路。
class GameFlowRegistry {
  GameFlowRegistry._();

  static final Map<String, GameFlowAdapter> _adapters = <String, GameFlowAdapter>{
    _SheepAdapter().code: _SheepAdapter(),
    _G2048Adapter().code: _G2048Adapter(),
    _Match3Adapter().code: _Match3Adapter(),
  };

  /// 取适配器；未注册的游戏返回 null（调用方回落「该游戏暂未实现」占位）。
  static GameFlowAdapter? adapterOf(String gameCode) => _adapters[gameCode];
}
