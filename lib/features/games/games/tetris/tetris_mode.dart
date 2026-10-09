import 'package:flutter/material.dart';

/// 俄罗斯方块模式（对应 `game_modes.play_kind` 的 4 个 tetris 行为码）。
///
/// 解析顺序与 match3 同范：**优先 play_kind（唯一真相源）**，
/// 回落 config 语义键兜底（合成关/后台配置缺位时仍可玩）。
enum TetrisMode {
  /// 马拉松：消行达标通关，局内逐级加速
  marathon('marathon', 'tetris', '马拉松'),

  /// 竞速：消行达标通关，速度恒定比最快
  sprint('sprint', 'tetris_sprint', '竞速'),

  /// 闪电：时限内刷分达标，Frenzy 倍率
  blitz('blitz', 'tetris_blitz', '闪电'),

  /// 挑战：限方块数内刷分达标
  challenge('challenge', 'tetris_challenge', '挑战');

  const TetrisMode(this.code, this.playKind, this.label);

  /// 模式编码（game_modes.code）
  final String code;

  /// 引擎行为码（game_modes.play_kind，唯一链接）
  final String playKind;

  /// 中文展示名
  final String label;

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
    }
  }
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
  return TetrisMode.marathon;
}
