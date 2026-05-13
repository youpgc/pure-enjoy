import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// 主题模式枚举
enum AppThemeMode {
  system('跟随系统'),
  light('浅色模式'),
  dark('深色模式');

  const AppThemeMode(this.label);
  final String label;
}

/// 主题Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const String _key = 'theme_mode';

  ThemeModeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  void _load() {
    final saved = StorageService().getSetting<String>(_key);
    if (saved != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await StorageService().saveSetting(_key, mode.name);
  }
}

/// 将AppThemeMode转换为Flutter的ThemeMode
ThemeMode toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
  }
}
