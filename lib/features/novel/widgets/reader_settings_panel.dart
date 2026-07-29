import 'package:flutter/material.dart';
import 'reader_enums.dart';
import 'reader_page_turn.dart';
import 'reader_settings_panel_content.dart';

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
    return ReaderSettingsPanelContent(
      fontSize: fontSize,
      fontSizeIndex: fontSizeIndex,
      fontSizes: fontSizes,
      lineHeight: lineHeight,
      lineHeightIndex: lineHeightIndex,
      lineHeights: lineHeights,
      pageTurnMode: pageTurnMode,
      font: font,
      background: background,
      onFontSizeIndexChanged: onFontSizeIndexChanged,
      onLineHeightIndexChanged: onLineHeightIndexChanged,
      onPageTurnModeChanged: onPageTurnModeChanged,
      onFontChanged: onFontChanged,
      onBackgroundChanged: onBackgroundChanged,
      onSave: onSave,
    );
  }
}
