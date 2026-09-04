import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 成就图标渲染（元素模板 + 渲染时上色）。
///
/// 资源文件（assets/games/achievements/）只保留「元素模板」，不再为每个成就生成
/// 一份全量着色的 SVG：
/// - `badge_N.svg` / `ach_global_*.svg`：段位徽章与全局成就，固定已上色 SVG，直接引用。
/// - `ach_<el>.svg`：语义元素模板，主色用占位色 `#ICON_MAIN`，渲染时按进阶等级上色。
///
/// 数据库 `game_achievements.icon` 令牌决定渲染：
/// - `badge_N` / `ach_global_*` → 直接使用对应固定 SVG。
/// - `ach_<el>_c<rank>` → 加载元素模板 `ach_<el>.svg`，将 `#ICON_MAIN` 替换为
///   「进阶等级颜色」（青铜→王者 7 色）后显示。同元素、不同等级复用同一 SVG，
///   节省静态资源（170 份全量着色 → 15 元素模板 + 运行时上色）。
class AchievementIcon extends StatelessWidget {
  final String? iconToken;
  final double size;

  const AchievementIcon(this.iconToken, {this.size = 64, super.key});

  /// 成就进阶等级颜色（rank 1..7，浅→深），与 SQL 端 icon_colors.json 保持一致。
  static const Map<int, String> advColors = <int, String>{
    1: '#90caf9',
    2: '#4fc3f7',
    3: '#4dd0e1',
    4: '#81c784',
    5: '#ffd54f',
    6: '#ff8a65',
    7: '#e57373',
  };

  /// 元素模板 SVG 字符串缓存（避免每次重建都重新读取资源）。
  static final Map<String, String> _elementCache = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final String token = iconToken ?? '';
    if (token.startsWith('badge_') || token.startsWith('ach_global_')) {
      return SvgPicture.asset(
        'assets/games/achievements/$token.svg',
        width: size,
        height: size,
      );
    }
    final RegExpMatch? m = RegExp(r'^ach_([a-z0-9]+)_c(\d+)$').firstMatch(token);
    if (m != null) {
      final String el = m.group(1)!;
      final int rank = int.tryParse(m.group(2)!) ?? 1;
      final String color = advColors[rank] ?? advColors[1]!;
      return _ElementColorIcon(el: el, color: color, size: size);
    }
    // 兜底：通用奖杯元素 + 默认等级色。
    return _ElementColorIcon(el: 'trophy', color: advColors[1]!, size: size);
  }
}

/// 加载元素模板并以进阶等级色替换占位色后渲染。
class _ElementColorIcon extends StatefulWidget {
  final String el;
  final String color;
  final double size;

  const _ElementColorIcon({
    required this.el,
    required this.color,
    required this.size,
  });

  @override
  State<_ElementColorIcon> createState() => _ElementColorIconState();
}

class _ElementColorIconState extends State<_ElementColorIcon> {
  String? _svg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String path = 'assets/games/achievements/ach_${widget.el}.svg';
    final String raw =
        AchievementIcon._elementCache[path] ?? await rootBundle.loadString(path);
    AchievementIcon._elementCache[path] = raw;
    if (!mounted) return;
    setState(() {
      _svg = raw.replaceAll('#ICON_MAIN', widget.color);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_svg == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return SvgPicture.string(_svg!, width: widget.size, height: widget.size);
  }
}
