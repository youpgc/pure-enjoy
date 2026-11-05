import 'package:flutter/material.dart';

/// 西行·独立画风单一源。
///
/// 「水墨鎏金」基调：深墨底 + 鎏金主色 + 朱砂点睛；游戏内全部页面
/// （hub/关卡/角色/天赋/图鉴/局内）共用本文件 token，禁止散落硬编码色值。
class JourneyTheme {
  JourneyTheme._();

  // ---- 底色体系 ----
  static const Color bgDeep = Color(0xFF16121F);
  static const Color bgBase = Color(0xFF1E1829);
  static const Color panel = Color(0xFF2A2138);
  static const Color panelRaised = Color(0xFF352A48);
  static const Color panelStroke = Color(0xFF4A3B63);

  // ---- 主色 ----
  static const Color gold = Color(0xFFE8C470);
  static const Color goldDeep = Color(0xFFB98F3E);
  static const Color goldSoft = Color(0xFFF6E3B4);
  static const Color cinnabar = Color(0xFFD4593F);
  static const Color jade = Color(0xFF6FBF9A);

  // ---- 文字 ----
  static const Color textPrimary = Color(0xFFF3EAD8);
  static const Color textSecondary = Color(0xFFB7A99A);
  static const Color textFaint = Color(0xFF7E7189);

  // ---- 状态 ----
  static const Color locked = Color(0xFF544B63);
  static const Color success = jade;
  static const Color danger = cinnabar;

  // ---- 品质档（法宝/卡牌通用，低→高）----
  static const List<Color> qualityColors = <Color>[
    Color(0xFF8D8698), // 凡品
    Color(0xFF6FBF9A), // 良品
    Color(0xFF5B9BD5), // 上品
    Color(0xFFE8C470), // 极品
  ];

  // ---- 五行色 ----
  static const Map<String, Color> elementColors = <String, Color>{
    'metal': Color(0xFFE8C470),
    'wood': Color(0xFF6FBF9A),
    'water': Color(0xFF5B9BD5),
    'fire': Color(0xFFD4593F),
    'earth': Color(0xFFB08968),
  };

  static const Map<String, String> elementNames = <String, String>{
    'metal': '金',
    'wood': '木',
    'water': '水',
    'fire': '火',
    'earth': '土',
  };

  // ---- 形状 ----
  static const double radiusPanel = 16;
  static const double radiusCard = 14;
  static const double radiusButton = 12;
  static const double strokeW = 1.0;

  // ---- 字级 ----
  static const TextStyle titleLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const TextStyle body = TextStyle(fontSize: 14, color: textPrimary);
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );
  static const TextStyle faint = TextStyle(fontSize: 11, color: textFaint);

  /// 页面统一底（深墨渐变，全页面共用）
  static BoxDecoration pageDecoration() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[bgDeep, bgBase],
        ),
      );

  /// 面板容器修饰
  static BoxDecoration panelDecoration({Color? color, Color? stroke}) =>
      BoxDecoration(
        color: color ?? panel,
        borderRadius: BorderRadius.circular(radiusPanel),
        border: Border.all(color: stroke ?? panelStroke, width: strokeW),
      );

  /// 金色主按钮修饰
  static BoxDecoration goldButton({bool pressed = false}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pressed
              ? <Color>[goldDeep, goldDeep]
              : <Color>[goldSoft, gold, goldDeep],
        ),
        borderRadius: BorderRadius.circular(radiusButton),
        border: Border.all(color: goldDeep, width: 1),
        boxShadow: pressed
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: goldDeep.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      );
}
