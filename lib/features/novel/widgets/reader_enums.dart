import '../../../core/theme/theme_provider.dart';

/// 阅读器背景主题枚举（复用主题模块的 ReaderBackgroundTheme，确保主题设置页的背景选择生效）
typedef ReaderBackground = ReaderBackgroundTheme;

/// 阅读器字体选择枚举
enum ReaderFont {
  system('系统默认', 'system'),
  serif('宋体', 'serif'),
  sansSerif('黑体', 'sans-serif'),
  monospace('等宽', 'monospace');

  const ReaderFont(this.label, this.fontFamily);
  final String label;
  final String fontFamily;
}
