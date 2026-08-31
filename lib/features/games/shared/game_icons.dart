import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 自绘卡通图标集（矢量 SVG，无位图资源、无版权）。
///
/// - [fruits]：羊了个羊方块图标（水果主题，柔和卡通配色）。
/// - [candies]：消消乐糖块图标（6 种不同形状+颜色，便于辨识）。
/// 均带白色高光，配合 [tile] 的圆角卡片背景使用。
class GameIcons {
  GameIcons._();

  /// 羊了个羊图块：10 款卡通水果（按索引取，超出循环）
  static const List<String> fruits = <String>[
    // 苹果
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 22 C42 10 24 12 24 32 C14 46 18 66 32 76 C42 84 58 84 68 76 C82 66 86 46 76 32 C76 12 58 10 50 22 Z" fill="#EF5350"/>'
        '<path d="M50 22 C49 14 52 9 60 7" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '<ellipse cx="38" cy="42" rx="7" ry="11" fill="#FFFFFF" opacity="0.35"/>'
        '</svg>',
    // 橙子
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="54" r="32" fill="#FFA726"/>'
        '<path d="M50 24 C50 16 56 12 64 12" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '<ellipse cx="40" cy="46" rx="7" ry="10" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 葡萄
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<g fill="#AB47BC">'
        '<circle cx="50" cy="34" r="10"/><circle cx="38" cy="46" r="10"/><circle cx="62" cy="46" r="10"/>'
        '<circle cx="44" cy="60" r="10"/><circle cx="56" cy="60" r="10"/><circle cx="50" cy="74" r="10"/>'
        '</g>'
        '<path d="M50 24 C50 16 54 12 62 10" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '</svg>',
    // 西瓜（绿皮条纹）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="52" r="32" fill="#66BB6A"/>'
        '<path d="M50 20 A32 32 0 0 1 82 52" stroke="#2E7D32" stroke-width="5" fill="none"/>'
        '<path d="M50 20 A32 32 0 0 0 18 52" stroke="#2E7D32" stroke-width="5" fill="none"/>'
        '<ellipse cx="40" cy="44" rx="6" ry="9" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 柠檬
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<ellipse cx="50" cy="52" rx="34" ry="24" fill="#FFEE58"/>'
        '<ellipse cx="38" cy="46" rx="6" ry="9" fill="#FFFFFF" opacity="0.35"/>'
        '</svg>',
    // 草莓
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M30 40 C30 30 70 30 70 40 C70 66 58 80 50 82 C42 80 30 66 30 40 Z" fill="#EF5350"/>'
        '<path d="M34 38 L50 30 L66 38 L58 44 L50 38 L42 44 Z" fill="#66BB6A"/>'
        '<g fill="#FFFFFF"><circle cx="44" cy="52" r="2.5"/><circle cx="56" cy="52" r="2.5"/>'
        '<circle cx="50" cy="62" r="2.5"/><circle cx="40" cy="62" r="2.5"/><circle cx="60" cy="62" r="2.5"/></g>'
        '</svg>',
    // 桃子
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 22 C30 22 22 40 30 58 C36 74 46 80 50 80 C54 80 64 74 70 58 C78 40 70 22 50 22 Z" fill="#FF8A80"/>'
        '<path d="M50 24 C48 40 48 60 50 78" stroke="#FF5252" stroke-width="3" fill="none" opacity="0.5"/>'
        '<path d="M50 24 C50 16 56 12 64 12" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '<ellipse cx="40" cy="42" rx="6" ry="9" fill="#FFFFFF" opacity="0.35"/>'
        '</svg>',
    // 樱桃
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 30 C50 20 44 16 36 18" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '<path d="M50 30 C52 22 60 20 66 24" stroke="#7CB342" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '<circle cx="38" cy="64" r="16" fill="#C62828"/><circle cx="64" cy="66" r="16" fill="#C62828"/>'
        '<ellipse cx="32" cy="58" rx="5" ry="7" fill="#FFFFFF" opacity="0.35"/>'
        '<ellipse cx="58" cy="60" rx="5" ry="7" fill="#FFFFFF" opacity="0.35"/>'
        '</svg>',
    // 蓝莓
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="54" r="30" fill="#5C6BC0"/>'
        '<path d="M40 32 L50 26 L60 32 L56 40 L50 34 L44 40 Z" fill="#9FA8DA"/>'
        '<ellipse cx="40" cy="46" rx="6" ry="9" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 香蕉
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M28 36 C30 64 50 78 74 70 C66 76 40 70 34 46 C32 38 30 34 28 36 Z" fill="#FFD54F"/>'
        '<path d="M28 36 C30 32 36 30 40 32" stroke="#8D6E63" stroke-width="4" fill="none" stroke-linecap="round"/>'
        '</svg>',
  ];

  /// 消消乐糖块：6 种不同形状+颜色
  static const List<String> candies = <String>[
    // 圆形（红）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="50" r="30" fill="#EF5350"/>'
        '<ellipse cx="40" cy="40" rx="8" ry="12" fill="#FFFFFF" opacity="0.4"/>'
        '<circle cx="50" cy="50" r="30" fill="none" stroke="#FFFFFF" stroke-width="3" opacity="0.5"/>'
        '</svg>',
    // 圆角方块（蓝）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<rect x="22" y="22" width="56" height="56" rx="14" fill="#42A5F5"/>'
        '<rect x="30" y="30" width="20" height="20" rx="6" fill="#FFFFFF" opacity="0.35"/>'
        '</svg>',
    // 三角（绿）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 22 L78 74 L22 74 Z" fill="#66BB6A"/>'
        '<path d="M50 38 L64 66 L36 66 Z" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 六边形（黄）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 20 L76 35 L76 65 L50 80 L24 65 L24 35 Z" fill="#FFCA28"/>'
        '<path d="M50 36 L64 44 L64 56 L50 64 L36 56 L36 44 Z" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 星形（紫）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 18 L60 42 L86 44 L66 62 L72 88 L50 74 L28 88 L34 62 L14 44 L40 42 Z" fill="#AB47BC"/>'
        '<circle cx="46" cy="50" r="8" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
    // 菱形（橙）
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M50 20 L74 50 L50 80 L26 50 Z" fill="#FF7043"/>'
        '<path d="M40 36 L50 28 L60 36 L50 48 Z" fill="#FFFFFF" opacity="0.3"/>'
        '</svg>',
  ];

  /// 取水果图标（按索引循环）
  static String fruit(int index) => fruits[index % fruits.length];

  /// 取糖块图标（按索引循环）
  static String candy(int index) => candies[index % candies.length];

  /// 圆角卡片包裹图标，统一视觉。
  static Widget tile({
    required String svg,
    double size = 48,
    Color? background,
    Border? border,
    double radius = 10,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      padding: const EdgeInsets.all(6),
      child: SvgPicture.string(svg, fit: BoxFit.contain),
    );
  }
}
