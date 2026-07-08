import 'package:flutter/material.dart';
import 'reader_enums.dart';
import 'reader_page_turn.dart';

/// 阅读设置面板
///
/// 以底部弹窗形式展示，提供字体大小、行高、翻页模式、字体和背景主题等
/// 阅读偏好设置。所有状态通过参数传入，面板本身不维护任何状态。
class ReaderSettingsPanel extends StatelessWidget {
  /// 当前字体大小
  final double fontSize;

  /// 当前字体大小索引
  final int fontSizeIndex;

  /// 可选的字体大小列表
  final List<double> fontSizes;

  /// 当前行高倍数
  final double lineHeight;

  /// 当前行高索引
  final int lineHeightIndex;

  /// 可选的行高列表
  final List<double> lineHeights;

  /// 当前翻页模式
  final PageTurnMode pageTurnMode;

  /// 当前字体
  final ReaderFont font;

  /// 当前背景主题
  final ReaderBackground background;

  /// 字体大小索引变化回调
  final ValueChanged<int> onFontSizeIndexChanged;

  /// 行高索引变化回调
  final ValueChanged<int> onLineHeightIndexChanged;

  /// 翻页模式变化回调
  final ValueChanged<PageTurnMode> onPageTurnModeChanged;

  /// 字体变化回调
  final ValueChanged<ReaderFont> onFontChanged;

  /// 背景主题变化回调
  final ValueChanged<ReaderBackground> onBackgroundChanged;

  /// 保存设置回调（可选，可由外部在每个 onChanged 后统一调用）
  final VoidCallback? onSave;

  const ReaderSettingsPanel({
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
          // 字体大小
          Row(
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
          ),
          const SizedBox(height: 20),
          // 行高
          Row(
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
          ),
          const SizedBox(height: 20),
          // 翻页模式
          const Text('翻页模式'),
          const SizedBox(height: 12),
          Wrap(
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
          ),
          const SizedBox(height: 20),
          // 字体
          const Text('字体'),
          const SizedBox(height: 12),
          Wrap(
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
          ),
          const SizedBox(height: 20),
          // 背景
          const Text('背景'),
          const SizedBox(height: 12),
          Row(
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
                                color:
                                    Theme.of(context).colorScheme.outlineVariant,
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
