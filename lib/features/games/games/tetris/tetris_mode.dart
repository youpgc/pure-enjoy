import 'package:flutter/material.dart';

/// 俄罗斯方块模式（对应 `game_modes.play_kind` 的 4 个 tetris 行为码）。
///
/// 解析顺序与 match3 同范：**优先 play_kind（唯一真相源）**，
/// 回落 config 语义键兜底（合成关/后台配置缺位时仍可玩）。
enum TetrisMode {
  /// 马拉松：消行达标通关，局内逐级加速
  marathon('marathon', 'tetris', '马拉松',
      '消行达标通关，下落速度逐级加快',
      '消满目标行数即可通关；每消 10 行提升 1 级，方块下落随之加快。开局稳住地基、留出长条井，越往后越考验反应。'),

  /// 竞速：消行达标通关，速度恒定比最快
  sprint('sprint', 'tetris_sprint', '竞速',
      '固定速度下最快消行，比拼用时',
      '下落速度全程恒定、不看分数只看用时——消满目标行数越快越好。硬降与提前规划是提速关键，快而不乱才能刷新纪录。'),

  /// 闪电：时限内刷分达标，Frenzy 倍率
  blitz('blitz', 'tetris_blitz', '闪电',
      '倒计时内刷分达标，连消叠加 Frenzy 倍率',
      '在倒计时内拿到目标分数。连续消行会点亮 Frenzy 倍率（最高 ×4），断连立即回落；终局最后 10 秒倍率归 1。多用 4 消和 T 旋拉高倍率。'),

  /// 挑战：限方块数内刷分达标
  challenge('challenge', 'tetris_challenge', '挑战',
      '方块数量有限，耗尽前刷分达标',
      '只能使用限定数量的方块，块数耗尽即结算。每一块都要落到最能产分的位置，4 消与连击是高分核心，宁可靠边整理也不要浪费块数。'),

  /// 挖掘（二期）：预填垃圾行挖穿到地板，比最快
  dig('dig', 'tetris_dig', '挖掘',
      '挖穿底部预填的垃圾行，比拼用时',
      '开局底部埋着带缺口的垃圾行，把它们全部清光即通关。竖向长井直插垃圾层效率最高，缺口位置会左右错开、留意对齐。'),

  /// 生存（二期）：周期顶起垃圾行，消行达标或顶死结算
  survival('survival', 'tetris_survival', '生存',
      '垃圾行周期顶起，消行求生',
      '底部会周期性顶起一行垃圾行，堆到顶部即结束。在顶起间隙里尽快消行达标；倒计时变红意味着下一波即将到来。'),

  /// 每日挑战（二期）：北京日期派生发牌种子，全员当日同序列
  daily('daily', 'tetris_daily', '每日挑战',
      '同日全员同序列，通关拿每日首通奖励',
      '每天的发牌序列由日期决定——所有玩家当天完全一致，次日更换。通关即领每日首通积分；想比对进度，和朋友比同一天的分数最公平。');

  const TetrisMode(this.code, this.playKind, this.label,
      this.summary, this.detail);

  /// 模式编码（game_modes.code）
  final String code;

  /// 引擎行为码（game_modes.play_kind，唯一链接）
  final String playKind;

  /// 中文展示名
  final String label;

  /// 模式一句话简介（说明页兜底；DB game_modes.summary 配置优先）
  final String summary;

  /// 玩法细则（说明页兜底；DB game_modes.guide 配置优先）
  final String detail;

  /// 模式网格展示色（与 [modeColorOf] 同一视觉体系）
  Color get color {
    switch (this) {
      case TetrisMode.marathon:
        return const Color(0xFF3949AB);
      case TetrisMode.sprint:
        return const Color(0xFF00897B);
      case TetrisMode.blitz:
        return const Color(0xFFEF6C00);
      case TetrisMode.challenge:
        return const Color(0xFF8E24AA);
      case TetrisMode.dig:
        return const Color(0xFF6D4C41);
      case TetrisMode.survival:
        return const Color(0xFFB71C1C);
      case TetrisMode.daily:
        return const Color(0xFF2E7D32);
    }
  }

  /// 说明页模式图标键（与 game_modes.icon 同名资产）。
  String get icon => 'mode_$code';
}


/// 按 play_kind 解析模式（唯一真相源优先）；未知返回 null。
TetrisMode? tetrisModeFromPlayKind(String? playKind) {
  for (final m in TetrisMode.values) {
    if (m.playKind == playKind) return m;
  }
  return null;
}

/// 综合解析：优先 play_kind，回落 config 语义键兜底。
///
/// 兜底规则：带 `time_limit` → blitz；带 `max_pieces` → challenge；
/// 带 `dig_rows` → dig；带 `garbage_interval` → survival；
/// 其余（含空 config）→ marathon（默认模式，与 adapter.defaultLevel 一致）。
TetrisMode resolveTetrisMode({
  String? playKind,
  required Map<String, dynamic> config,
}) {
  final fromPk = tetrisModeFromPlayKind(playKind);
  if (fromPk != null) return fromPk;
  if (config['time_limit'] != null || config['timeLimit'] != null) {
    return TetrisMode.blitz;
  }
  if (config['max_pieces'] != null || config['maxPieces'] != null) {
    return TetrisMode.challenge;
  }
  if (config['dig_rows'] != null || config['digRows'] != null) {
    return TetrisMode.dig;
  }
  if (config['garbage_interval'] != null || config['garbageInterval'] != null) {
    return TetrisMode.survival;
  }
  return TetrisMode.marathon;
}
