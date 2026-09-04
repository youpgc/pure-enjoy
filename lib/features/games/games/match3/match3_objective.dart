import 'dart:math';

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

/// HUD 展示项
class ObjectiveStat {
  final String label;
  final String value;

  /// 是否告急（剩余步数/时间不足时标红）
  final bool alert;

  const ObjectiveStat(this.label, this.value, {this.alert = false});
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

  /// 已收集数量（collect）
  int collected = 0;

  /// Boss 剩余血量（boss）
  int bossLeft = 0;

  /// 当前分数（由引擎同步）
  int score = 0;

  /// 剩余步数（由引擎同步）
  int movesLeft = 0;

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
    );
  }

  /// 是否走倒计时（限时模式）
  bool get isTimed => mode == Match3Mode.timed;

  /// 初始化目标层（随机撒果冻 / 冰块）
  void initBoard(Random rng) {
    jelly = List.generate(rows, (_) => List<int>.filled(cols, 0));
    ice = List.generate(rows, (_) => List<int>.filled(cols, 0));
    bossLeft = bossHp;
    collected = 0;

    if (mode == Match3Mode.clear) {
      _scatter(rng, jellyCount, (r, c) => jelly[r][c] = 1);
    } else if (mode == Match3Mode.obstacle) {
      // 冰块需消除两次，撒在中下部区域（避免顶部补充糖果时视觉突兀）
      _scatter(rng, iceCount, (r, c) => ice[r][c] = 2);
    }
    movesLeft = steps;
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
        }
        break;
      case Match3Mode.collect:
        for (final cell in cells) {
          if (cell.type == collectType) collected++;
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
        return collected >= collectTarget;
      case Match3Mode.obstacle:
        return iceLeft == 0;
      case Match3Mode.boss:
        return bossLeft <= 0;
    }
  }

  /// 资源是否耗尽（步数用尽 / 倒计时归零）
  bool get exhausted =>
      isTimed ? secondsLeft <= 0 : movesLeft <= 0;

  /// HUD 三项（按模式给最关键的三个指标）
  List<ObjectiveStat> stats() {
    final movesAlert = !isTimed && movesLeft <= 3;
    final timeAlert = isTimed && secondsLeft <= 10;
    final moveStat = isTimed
        ? ObjectiveStat('剩余时间', '${secondsLeft.ceil()}s', alert: timeAlert)
        : ObjectiveStat('剩余步数', '$movesLeft', alert: movesAlert);

    switch (mode) {
      case Match3Mode.score:
      case Match3Mode.timed:
        return <ObjectiveStat>[
          ObjectiveStat('得分', '$score'),
          ObjectiveStat('目标', '$goalScore'),
          moveStat,
        ];
      case Match3Mode.clear:
        return <ObjectiveStat>[
          ObjectiveStat('剩余果冻', '$jellyLeft'),
          ObjectiveStat('得分', '$score'),
          moveStat,
        ];
      case Match3Mode.collect:
        return <ObjectiveStat>[
          ObjectiveStat('已收集', '$collected/$collectTarget'),
          ObjectiveStat('得分', '$score'),
          moveStat,
        ];
      case Match3Mode.obstacle:
        return <ObjectiveStat>[
          ObjectiveStat('剩余冰块', '$iceLeft'),
          ObjectiveStat('得分', '$score'),
          moveStat,
        ];
      case Match3Mode.boss:
        return <ObjectiveStat>[
          ObjectiveStat('Boss 血量', '$bossLeft/$bossHp'),
          ObjectiveStat('得分', '$score'),
          moveStat,
        ];
    }
  }

  /// 本局操作提示（底部一行）
  String get hint {
    switch (mode) {
      case Match3Mode.score:
        return '点选两个相邻糖果交换，三连即消，步数内达到 $goalScore 分';
      case Match3Mode.clear:
        return '在带果冻的格子上消除糖果即可清除果冻，清空全部果冻通关';
      case Match3Mode.collect:
        return '消除指定颜色糖果累计收集，凑满 $collectTarget 个即通关';
      case Match3Mode.obstacle:
        return '冰封格需在其上消除两次才会碎裂，敲碎全部冰块通关';
      case Match3Mode.timed:
        return '倒计时进行中，抓紧制造连锁，$seconds 秒内达到 $goalScore 分';
      case Match3Mode.boss:
        return '每消除 1 个糖果造成 1 点伤害，特殊糖翻倍，打光 Boss 血量通关';
    }
  }
}
