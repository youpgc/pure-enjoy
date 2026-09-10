import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/match3_mode.dart';

/// 一个被消除的格子（供目标判定用，避免 Objective 依赖渲染层 Candy）
class ClearedCell {
  final int row;
  final int col;
  final int type;

  /// 是否为特殊糖（Boss 模式伤害翻倍）
  final bool special;

  const ClearedCell(this.row, this.col, this.type, {this.special = false});
}

/// 单个颜色收集目标（collect / obstacle 模式，2026-09-07 多目标扩展）
///
/// config 形态：
/// - 数组多目标：`"collect": [{"type":1,"count":15},{"type":3,"count":10}]`
/// - 旧单值：`"collect": 20` + `"collectType": 1` → 归一为单目标
class CollectGoal {
  final int type;
  final int count;

  /// 已收集数（由 [Match3Objective.onCleared] 累计）
  int collected = 0;

  CollectGoal({required this.type, required this.count});

  /// 剩余待收集数（实时减少，供目标 banner 展示）
  int get remaining => (count - collected).clamp(0, count);

  /// 是否已达成
  bool get done => collected >= count;
}

/// HUD 展示项
class ObjectiveStat {
  final String label;
  final String value;

  /// 是否告急（剩余步数/时间不足时标红；alert 优先于 [color]）
  final bool alert;

  /// 语义色（各标识不同颜色表达不同含义，2026-09-09；null = 跟随主题前景）
  final Color? color;

  const ObjectiveStat(this.label, this.value, {this.alert = false, this.color});
}

/// 消消乐关卡目标状态机：统一承载 6 种模式的**目标初始化、进度累计、
/// 达成/失败判定与 HUD 数据**，与盘面渲染彻底解耦。
///
/// 引擎侧只需：
/// 1. onLoad 时调用 [initBoard]；
/// 2. 每次消除调用 [onCleared]；
/// 3. 每步结束查 [achieved]；步数/时间耗尽时查 [achieved] 决定通关或失败；
/// 4. 渲染时读 [jelly] / [ice] 叠加层。
class Match3Objective {
  final Match3Mode mode;
  final int rows;
  final int cols;

  /// 限定步数（timed 模式不使用）
  final int steps;

  /// 倒计时秒数（仅 timed）
  final int seconds;

  /// 目标分数（score / timed）
  final int goalScore;

  /// 收集目标数量（collect）
  final int collectTarget;

  /// 收集目标颜色索引（collect）
  final int collectType;

  /// 果冻格数量（clear）
  final int jellyCount;

  /// 冰封格数量（obstacle）
  final int iceCount;

  /// Boss 总血量（boss）
  final int bossHp;

  /// 果冻层：1 = 有果冻，0 = 已清除（[initBoard] 前为空，渲染需先判空）
  List<List<int>> jelly = <List<int>>[];

  /// 冰层：2 = 完整冰块，1 = 已裂开，0 = 已清除（[initBoard] 前为空）
  List<List<int>> ice = <List<int>>[];

  /// 颜色收集目标（collect 模式全部；obstacle 模式可选附加条件）
  final List<CollectGoal> collectGoals;

  /// 已收集数量（旧单目标口径兼容读取，= 首目标 collected）
  int get collected => collectGoals.isEmpty ? 0 : collectGoals.first.collected;

  /// 全部目标的已收集合计（HUD 合计进度项用）
  int get collectedTotal =>
      collectGoals.fold(0, (sum, g) => sum + g.collected);

  /// Boss 剩余血量（boss）
  int bossLeft = 0;

  /// 当前分数（由引擎同步）
  int score = 0;

  /// 剩余步数（由引擎同步；steps<=0 = 不限步数，仅展示不计减）
  int movesLeft = 0;

  /// 已用步数（全模式统计，含限时——结算成绩 moves 维度来源）
  int movesUsed = 0;

  /// 剩余秒数（由引擎同步，仅 timed）
  double secondsLeft = 0;

