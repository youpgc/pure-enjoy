import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

/// 个性化设置页面
///
/// 提供主题模式、配色方案、字体大小、阅读背景等个性化设置。
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('个性化设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题模式
          const _SectionTitle(title: '主题模式'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  icon: Icons.brightness_auto,
                  title: '跟随系统',
                  selected: tp.themeMode == ThemeMode.system,
                  onTap: () => tp.setThemeMode(ThemeMode.system),
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  icon: Icons.light_mode,
                  title: '浅色模式',
                  selected: tp.themeMode == ThemeMode.light,
                  onTap: () => tp.setThemeMode(ThemeMode.light),
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  icon: Icons.dark_mode,
                  title: '深色模式',
                  selected: tp.themeMode == ThemeMode.dark,
                  onTap: () => tp.setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 配色方案
          const _SectionTitle(title: '配色方案'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppColorScheme.values.map((scheme) {
                  final isSelected = tp.colorScheme == scheme;
                  return GestureDetector(
                    onTap: () => tp.setColorScheme(scheme),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.seedColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: scheme.seedColor, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: scheme.seedColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheme.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? scheme.seedColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 字体大小
          const _SectionTitle(title: '字体大小'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('小'),
                      Text(
                        '${(tp.fontScale * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Text('大'),
                    ],
                  ),
                  Slider(
                    value: tp.fontScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(tp.fontScale * 100).toInt()}%',
                    onChanged: (value) => tp.setFontScale(value),
                  ),
                  // 预览文本
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '预览文本：纯享，记录生活每一天',
                      style: TextStyle(fontSize: 14 * tp.fontScale),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 阅读背景
          const _SectionTitle(title: '阅读背景'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ReaderBackgroundTheme.values.map((bg) {
                  final isSelected = tp.readerBg == bg;
                  return GestureDetector(
                    onTap: () => tp.setReaderBackground(bg),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bg.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: bg.textColor,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bg.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// 分区标题
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// 主题模式选项
class _ThemeModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
