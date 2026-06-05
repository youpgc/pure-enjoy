import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题配色方案 - 基于Logo的橙黄渐变色系
enum AppColorScheme {
  orange('活力橙', Color(0xFFF26522)),
  yellow('暖阳黄', Color(0xFFFFC107)),
  amber('琥珀金', Color(0xFFFFB300)),
  coral('珊瑚橙', Color(0xFFFF7043)),
  gold('香槟金', Color(0xFFFFD54F)),
  sunset('夕阳橙', Color(0xFFFF8A65)),
  mango('芒果黄', Color(0xFFFFCA28)),
  tangerine('柑橘橙', Color(0xFFFF9800));

  const AppColorScheme(this.label, this.seedColor);
  final String label;
  final Color seedColor;
}

/// 阅读背景主题
enum ReaderBackgroundTheme {
  defaultWhite('默认白', Colors.white, Colors.black87),
  warmYellow('护眼黄', Color(0xFFF5E6C8), Color(0xFF5D4E37)),
  lightGreen('淡绿', Color(0xFFCCE8CF), Color(0xFF2D4A30)),
  lightBlue('淡蓝', Color(0xFFD4E6F1), Color(0xFF2C3E50)),
  lightPink('淡粉', Color(0xFFF5D5D5), Color(0xFF6B3A3A)),
  darkGray('深灰', Color(0xFF2C2C2C), Color(0xFFD0D0D0)),
  pureBlack('纯黑', Color(0xFF000000), Color(0xFFB0B0B0)),
  brown('牛皮纸', Color(0xFFD4B896), Color(0xFF5C4A32));

  const ReaderBackgroundTheme(this.label, this.bgColor, this.textColor);
  final String label;
  final Color bgColor;
  final Color textColor;
}

/// 主题提供者 - 管理主题模式、配色、字体大小、阅读背景
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _colorSchemeKey = 'color_scheme';
  static const String _fontScaleKey = 'font_scale';
  static const String _readerBgKey = 'reader_bg';

  // 主题模式
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 配色方案
  AppColorScheme _colorScheme = AppColorScheme.orange;
  AppColorScheme get colorScheme => _colorScheme;

  // 字体缩放 (0.8 ~ 1.4)
  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  // 阅读背景
  ReaderBackgroundTheme _readerBg = ReaderBackgroundTheme.defaultWhite;
  ReaderBackgroundTheme get readerBg => _readerBg;

  ThemeProvider() {
    _loadSettings();
  }

  /// 加载所有设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 主题模式
    final themeString = prefs.getString(_themeKey);
    if (themeString != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == themeString,
        orElse: () => ThemeMode.system,
      );
    }

    // 配色方案
    final schemeIndex = prefs.getInt(_colorSchemeKey);
    if (schemeIndex != null && schemeIndex >= 0 && schemeIndex < AppColorScheme.values.length) {
      _colorScheme = AppColorScheme.values[schemeIndex];
    }

    // 字体缩放
    final scale = prefs.getDouble(_fontScaleKey);
    if (scale != null && scale >= 0.8 && scale <= 1.4) {
      _fontScale = scale;
    }

    // 阅读背景
    final bgIndex = prefs.getInt(_readerBgKey);
    if (bgIndex != null && bgIndex >= 0 && bgIndex < ReaderBackgroundTheme.values.length) {
      _readerBg = ReaderBackgroundTheme.values[bgIndex];
    }

    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// 设置跟随系统
  Future<void> setSystemTheme() async {
    await setThemeMode(ThemeMode.system);
  }

  /// 设置配色方案
  Future<void> setColorScheme(AppColorScheme scheme) async {
    _colorScheme = scheme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSchemeKey, scheme.index);
  }

  /// 设置字体缩放
  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, _fontScale);
  }

  /// 设置阅读背景
  Future<void> setReaderBackground(ReaderBackgroundTheme bg) async {
    _readerBg = bg;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readerBgKey, bg.index);
  }
}