  Match3Objective({
    required this.mode,
    required this.rows,
    required this.cols,
    this.steps = 22,
    this.seconds = 90,
    this.goalScore = 1200,
    this.collectTarget = 20,
    this.collectType = 0,
    this.jellyCount = 14,
    this.iceCount = 16,
    this.bossHp = 260,
    this.collectGoals = const <CollectGoal>[],
  });

  /// 从关卡 config 构造（缺省值按模式给合理默认，保证无配置也能玩）
  ///
  /// [mode] 可由调用方按 play_kind 预先解析后传入，避免重复推导；
  /// 不传则内部按 config/level_no 兜底解析。
  /// 配置键兼容 04 种子的别名：jelly_layers→jelly、ingredients/orders→collect、
  /// time_limit→seconds（旧键 jelly/collect/bossHp/seconds 仍生效）。
  factory Match3Objective.fromConfig(
    Map<String, dynamic> config,
    int levelNo, {
    required int rows,
    required int cols,
    Match3Mode? mode,
  }) {
    final resolved = mode ?? parseMatch3Mode(config, levelNo);
    int intOf(String key, int fallback, [List<String>? aliases]) {
      final keys = <String>[key, ...?aliases];
      for (final k in keys) {
        final v = config[k];
        if (v is num) return v.toInt();
      }
      return fallback;
    }

    // 颜色收集目标解析（多目标数组优先，旧单值兜底）：
    // - collect 模式读 `collect`；obstacle 模式读 `iceCollect`（也可复用 `collect`）
    // - 数组形态 [{"type":1,"count":15},...]；旧单值 collect+collectType 归一单目标
    List<CollectGoal> parseGoals(String listKey) {
      final raw = config[listKey] ?? config['collect'];
      if (raw is List && raw.isNotEmpty) {
        final goals = <CollectGoal>[];
        for (final item in raw) {
          if (item is Map) {
            final t = (item['type'] as num?)?.toInt();
            final c = (item['count'] as num?)?.toInt();
            if (t != null && c != null && c > 0) {
              goals.add(CollectGoal(type: t, count: c));
            }
          }
        }
        return goals;
      }
      // 旧单值口径（仅 collect 模式历史数据）
      final single = intOf('collect', 0, ['ingredients', 'orders']);
      if (single > 0) {
        return <CollectGoal>[CollectGoal(type: intOf('collectType', 0), count: single)];
      }
      return <CollectGoal>[];
    }

    final goals = resolved == Match3Mode.collect
        ? parseGoals('collect')
        : resolved == Match3Mode.obstacle
            ? parseGoals('iceCollect')
            : <CollectGoal>[];

    return Match3Objective(
      mode: resolved,
      rows: rows,
      cols: cols,
      steps: intOf('steps', 22),
      seconds: intOf('seconds', 90, ['time_limit']),
      goalScore: intOf('goal', 1200),
      collectTarget: intOf('collect', 20, ['ingredients', 'orders']),
      collectType: intOf('collectType', 0),
      jellyCount: intOf('jelly', 14, ['jelly_layers']),
      iceCount: intOf('ice', 16),
      bossHp: intOf('bossHp', 260),
      collectGoals: goals,
    );
  }

  /// 是否走倒计时（限时模式）
  bool get isTimed => mode == Match3Mode.timed;

  /// 初始化目标层（随机撒果冻 / 冰块）
  void initBoard(Random rng) {
    jelly = List.generate(rows, (_) => List<int>.filled(cols, 0));
    ice = List.generate(rows, (_) => List<int>.filled(cols, 0));
    bossLeft = bossHp;
    for (final g in collectGoals) {
      g.collected = 0;
    }

    if (mode == Match3Mode.clear) {
      _scatter(rng, jellyCount, (r, c) => jelly[r][c] = 1);
    } else if (mode == Match3Mode.obstacle) {
      // 冰块需消除两次，撒在中下部区域（避免顶部补充糖果时视觉突兀）
      _scatter(rng, iceCount, (r, c) => ice[r][c] = 2);
    }
    movesLeft = steps > 0 ? steps : 0;
    movesUsed = 0;
    secondsLeft = seconds.toDouble();
  }

