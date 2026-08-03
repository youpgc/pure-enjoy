import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

/// {@template theme_settings_content}
/// [ThemeSettingsScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入的 [ThemeProvider]（tp），不持有状态，按分区拆为 4 个子组件。
/// {@endtemplate}
class ThemeSettingsContent extends StatelessWidget {
  /// {@macro theme_settings_content}
  const ThemeSettingsContent({super.key, required this.tp});

  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个性化设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ThemeModeSection(tp: tp),
          const SizedBox(height: 24),
          ColorSchemeSection(tp: tp),
          const SizedBox(height: 24),
          FontSizeSection(tp: tp),
          const SizedBox(height: 24),
          UiStyleSection(tp: tp),
          const SizedBox(height: 24),
          BorderShadowSection(tp: tp),
          const SizedBox(height: 24),
          ReaderBgSection(tp: tp),
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

/// 主题模式分区
class ThemeModeSection extends StatelessWidget {
  const ThemeModeSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}

/// 配色方案分区
class ColorSchemeSection extends StatelessWidget {
  const ColorSchemeSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 字体大小分区
class FontSizeSection extends StatelessWidget {
  const FontSizeSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
                    ),
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
      ],
    );
  }
}

/// 阅读背景分区
class ReaderBgSection extends StatelessWidget {
  const ReaderBgSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.3),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              color: bg.textColor,
                              fontSize: 16,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// UI 视觉风格分区
class UiStyleSection extends StatelessWidget {
  const UiStyleSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const _SectionTitle(title: 'UI 风格'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                UiStyle.sharpMinimal, // 圆角 4
                UiStyle.minimalFlat, // 圆角 8
                UiStyle.elegantAiry, // 圆角 12
                UiStyle.pillModern, // 圆角 18
              ].map((style) {
                final token = UiStyleToken.of(style);
                final isSelected = tp.uiStyle == style;
                return GestureDetector(
                  onTap: () => tp.setUiStyle(style),
                  child: Container(
                    width: 84,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(token.cardRadius),
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(token.cardRadius),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 14,
                          width: 44,
                          decoration: BoxDecoration(
                            color: cs.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(token.buttonRadius),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          token.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? cs.primary : cs.onSurfaceVariant,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 边框与阴影分区
class BorderShadowSection extends StatelessWidget {
  const BorderShadowSection({super.key, required this.tp});
  final ThemeProvider tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SectionTitle(title: '边框与阴影'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.border_outer),
                title: const Text('显示边框'),
                subtitle: const Text('关闭后卡片仅以背景区分，去掉描边'),
                value: tp.useBorder,
                onChanged: (v) => tp.setUseBorder(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.filter_none),
                title: const Text('开启阴影'),
                subtitle: const Text('卡片悬浮投影，参考经典立体风格'),
                value: tp.enableShadow,
                onChanged: (v) => tp.setEnableShadow(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
