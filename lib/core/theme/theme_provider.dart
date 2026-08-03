import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import '../../features/auth/auth_provider.dart';

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

/// 主题提供者 - 管理主题模式、配色、字体大小
///
/// 按用户隔离：登录用户的设置存储键带业务 userId 后缀（如 theme_mode_U178...），
/// 未登录（游客）使用显式 '_guest' 后缀键，避免与升级前旧版共享键（如 'theme_mode'）
/// 同名导致误读其他账号的历史脏数据。切换账号时由 themeProvider 依赖
/// currentUserIdProvider 自动重建实例并加载对应用户设置，防止跨账号继承。
class ThemeProvider extends ChangeNotifier {
  static const String _themeKeyBase = 'theme_mode';
  static const String _colorSchemeKeyBase = 'color_scheme';
  static const String _fontScaleKeyBase = 'font_scale';
  static const String _uiStyleKeyBase = 'theme_ui_style';
  static const String _useBorderKeyBase = 'theme_use_border';
  static const String _enableShadowKeyBase = 'theme_enable_shadow';

  /// 当前用户业务 ID（null = 未登录/游客）
  final String? _userId;

  /// 存储键加用户后缀：登录用户带业务 userId（如 theme_mode_U178...），
  /// 游客使用显式 '_guest' 后缀，避免与升级前旧版共享键（如 'theme_mode'）同名
  /// 导致误读其他账号的历史脏数据。
  String _key(String base) => _userId == null ? '${base}_guest' : '${base}_$_userId';

  String get _themeKey => _key(_themeKeyBase);
  String get _colorSchemeKey => _key(_colorSchemeKeyBase);
  String get _fontScaleKey => _key(_fontScaleKeyBase);
  String get _uiStyleKey => _key(_uiStyleKeyBase);
  String get _useBorderKey => _key(_useBorderKeyBase);
  String get _enableShadowKey => _key(_enableShadowKeyBase);

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

  // UI 视觉风格
  UiStyle _uiStyle = UiStyle.minimalFlat;
  UiStyle get uiStyle => _uiStyle;

  // 是否显示边框（默认关闭）
  bool _useBorder = false;
  bool get useBorder => _useBorder;

  // 是否开启阴影
  bool _enableShadow = false;
  bool get enableShadow => _enableShadow;

  ThemeProvider({String? userId}) : _userId = userId {
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

    // UI 视觉风格
    final uiStyleIndex = prefs.getInt(_uiStyleKey);
    if (uiStyleIndex != null && uiStyleIndex >= 0 && uiStyleIndex < UiStyle.values.length) {
      _uiStyle = UiStyle.values[uiStyleIndex];
    }

    // 是否显示边框
    final useBorder = prefs.getBool(_useBorderKey);
    if (useBorder != null) {
      _useBorder = useBorder;
    }

    // 是否开启阴影
    final enableShadow = prefs.getBool(_enableShadowKey);
    if (enableShadow != null) {
      _enableShadow = enableShadow;
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

  /// 设置 UI 视觉风格
  Future<void> setUiStyle(UiStyle style) async {
    _uiStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uiStyleKey, style.index);
  }

  /// 设置是否显示边框
  Future<void> setUseBorder(bool value) async {
    _useBorder = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBorderKey, value);
  }

  /// 设置是否开启阴影
  Future<void> setEnableShadow(bool value) async {
    _enableShadow = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableShadowKey, value);
  }
}

/// 主题 Provider（Riverpod）
/// 依赖 currentUserIdProvider：登录/登出/切换账号时自动重建，
/// 加载对应用户的主题/字号设置（防跨账号继承）。
final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ThemeProvider(userId: userId);
});
