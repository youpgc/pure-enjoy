import 'package:flutter/material.dart';

/// 小说封面组件
///
/// 当封面 URL 为空或加载失败时，使用基于书名的稳定随机背景色 + 书名展示。
/// 颜色从预定义的高级感色板中按书名 hash 选取，确保同一本书始终显示相同颜色。
class NovelCover extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final double width;
  final double height;
  final double borderRadius;

  const NovelCover({
    super.key,
    this.coverUrl,
    required this.title,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  /// 预定义的高级感色板（渐变起始色）
  static const List<Color> _gradientStarts = [
    Color(0xFF667eea), // 紫蓝
    Color(0xFFf093fb), // 粉紫
    Color(0xFF4facfe), // 天蓝
    Color(0xFF43e97b), // 翠绿
    Color(0xFFfa709a), // 桃红
    Color(0xFFfee140), // 金黄
    Color(0xFF30cfd0), // 青绿
    Color(0xFFa8edea), // 薄荷
    Color(0xFFff9a9e), // 珊瑚
    Color(0xFFfbc2eb), // 淡紫
    Color(0xFF8fd3f4), // 浅蓝
    Color(0xFF84fab0), // 浅绿
  ];

  static const List<Color> _gradientEnds = [
    Color(0xFF764ba2), // 深紫
    Color(0xFFf5576c), // 玫红
    Color(0xFF00f2fe), // 亮青
    Color(0xFF38f9d7), // 浅翠
    Color(0xFFfee140), // 暖黄
    Color(0xFFfa709a), // 桃红
    Color(0xFF330867), // 深蓝紫
    Color(0xFFfed6e3), // 粉白
    Color(0xFFfecfef), // 浅粉
    Color(0xFFa18cd1), // 紫罗兰
    Color(0xFF84fab0), // 薄荷绿
    Color(0xFF8fd3f4), // 天蓝
  ];

  /// 根据字符串生成稳定的 hash 值
  int _hash(String s) {
    var h = 0;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) - h + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return h;
  }

  /// 获取基于书名的稳定渐变色
  (Color start, Color end) _getGradientColors() {
    final idx = _hash(title).abs() % _gradientStarts.length;
    return (_gradientStarts[idx], _gradientEnds[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final (startColor, endColor) = _getGradientColors();

    final placeholder = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              title.isNotEmpty ? title : '未知',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black26,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (coverUrl == null || coverUrl!.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          coverUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder;
          },
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}
