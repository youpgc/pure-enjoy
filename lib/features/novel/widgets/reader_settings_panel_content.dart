import 'package:flutter/material.dart';
import 'reader_enums.dart';
import 'reader_page_turn.dart';

/// {@template reader_settings_panel_content}
/// [ReaderSettingsPanel] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。各设置项拆为独立子组件。
/// {@endtemplate}
class ReaderSettingsPanelContent extends StatelessWidget {
  /// {@macro reader_settings_panel_content}
  const ReaderSettingsPanelContent({
    super.key,
    required this.fontSize,
    required this.fontSizeIndex,
    required this.fontSizes,
    required this.lineHeight,
    required this.lineHeightIndex,
    required this.lineHeights,
    required this.pageTurnMode,
    required this.font,
    required this.background,
    required this.onFontSizeIndexChanged,
    required this.onLineHeightIndexChanged,
    required this.onPageTurnModeChanged,
    required this.onFontChanged,
    required this.onBackgroundChanged,
    this.onSave,
  });

  final double fontSize;
  final int fontSizeIndex;
  final List<double> fontSizes;
  final double lineHeight;
  final int lineHeightIndex;
  final List<double> lineHeights;
  final PageTurnMode pageTurnMode;
  final ReaderFont font;
  final ReaderBackground background;
  final ValueChanged<int> onFontSizeIndexChanged;
  final ValueChanged<int> onLineHeightIndexChanged;
  final ValueChanged<PageTurnMode> onPageTurnModeChanged;
  final ValueChanged<ReaderFont> onFontChanged;
  final ValueChanged<ReaderBackground> onBackgroundChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('阅读设置', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          ReaderSettingsFontSize(
            fontSize: fontSize,
            fontSizeIndex: fontSizeIndex,
            fontSizes: fontSizes,
            onFontSizeIndexChanged: onFontSizeIndexChanged,
            onSave: onSave,
          ),
          const SizedBox(height: 20),
          ReaderSettingsLineHeight(
            lineHeight: lineHeight,
            lineHeightIndex: lineHeightIndex,
            lineHeights: lineHeights,
            onLineHeightIndexChanged: onLineHeightIndexChanged,
            onSave: onSave,
          ),
          const SizedBox(height: 20),
          const Text('翻页模式'),
          const SizedBox(height: 12),
          ReaderSettingsPageTurn(
            pageTurnMode: pageTurnMode,
            onPageTurnModeChanged: onPageTurnModeChanged,
            onSave: onSave,
          ),
          const SizedBox(height: 20),
          const Text('字体'),
          const SizedBox(height: 12),
          ReaderSettingsFont(
            font: font,
            onFontChanged: onFontChanged,
            onSave: onSave,
          ),
          const SizedBox(height: 20),
          const Text('背景'),
          const SizedBox(height: 12),
          ReaderSettingsBackground(
            background: background,
            onBackgroundChanged: onBackgroundChanged,
            onSave: onSave,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 字体大小调节行
class ReaderSettingsFontSize extends StatelessWidget {
  const ReaderSettingsFontSize({
    super.key,
    required this.fontSize,
    required this.fontSizeIndex,
    required this.fontSizes,
    required this.onFontSizeIndexChanged,
    this.onSave,
  });

  final double fontSize;
  final int fontSizeIndex;
  final List<double> fontSizes;
  final ValueChanged<int> onFontSizeIndexChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('字体大小'),
        const Spacer(),
        IconButton.filledTonal(
          icon: const Text('A-', style: TextStyle(fontSize: 12)),
          onPressed: fontSizeIndex > 0
              ? () {
                  onFontSizeIndexChanged(fontSizeIndex - 1);
                  onSave?.call();
                }
              : null,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${fontSize.toInt()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          icon: const Text('A+', style: TextStyle(fontSize: 16)),
          onPressed: fontSizeIndex < fontSizes.length - 1
              ? () {
                  onFontSizeIndexChanged(fontSizeIndex + 1);
                  onSave?.call();
                }
              : null,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

/// 行高调节行
class ReaderSettingsLineHeight extends StatelessWidget {
  const ReaderSettingsLineHeight({
    super.key,
    required this.lineHeight,
    required this.lineHeightIndex,
    required this.lineHeights,
    required this.onLineHeightIndexChanged,
    this.onSave,
  });

  final double lineHeight;
  final int lineHeightIndex;
  final List<double> lineHeights;
  final ValueChanged<int> onLineHeightIndexChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('行高'),
        const Spacer(),
        IconButton.filledTonal(
          icon: const Icon(Icons.remove),
          onPressed: lineHeightIndex > 0
              ? () {
                  onLineHeightIndexChanged(lineHeightIndex - 1);
                  onSave?.call();
                }
              : null,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            lineHeight.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.add),
          onPressed: lineHeightIndex < lineHeights.length - 1
              ? () {
                  onLineHeightIndexChanged(lineHeightIndex + 1);
                  onSave?.call();
                }
              : null,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }
}

/// 翻页模式选择（Wrap ChoiceChip）
class ReaderSettingsPageTurn extends StatelessWidget {
  const ReaderSettingsPageTurn({
    super.key,
    required this.pageTurnMode,
    required this.onPageTurnModeChanged,
    this.onSave,
  });

  final PageTurnMode pageTurnMode;
  final ValueChanged<PageTurnMode> onPageTurnModeChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: PageTurnMode.values.map((mode) {
        final isSelected = pageTurnMode == mode;
        return ChoiceChip(
          avatar: Icon(mode.icon, size: 18),
          label: Text(mode.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onPageTurnModeChanged(mode);
              onSave?.call();
            }
          },
        );
      }).toList(),
    );
  }
}

/// 字体选择（Wrap ChoiceChip）
class ReaderSettingsFont extends StatelessWidget {
  const ReaderSettingsFont({
    super.key,
    required this.font,
    required this.onFontChanged,
    this.onSave,
  });

  final ReaderFont font;
  final ValueChanged<ReaderFont> onFontChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: ReaderFont.values.map((f) {
        final isSelected = font == f;
        return ChoiceChip(
          label: Text(f.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onFontChanged(f);
              onSave?.call();
            }
          },
        );
      }).toList(),
    );
  }
}

/// 背景主题选择（可点击色块）
class ReaderSettingsBackground extends StatelessWidget {
  const ReaderSettingsBackground({
    super.key,
    required this.background,
    required this.onBackgroundChanged,
    this.onSave,
  });

  final ReaderBackground background;
  final ValueChanged<ReaderBackground> onBackgroundChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ReaderBackground.values.map((bg) {
        final isSelected = background == bg;
        return GestureDetector(
          onTap: () {
            onBackgroundChanged(bg);
            onSave?.call();
          },
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                ),
                child: Center(
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      color: bg.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bg.label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
