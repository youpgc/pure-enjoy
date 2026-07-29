import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import './theme_settings_screen_content.dart';

/// 个性化设置页面
///
/// 提供主题模式、配色方案、字体大小、阅读背景等个性化设置。
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = ref.watch(themeProvider);
    return ThemeSettingsContent(tp: tp);
  }
}
