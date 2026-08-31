import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 统一卡通图标集（矢量 SVG，无位图资源、无版权）。
///
/// 图标文件由两端共用：
/// - App 端：`assets/games/icons/*.svg`（pubspec 已注册 `assets/games/icons/`）
/// - 管理后台：`public/game-icons/*.svg`（Vite 静态目录，按需引用）
///
/// 风格规范：100×100 viewBox、`#5D4037` 粗描边、白色高光、圆角卡通。
/// 后期若要整体替换，只需用同文件名的新文件覆盖两端目录即可，调用方无需改动。
///
/// - [fruits]：羊了个羊方块图标（牧场主题，10 款）。
/// - [candies]：消消乐糖块图标（6 种不同形状+颜色，便于辨识）。
class GameIcons {
  GameIcons._();

  /// 资源目录（pubspec 注册路径）
  static const String _dir = 'assets/games/icons';

  /// 羊了个羊图块：10 款牧场元素（按索引取，超出循环）
  static const List<String> fruits = <String>[
    '$_dir/sheep_01_lamb.svg',
    '$_dir/sheep_02_chick.svg',
    '$_dir/sheep_03_cow.svg',
    '$_dir/sheep_04_pig.svg',
    '$_dir/sheep_05_egg.svg',
    '$_dir/sheep_06_milk.svg',
    '$_dir/sheep_07_carrot.svg',
    '$_dir/sheep_08_corn.svg',
    '$_dir/sheep_09_hay.svg',
    '$_dir/sheep_10_apple.svg',
  ];

  /// 消消乐糖块：6 种不同形状+颜色（备用，App 端消消乐当前由 Flame 绘制）
  static const List<String> candies = <String>[
    '$_dir/candy_01_cherry.svg',
    '$_dir/candy_02_orange.svg',
    '$_dir/candy_03_lemon.svg',
    '$_dir/candy_04_apple.svg',
    '$_dir/candy_05_blueberry.svg',
    '$_dir/candy_06_grape.svg',
  ];

  /// 取水果图标资源路径（按索引循环）
  static String fruit(int index) => fruits[index % fruits.length];

  /// 取糖块图标资源路径（按索引循环）
  static String candy(int index) => candies[index % candies.length];

  /// 圆角卡片包裹图标，统一视觉（asset 版）。
  static Widget tileAsset({
    required String asset,
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
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }

  /// 圆角卡片包裹内联 SVG 字符串（兼容旧调用）。
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
