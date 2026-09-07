import 'package:flutter/material.dart';

import 'models/game_model.dart';
import 'models/game_mode_model.dart';
import 'models/match3_mode.dart';
import 'services/game_service.dart';

/// 玩法说明数据源：集中三款游戏（羊了个羊 / 2048 / 消消乐）的说明文案，
/// 主界面「查看说明」统一调用 [gameGuideOf] 取用，避免文案散落各处。
///
/// 消消乐的 6 种模式说明直接复用 [Match3Mode] 的 [Match3Mode.detail] /
/// [Match3Mode.summary]，模式名称/图标/配色也与选关、盘面对齐，避免漂移。

/// 一段说明（小标题 + 正文）
class GameGuideSection {
  final String title;
  final String body;
  final IconData? icon;

  const GameGuideSection({
    required this.title,
    required this.body,
    this.icon,
  });
}

/// 一款游戏的完整说明
class GameGuideInfo {
  final String title;
  final String? intro;
  final List<GameGuideSection> sections;

  const GameGuideInfo({
    required this.title,
    this.intro,
    this.sections = const <GameGuideSection>[],
  });
}

/// 取指定游戏的说明；未知游戏返回空 sections（调用方应对空态）。
GameGuideInfo gameGuideOf(GameModel game) {
  switch (game.code) {
    case 'match3':
      return _match3Guide(game);
    case 'sheep':
      return _sheepGuide(game);
    case 'g2048':
      return _g2048Guide(game);
    default:
      return GameGuideInfo(title: game.name);
  }
}

/// 游戏介绍：后台 games.intro 优先，空回退内置文案。
String? _introOf(GameModel game, String fallback) {
  final i = game.intro;
  return (i != null && i.isNotEmpty) ? i : fallback;
}

/// 游戏规则段：后台 games.rules 优先替换正文，标题沿用各游戏内置。
GameGuideSection _rulesSection(
  GameModel game, {
  required String title,
  required String fallbackBody,
}) {
  final r = game.rules;
  return GameGuideSection(
      title: title, body: (r != null && r.isNotEmpty) ? r : fallbackBody);
}

/// 生成「按模式」的说明段：优先用后台 game_modes.guide（模式配置维护），
/// 无配置时按 play_kind 回退内置文案（零漂移兜底）。
List<GameGuideSection> _modeSectionsOf(GameModel game, Match3Mode? Function(GameModeModel) modeOf) {
  final modes = GameService.instance.cachedConfig.modesOf(game.id);
  if (modes.isEmpty) return const <GameGuideSection>[];
  return modes.map((m) {
    final meta = modeOf(m);
    // 后台配置：summary（一句话简介）+ guide（达成规则描述）组合展示
    final configured = <String>[
      if (m.summary.isNotEmpty) m.summary,
      if (m.guide.isNotEmpty) m.guide,
    ].join('\n');
    final body = configured.isNotEmpty
        ? configured
        : (meta != null ? '${meta.summary}\n\n${meta.detail}' : '');
    return GameGuideSection(title: m.name, body: body, icon: meta?.icon);
  }).where((s) => s.body.isNotEmpty).toList();
}

GameGuideInfo _match3Guide(GameModel game) {
  final dynamicSections = _modeSectionsOf(game, (m) => match3ModeFromPlayKind(m.playKind));
  final sections = dynamicSections.isNotEmpty
      ? dynamicSections
      : Match3Mode.values.map((m) => GameGuideSection(
            title: m.label,
            body: '${m.summary}\n\n${m.detail}',
            icon: m.icon,
          )).toList();
  return GameGuideInfo(
    title: '消消乐',
    intro: _introOf(game, '点选两个相邻糖果交换位置，三个及以上同色连成一线即消除。'
        '利用连锁与特殊糖可在更少的步数里拿到更高分。下面按玩法模式分别说明：'),
    sections: <GameGuideSection>[
      _rulesSection(
        game,
        title: '基础规则',
        fallbackBody: '4 连生成条纹糖（清整行/列），L/T 交叉生成包装糖（清 3×3），'
            '5 连生成彩爆（清除同色全屏）；连锁越长得分倍率越高。',
      ),
      ...sections,
    ],
  );
}

GameGuideInfo _sheepGuide(GameModel game) {
  return GameGuideInfo(
    title: '羊了个羊',
    intro: _introOf(game, '点击上层未被压住的方块加入底部槽位，凑齐三个相同图案即可消除。'
        '槽位满 7 个且无法消除即失败。下面按模式分别说明：'),
    sections: <GameGuideSection>[
      _rulesSection(
        game,
        title: '基础规则',
        fallbackBody: '图案按多层堆叠，被上层压住的方块无法点击，需先消掉上层。'
            '底部槽位最多容纳 7 个，凑齐 3 个同类即消除；'
            '层数、类型数与遮挡率随关卡逐步提升。',
      ),
      ..._modeSectionsOf(game, (_) => null),
      const GameGuideSection(
        title: '道具',
        body: '卡关时可借用道具（移出 / 撤回 / 洗牌）缓解局面，'
            '每局各有免费次数，合理使用能在最难的层里翻盘。',
      ),
    ],
  );
}

GameGuideInfo _g2048Guide(GameModel game) {
  return GameGuideInfo(
    title: '2048',
    intro: _introOf(game, '在 4×4 网格上滑动，相同数字方块相撞即合并为两倍。'
        '每步结束后随机生成一个 2 或 4。下面按模式分别说明：'),
    sections: <GameGuideSection>[
      _rulesSection(
        game,
        title: '基本操作',
        fallbackBody: '上下左右滑动让所有方块朝该方向移动到尽头并合并。'
            '一次滑动中，每个方块最多合并一次；棋盘填满且四向无法移动即失败。',
      ),
      ..._modeSectionsOf(game, (_) => null),
      const GameGuideSection(
        title: '策略',
        body: '尽量把最大数字固定在角落，并让各行/列保持由大到小的梯度，'
            '留出移动空间，避免被小数字堵死。',
      ),
    ],
  );
}
