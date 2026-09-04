import 'package:flutter/material.dart';

import 'models/game_model.dart';
import 'models/match3_mode.dart';

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
      return _match3Guide();
    case 'sheep':
      return _sheepGuide();
    case 'g2048':
      return _g2048Guide();
    default:
      return GameGuideInfo(title: game.name);
  }
}

GameGuideInfo _match3Guide() {
  // 复用 Match3Mode 的枚举元数据，6 个模式一段说明，零漂移。
  final modeSections = Match3Mode.values.map((m) {
    return GameGuideSection(
      title: m.label,
      body: '${m.summary}\n\n${m.detail}',
      icon: m.icon,
    );
  }).toList();

  return GameGuideInfo(
    title: '消消乐',
    intro: '点选两个相邻糖果交换位置，三个及以上同色连成一线即消除。'
        '利用连锁与特殊糖可在更少的步数里拿到更高分。下面按 6 种目标模式分别说明：',
    sections: modeSections,
  );
}

GameGuideInfo _sheepGuide() {
  return const GameGuideInfo(
    title: '羊了个羊',
    intro: '点击上层未被压住的方块加入底部槽位，凑齐三个相同图案即可消除。'
        '槽位满 7 个且无法消除即失败。下面按两种模式分别说明：',
    sections: <GameGuideSection>[
      GameGuideSection(
        title: '基础规则',
        body: '图案按多层堆叠，被上层压住的方块无法点击，需先消掉上层。'
            '底部槽位最多容纳 7 个，凑齐 3 个同类即消除；'
            '层数、类型数与遮挡率随关卡逐步提升。',
      ),
      GameGuideSection(
        title: '经典模式',
        body: '无时间限制，从容规划消除顺序。'
            '优先处理覆盖面广的方块，避免把关键图案锁在底层；'
            '优先消除同类的成对图案，为后层腾出空间。',
      ),
      GameGuideSection(
        title: '限时模式',
        body: '在经典规则上增加倒计时（前期约 87 秒，随关卡放宽到约 255 秒），'
            '倒计时归零仍未清空棋盘即失败。节奏更快，见缝插针地消除。',
      ),
      GameGuideSection(
        title: '道具',
        body: '卡关时可借用道具（移出 / 撤回 / 洗牌）缓解局面，'
            '每局各有免费次数，合理使用能在最难的层里翻盘。',
      ),
    ],
  );
}

GameGuideInfo _g2048Guide() {
  return const GameGuideInfo(
    title: '2048',
    intro: '在 4×4 网格上滑动，相同数字方块相撞即合并为两倍。'
        '每步结束后随机生成一个 2 或 4。下面按四种模式分别说明：',
    sections: <GameGuideSection>[
      GameGuideSection(
        title: '基本操作',
        body: '上下左右滑动让所有方块朝该方向移动到尽头并合并。'
            '一次滑动中，每个方块最多合并一次；棋盘填满且四向无法移动即失败。',
      ),
      GameGuideSection(
        title: '经典模式',
        body: '合成出目标数字方块即通关（无分数门槛），'
            '目标随关卡逐步提高，追求以更少的步数达成。',
      ),
      GameGuideSection(
        title: '限时模式',
        body: '在限定时间内（约 60~297 秒，随关卡变化）让分数达到目标值，'
            '倒计时归零未达标即失败。连招合并拿高分是关键。',
      ),
      GameGuideSection(
        title: '挑战模式',
        body: '限定步数（约 80~396 步）内达到目标分数，'
            '步数耗尽未达标即失败——每一步都要精打细算。',
      ),
      GameGuideSection(
        title: '无尽模式',
        body: '永不通关的休闲玩法：没有步数与时间限制，随时开一局挑战最高分，'
            '分数里程碑就是你的目标线。',
      ),
      GameGuideSection(
        title: '策略',
        body: '尽量把最大数字固定在角落，并让各行/列保持由大到小的梯度，'
            '留出移动空间，避免被小数字堵死。',
      ),
    ],
  );
}
