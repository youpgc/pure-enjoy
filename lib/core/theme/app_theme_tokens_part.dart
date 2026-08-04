part of './app_theme.dart';

/// UI 视觉风格维度（与配色方案正交，仅改形状/边框/密度，不动语义色）
enum UiStyle {
  minimalFlat, // 简约扁平（默认）
  sharpMinimal, // 锐利极简
  pillModern, // 胶囊现代
  elegantAiry, // 优雅留白
}

/// 各 UI 风格的视觉 token（半径/边框/密度）
class UiStyleToken {
  final double cardRadius;
  final double inputRadius;
  final double buttonRadius;
  final double dialogRadius;
  final double sheetRadius;
  final double borderWidth;
  final VisualDensity visualDensity;
  final String label;

  const UiStyleToken({
    required this.cardRadius,
    required this.inputRadius,
    required this.buttonRadius,
    required this.dialogRadius,
    required this.sheetRadius,
    required this.borderWidth,
    required this.visualDensity,
    required this.label,
  });

  static const Map<UiStyle, UiStyleToken> tokens = {
    UiStyle.minimalFlat: UiStyleToken(
      cardRadius: 8,
      inputRadius: 8,
      buttonRadius: 8,
      dialogRadius: 16,
      sheetRadius: 24,
      borderWidth: 1,
      visualDensity: VisualDensity(horizontal: -0.5, vertical: -0.5),
      label: '简约扁平',
    ),
    UiStyle.sharpMinimal: UiStyleToken(
      cardRadius: 4,
      inputRadius: 4,
      buttonRadius: 4,
      dialogRadius: 8,
      sheetRadius: 16,
      borderWidth: 1,
      visualDensity: VisualDensity(horizontal: -0.5, vertical: -0.5),
      label: '锐利极简',
    ),
    UiStyle.pillModern: UiStyleToken(
      cardRadius: 18,
      inputRadius: 999,
      buttonRadius: 999,
      dialogRadius: 24,
      sheetRadius: 24,
      borderWidth: 1,
      visualDensity: VisualDensity.standard,
      label: '胶囊现代',
    ),
    UiStyle.elegantAiry: UiStyleToken(
      cardRadius: 12,
      inputRadius: 12,
      buttonRadius: 12,
      dialogRadius: 20,
      sheetRadius: 24,
      borderWidth: 1,
      visualDensity: VisualDensity(horizontal: 0.5, vertical: 0.5),
      label: '优雅留白',
    ),
  };

  static UiStyleToken of(UiStyle style) => tokens[style]!;
}

/// 将当前 UI 风格注入 Flutter ThemeData，供任意 widget 通过 [AppTheme.uiStyleOf]
/// 读取，从而让装饰卡等硬编码圆角也能跟随风格切换（无需把 widget 改成 ConsumerWidget）。
class UiStyleTheme extends ThemeExtension<UiStyleTheme> {
  final UiStyle uiStyle;
  const UiStyleTheme(this.uiStyle);

  @override
  UiStyleTheme copyWith({UiStyle? uiStyle}) =>
      UiStyleTheme(uiStyle ?? this.uiStyle);

  @override
  UiStyleTheme lerp(ThemeExtension<UiStyleTheme>? other, double t) {
    if (other is! UiStyleTheme) return this;
    return UiStyleTheme(other.uiStyle);
  }
}

/// 主题级开关扩展，供任意 widget 读取（与 UiStyleTheme 同理，避免装饰卡/彩色卡耦合 Riverpod）。
/// 承载全局开关：useBorder（显示边框）、enableShadow（开启阴影），
/// 使全局 cardTheme 之外的彩色 Card 也能跟随这两个开关。
class _BorderFlags extends ThemeExtension<_BorderFlags> {
  final bool useBorder;
  final bool enableShadow;
  const _BorderFlags({required this.useBorder, required this.enableShadow});

  @override
  _BorderFlags copyWith({bool? useBorder, bool? enableShadow}) => _BorderFlags(
        useBorder: useBorder ?? this.useBorder,
        enableShadow: enableShadow ?? this.enableShadow,
      );

  @override
  _BorderFlags lerp(_BorderFlags? other, double t) => other ?? this;
}
