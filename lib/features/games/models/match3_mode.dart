import 'package:flutter/material.dart';

/// 消消乐玩法模式（对标市场主流三消手游的 6 类关卡目标）。
///
/// 落库方式（**无 DDL**）：模式写在 `game_levels.config.mode`，同时用
/// `level_no` 编码 `模式序号 × 100 + 模式内关序(1~50)`（如 201..250 =
/// 消除模式 1~50 关），使 `(game_id, level_no)` 唯一约束天然容纳
/// 「每模式 50 关 / 共 300 关」，且后台关卡管理页无需改造即可维护。
/// config 缺 mode 时按 level_no **百位**兜底推导。
///
/// ⚠️ 该编码由 `/d/workspace/sql/feature_reseed_match3_levels_300.sql` 落库，
/// 改动编码规则必须同步 [parseMatch3Mode] 与 [match3LevelIndex]。
enum Match3Mode {
  /// 步数计分：限定步数内达到目标分（经典关）
  score,

  /// 消除完：限定步数内清除盘面上全部「目标格」（果冻层全清）
  clear,

  /// 收集：限定步数内收集指定颜色糖果 N 个
  collect,

  /// 障碍清除：限定步数内打碎全部冰封格（每格需被覆盖消除 2 次）
  obstacle,

  /// 限时：倒计时内达到目标分
  timed,

  /// Boss 战：限定步数内打光 Boss 血量（消除即造成伤害）
  boss,
}

extension Match3ModeMeta on Match3Mode {
  /// 落库编码（config.mode 的取值）
  String get code {
    switch (this) {
      case Match3Mode.score:
        return 'score';
      case Match3Mode.clear:
        return 'clear';
      case Match3Mode.collect:
        return 'collect';
      case Match3Mode.obstacle:
        return 'obstacle';
      case Match3Mode.timed:
        return 'timed';
      case Match3Mode.boss:
        return 'boss';
    }
  }

  /// 模式序号（1~6），即 level_no 的百位（level_no = index × 100 + 关序）
  int get index => Match3Mode.values.indexOf(this) + 1;

  /// 展示名
  String get label {
    switch (this) {
      case Match3Mode.score:
        return '计分模式';
      case Match3Mode.clear:
        return '消除模式';
      case Match3Mode.collect:
        return '收集模式';
      case Match3Mode.obstacle:
        return '破冰模式';
      case Match3Mode.timed:
        return '限时模式';
      case Match3Mode.boss:
        return 'Boss 模式';
    }
  }

  /// 一句话目标说明
  String get summary {
    switch (this) {
      case Match3Mode.score:
        return '在限定步数内达到目标分数';
      case Match3Mode.clear:
        return '在限定步数内消除盘面上所有果冻格';
      case Match3Mode.collect:
        return '在限定步数内收集足够数量的指定糖果';
      case Match3Mode.obstacle:
        return '在限定步数内敲碎所有冰封格（每格需消除两次）';
      case Match3Mode.timed:
        return '在倒计时结束前达到目标分数';
      case Match3Mode.boss:
        return '在限定步数内消除糖果造成伤害，打光 Boss 血量';
    }
  }

  /// 详细玩法说明（主界面「查看说明」用）
  String get detail {
    switch (this) {
      case Match3Mode.score:
        return '经典三消关。每次交换消耗 1 步，消除越多、连锁越长得分越高。'
            '步数用尽时分数达标即通关。';
      case Match3Mode.clear:
        return '盘面部分格子带果冻底。糖果在果冻格上被消除即可清掉该格果冻，'
            '把所有果冻清空即通关；步数用尽仍有残留则失败。';
      case Match3Mode.collect:
        return '关卡指定一种颜色的糖果作为收集目标，消除该颜色即累计数量，'
            '达到指定个数即通关。特殊糖的连带消除同样计入。';
      case Match3Mode.obstacle:
        return '冰封格需要被覆盖消除两次才会彻底破碎（第一次裂开、第二次清除）。'
            '在步数内敲碎全部冰封格即通关。';
      case Match3Mode.timed:
        return '不限步数但有倒计时。抓紧时间制造连锁，倒计时归零时分数达标即通关。';
      case Match3Mode.boss:
        return '每消除 1 个糖果对 Boss 造成 1 点伤害，特殊糖伤害翻倍。'
            '在步数用尽前把 Boss 血量清零即获胜。';
    }
  }

  IconData get icon {
    switch (this) {
      case Match3Mode.score:
        return Icons.stars_rounded;
      case Match3Mode.clear:
        return Icons.blur_on;
      case Match3Mode.collect:
        return Icons.inventory_2_outlined;
      case Match3Mode.obstacle:
        return Icons.ac_unit;
      case Match3Mode.timed:
        return Icons.timer_outlined;
      case Match3Mode.boss:
        return Icons.pest_control_rodent;
    }
  }