  void _scatter(Random rng, int count, void Function(int, int) mark) {
    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        cells.add((r, c));
      }
    }
    cells.shuffle(rng);
    final n = min(count, cells.length);
    for (var i = 0; i < n; i++) {
      mark(cells[i].$1, cells[i].$2);
    }
  }

  /// 消除回调：按模式累计进度（果冻清除 / 冰块削层 / 收集计数 / Boss 掉血）
  void onCleared(List<ClearedCell> cells) {
    switch (mode) {
      case Match3Mode.clear:
        for (final cell in cells) {
          if (jelly[cell.row][cell.col] > 0) jelly[cell.row][cell.col] = 0;
        }
        break;
      case Match3Mode.obstacle:
        for (final cell in cells) {
          if (ice[cell.row][cell.col] > 0) ice[cell.row][cell.col] -= 1;
          // 破冰模式附加颜色目标（iceCollect）：同步累计
          for (final g in collectGoals) {
            if (cell.type == g.type && g.collected < g.count) g.collected++;
          }
        }
        break;
      case Match3Mode.collect:
        for (final cell in cells) {
          for (final g in collectGoals) {
            if (cell.type == g.type && g.collected < g.count) g.collected++;
          }
        }
        break;
      case Match3Mode.boss:
        for (final cell in cells) {
          bossLeft -= cell.special ? 2 : 1;
        }
        if (bossLeft < 0) bossLeft = 0;
        break;
      case Match3Mode.score:
      case Match3Mode.timed:
        break;
    }
  }

  /// 剩余果冻格数
  int get jellyLeft {
    var n = 0;
    for (final row in jelly) {
      for (final v in row) {
        if (v > 0) n++;
      }
    }
    return n;
  }

  /// 剩余冰封格数（含已裂开）
  int get iceLeft {
    var n = 0;
    for (final row in ice) {
      for (final v in row) {
        if (v > 0) n++;
      }
    }
    return n;
  }

  /// 目标是否已达成（达成即可立即通关，无需耗尽步数）
  bool get achieved {
    switch (mode) {
      case Match3Mode.score:
      case Match3Mode.timed:
        return score >= goalScore;
      case Match3Mode.clear:
        return jellyLeft == 0;
      case Match3Mode.collect:
        // 多目标：全部满足才通关；无配置目标时退回旧单值口径
        return collectGoals.isNotEmpty
            ? collectGoals.every((g) => g.done)
            : collected >= collectTarget;
      case Match3Mode.obstacle:
        // 冰块全碎 + 附加颜色目标（若有）全部满足
        if (iceLeft > 0) return false;
        return collectGoals.isEmpty || collectGoals.every((g) => g.done);
      case Match3Mode.boss:
        return bossLeft <= 0;
    }
  }

  /// 资源是否耗尽（步数用尽 / 倒计时归零）。
  /// steps<=0 = 不限步数（前置关卡），永不因步数判负。
  bool get exhausted =>
      isTimed ? secondsLeft <= 0 : (steps > 0 && movesLeft <= 0);

  /// 秒 → mm:ss（时间展示统一格式）
  static String fmtClock(num seconds) {
    final s = seconds.ceil();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// HUD 指标（按模式给最关键项；steps<=0 不限步时不展示步数项）
  List<ObjectiveStat> stats() {
    // 只渲染本关实际生效的条件项：steps<=0（不限步）时不渲染步数项；
    // 限时渲染剩余时间。无关条件数据一律不展示（2026-09-07）。
    final movesAlert = !isTimed && steps > 0 && movesLeft <= 3;
    final timeAlert = isTimed && secondsLeft <= 10;
    // 语义色：得分琥珀 / 步数蓝 / 时间绿(告急红) / 果冻紫 / 收集绿 / Boss 红
    const scoreColor = Color(0xFFFFB300);
    const movesColor = Color(0xFF64B5F6);
    const timeColor = Color(0xFF66BB6A);
    const jellyColor = Color(0xFFCE93D8);
    const collectColor = Color(0xFF66BB6A);
    const bossColor = Color(0xFFEF5350);
    final ObjectiveStat? moveStat = isTimed
        ? ObjectiveStat('剩余时间', fmtClock(secondsLeft),
            alert: timeAlert, color: timeColor)
        : (steps > 0
            ? ObjectiveStat('剩余步数', '$movesLeft',
                alert: movesAlert, color: movesColor)
            : null);

    switch (mode) {
      case Match3Mode.score:
      case Match3Mode.timed:
        return <ObjectiveStat>[
          ObjectiveStat('得分', '$score', color: scoreColor),
          ObjectiveStat('目标', '$goalScore', color: scoreColor),
          if (moveStat != null) moveStat,
        ];
      case Match3Mode.clear:
        return <ObjectiveStat>[
          ObjectiveStat('剩余果冻', '$jellyLeft', color: jellyColor),
          ObjectiveStat('得分', '$score', color: scoreColor),
          if (moveStat != null) moveStat,
        ];
      case Match3Mode.collect:
        // 收集进度由顶部「目标达成条件」banner 展示（图标×N 实时减少），
        // HUD 侧补充一个合计进度项（绿色 = 收集语义）
        return <ObjectiveStat>[
          ObjectiveStat('已收集', '$collectedTotal', color: collectColor),
          ObjectiveStat('得分', '$score', color: scoreColor),
          if (moveStat != null) moveStat,
        ];
      case Match3Mode.obstacle:
        // 冰块进度由 banner 展示（❄ ×剩余）
        return <ObjectiveStat>[
          ObjectiveStat('剩余冰块', '$iceLeft', color: const Color(0xFF4FC3F7)),
          ObjectiveStat('得分', '$score', color: const Color(0xFFFFB300)),
          if (moveStat != null) moveStat,
        ];
      case Match3Mode.boss:
        return <ObjectiveStat>[
          ObjectiveStat('Boss 血量', '$bossLeft/$bossHp',
              color: const Color(0xFFEF5350)),
          ObjectiveStat('得分', '$score', color: const Color(0xFFFFB300)),
          if (moveStat != null) moveStat,
        ];
    }
  }

  /// 本局通关条件（底部一行，**按本关实际 config 动态生成**，2026-09-10 简化）：
  /// 只展示硬性通关限制（步数/时限 + 目标量），「不限步数」等非限制内容
  /// 不展示；单行短文案防换行。示例：
  /// 「38步内清除36块果冻」「38步内收集黄色×51、蓝色×42」
  /// 「击碎冰块并收集黄色×15」「60s内达成7030分」「39步内击破357血量Boss」。
  String get conditionHint {
    // 目标色中文名（与糖果绘制色板同序）
    const names = <String>['红', '蓝', '绿', '黄', '紫', '橙'];
    // 步数/时限前缀：仅在有硬性限制时展示；不限步不加任何前缀
    final stepText = isTimed
        ? '${seconds}s内'
        : (steps > 0 ? '$steps步内' : '');

    switch (mode) {
      case Match3Mode.score:
      case Match3Mode.timed:
        return '$stepText达成$goalScore分';
      case Match3Mode.clear:
        return '$stepText清除$jellyLeft块果冻';
      case Match3Mode.collect:
        // 多目标：列出各色实际数量（与 collect 数组一一对应）
        if (collectGoals.isEmpty) {
          return '$stepText收集$collectTarget个指定糖果';
        }
        final parts = <String>[
          for (final g in collectGoals)
            '${names[g.type % names.length]}×${g.count}',
        ];
        return '$stepText收集${parts.join('、')}';
      case Match3Mode.obstacle:
        // 冰块（全碎）+ 附加颜色目标（如有）
        final extra = <String>[
          for (final g in collectGoals)
            '${names[g.type % names.length]}×${g.count}',
        ];
        return extra.isEmpty
            ? '$stepText击碎冰块'
            : '${stepText}击碎冰块并收集${extra.join('、')}';
      case Match3Mode.boss:
        return '$stepText击破$bossHp血量Boss';
    }
  }

  /// 兼容旧调用点：返回动态通关条件文案。
  String get hint => conditionHint;
}