  /// SVG 资源路径（与 App 端 assets/games/icons 同名文件；双端统一图标）。
  String get svg => 'assets/games/icons/mode_${code}.svg';

  Color get color {
    switch (this) {
      case Match3Mode.score:
        return const Color(0xFFFFA726);
      case Match3Mode.clear:
        return const Color(0xFFAB47BC);
      case Match3Mode.collect:
        return const Color(0xFF66BB6A);
      case Match3Mode.obstacle:
        return const Color(0xFF42A5F5);
      case Match3Mode.timed:
        return const Color(0xFFEF5350);
      case Match3Mode.boss:
        return const Color(0xFF8D6E63);
    }
  }
}

/// 从关卡 config / level_no 解析模式；无法识别时回落到 [Match3Mode.score]。
///
/// 解析优先级（v2 统一模式体系）：
///   1. play_kind（后台 game_modes.play_kind，模式→引擎行为的唯一真相源）；
///   2. config 语义键（04 种子直接携带，无需 mode 字段即可判定，鲁棒兜底）；
///   3. level_no 百位（旧编码兜底）；
///   4. score。
Match3Mode parseMatch3Mode(Map<String, dynamic> config, int levelNo) {
  final raw = config['mode'];
  if (raw is String && raw.isNotEmpty) {
    for (final m in Match3Mode.values) {
      if (m.code == raw) return m;
    }
  }
  // 04 种子 config 携带语义键，无需 mode 字段即可判定（兜底鲁棒）
  if (config.containsKey('time_limit')) return Match3Mode.timed;
  if (config.containsKey('jelly_layers')) return Match3Mode.clear;
  if (config.containsKey('ingredients') || config.containsKey('orders')) {
    return Match3Mode.collect;
  }
  // 兜底：level_no 百位即模式序号（101..150=计分，201..250=消除 ...）
  final idx = levelNo ~/ 100;
  if (idx >= 1 && idx <= Match3Mode.values.length) {
    return Match3Mode.values[idx - 1];
  }
  return Match3Mode.score;
}

/// 按 play_kind（引擎 6 行为码 score/clear/collect/obstacle/timed/boss）解析模式；
/// 无/未知返回 null，交由 [parseMatch3Mode] 继续兜底。
Match3Mode? match3ModeFromPlayKind(String? playKind) {
  if (playKind == null || playKind.isEmpty) return null;
  for (final m in Match3Mode.values) {
    if (m.code == playKind) return m;
  }
  return null;
}

/// 综合解析：优先 play_kind（后台语义，唯一真相源），
/// 回落 config 键检测 / level_no 百位 / score。引擎侧统一入口。
Match3Mode resolveMatch3Mode({
  required Map<String, dynamic> config,
  int levelNo = 0,
  String? playKind,
}) {
  final fromPk = match3ModeFromPlayKind(playKind);
  if (fromPk != null) return fromPk;
  return parseMatch3Mode(config, levelNo);
}

/// 每个 match3 模式的关卡数（编码 `模式序号 × 100 + 1..50` 的容量）。
const int match3LevelsPerMode = 50;

/// 关卡的**全局关序**（1~300）：把 `level_no` 的
/// 「模式序号 × 100 + 模式内关序(1~50)」编码折算为跨模式连续关序。
///
/// 该口径用于成就「累计通关至第 N 关」判定：`game_achievements.condition`
/// 的 `min_level_no` 阈值为 5/10/20/30/50/70/100/150/200/300，其中
/// 300 恰为「第 6 模式第 50 关」（最后一关），故必须按全局关序比对，
/// 不能用原始 level_no（101 会被当成第 101 关而误判达成多档成就），
/// 也不能只取模式内关序（最大 50，会让 70 以上的成就永不可达）。
///
/// 旧数据（未编码、`level_no < 100`）原样返回，保证兼容。
int match3LevelIndex(int levelNo) {
  final mode = levelNo ~/ 100; // 1..6
  final unit = levelNo % 100; // 1..50
  if (mode < 1 || mode > Match3Mode.values.length || unit < 1) return levelNo;
  return (mode - 1) * match3LevelsPerMode + unit;
}

/// 模式编码 → 中文展示名（未知编码原样返回）。
/// 供道具商城/道具管理等展示 `game_items.mode`（如 timed → 限时模式）。
String match3ModeLabelOf(String code) {
  for (final m in Match3Mode.values) {
    if (m.code == code) return m.label;
  }
  return code;
}

/// 按 play_kind（模式语义编码）取统一模式网格的展示色。
/// match3 六模式（score/clear/collect/obstacle/timed/boss）取各自配色；
/// 其余（2048 / merge 等）回落默认棕，保证三游戏网格视觉一致。
Color modeColorOf(String playKind) {
  for (final m in Match3Mode.values) {
    if (m.code == playKind) return m.color;
  }
  return const Color(0xFF5D4037);
}
