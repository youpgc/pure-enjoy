import 'package:flutter/material.dart';

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

/// 应用主题配置 - 基于logo的橙黄配色方案
class AppTheme {
  /// 从 ThemeData 读取当前 UI 风格（由 main 注入），装饰卡据此跟随风格切换圆角。
  static UiStyle uiStyleOf(BuildContext context) {
    final ext = Theme.of(context).extension<UiStyleTheme>();
    return ext?.uiStyle ?? UiStyle.minimalFlat;
  }

  /// 由模块内容背景色派生边框色：保持色相，沿明度偏移一个档位，
  /// 浅底→更深边、深底→更浅边，使边框与内容背景形成明显对比，
  /// 且同色系更和谐（替代原本与主题冷调冲突的纯灰 outline）。
  static Color surfaceBorder(Color surface) {
    final hsl = HSLColor.fromColor(surface);
    const double step = 0.28; // 一个明度档（亮底→更深边/深底→更浅边，制造明显对比）
    final double newL = hsl.lightness > 0.5
        ? (hsl.lightness - step).clamp(0.0, 1.0)
        : (hsl.lightness + step).clamp(0.0, 1.0);
    return hsl.withLightness(newL).toColor();
  }

  /// 由某张卡片的「实际背景色」派生其边框线（保留色相、压暗一档），
  /// 并遵循全局「显示边框」开关。供所有非默认背景色的 Card 复用，
  /// 解决全局 cardTheme 边框只认单一基准色、导致彩色卡片边框与背景不匹配的问题。
  static BorderSide cardBorderSide(BuildContext context, Color background) {
    final flags = Theme.of(context).extension<_BorderFlags>() ??
        const _BorderFlags(useBorder: true, enableShadow: false);
    if (!flags.useBorder) return BorderSide.none;
    return BorderSide(
      color: surfaceBorder(background),
      width: UiStyleToken.of(uiStyleOf(context)).borderWidth,
    );
  }

  /// 由某张卡片的「实际背景色」派生阴影色：保留色相、压暗一档并降低不透明度，
  /// 使投影与卡片内容背景同色系（替代中性灰投影），呼应「阴影随内容背景色展示」。
  static Color cardShadowColor(Color background) {
    final hsl = HSLColor.fromColor(background);
    const double step = 0.35; // 压暗一档
    final double newL = (hsl.lightness - step).clamp(0.0, 1.0);
    return hsl.withLightness(newL).toColor().withValues(alpha: 0.35);
  }

  /// 由全局「开启阴影」开关决定彩色 Card 的 elevation（2/0）。
  /// 供非默认背景色的彩色 Card 复用，使其与全局 cardTheme 行为一致：
  /// 默认关闭阴影时不显示投影，避免彩色卡恒带阴影而违背「默认不开启阴影」。
  static double cardElevation(BuildContext context) {
    final flags = Theme.of(context).extension<_BorderFlags>() ??
        const _BorderFlags(useBorder: true, enableShadow: false);
    return flags.enableShadow ? 2 : 0;
  }

  /// 字体缩放感知的网格宽高比。
  /// 字体放大（textScale>1）时降低 ratio 以抬高单元格高度，避免卡片内文字溢出；
  /// 用 clamp 限制范围，避免比例过扁/过竖导致布局变形。
  static double gridAspectRatio(BuildContext context, double base) {
    final scale = MediaQuery.of(context).textScaler.scale(1);
    return (base / scale).clamp(base * 0.7, base * 1.2);
  }

  // ===== Logo 主色调 =====
  static const Color primaryOrange = Color(0xFFF26522);   // 深橙色
  static const Color primaryYellow = Color(0xFFFFC107);   // 暖黄色
  static const Color warmWhite = Color(0xFFFFF8F0);       // 暖白色（背景）

  // ===== 派生色板 =====
  static const Color primaryLight = Color(0xFFFFA726);    // 浅橙色
  static const Color primaryDark = Color(0xFFE65100);     // 深橙色（强调）
  static const Color secondaryColor = Color(0xFFFFB300);  // 琥珀色
  static const Color accentColor = Color(0xFFFFD54F);     // 浅黄色（点缀）

  // ===== 语义色 =====
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // ===== 中性色 =====
  static const Color neutral100 = Color(0xFFFFFFFF);
  static const Color neutral200 = Color(0xFFF5F5F5);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF9E9E9E);
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral700 = Color(0xFF616161);
  static const Color neutral800 = Color(0xFF424242);
  static const Color neutral900 = Color(0xFF212121);

  /// 根据配色方案生成浅色主题
  static ThemeData lightTheme(
    Color seedColor,
    UiStyle uiStyle, {
    bool useBorder = true,
    bool enableShadow = false,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      primary: primaryOrange,
      secondary: primaryYellow,
      tertiary: secondaryColor,
      surface: warmWhite,
      surfaceContainerHighest: neutral200,
      error: error,
      onPrimary: Colors.white,
      onSecondary: neutral900,
      onSurface: neutral900,
      onSurfaceVariant: neutral600,
      onError: Colors.white,
      outline: neutral400,
      shadow: neutral900.withValues(alpha: 0.1),
    );
    return _buildTheme(colorScheme, uiStyle, useBorder, enableShadow);
  }

  /// 根据配色方案生成深色主题
  static ThemeData darkTheme(
    Color seedColor,
    UiStyle uiStyle, {
    bool useBorder = true,
    bool enableShadow = false,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      primary: primaryLight,
      secondary: accentColor,
      tertiary: secondaryColor,
      surface: neutral900,
      surfaceContainerHighest: neutral800,
      error: const Color(0xFFEF5350),
      onPrimary: neutral900,
      onSecondary: neutral900,
      onSurface: neutral200,
      onSurfaceVariant: neutral400,
      onError: Colors.white,
      outline: neutral600,
      shadow: Colors.black.withValues(alpha: 0.3),
    );
    return _buildTheme(colorScheme, uiStyle, useBorder, enableShadow);
  }

  /// 统一构建主题
  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    UiStyle uiStyle,
    bool useBorder,
    bool enableShadow,
  ) {
    final token = UiStyleToken.of(uiStyle);
    final Color borderColor = surfaceBorder(colorScheme.surfaceContainerHighest);
    final BorderSide borderSide = useBorder
        ? BorderSide(color: borderColor, width: token.borderWidth)
        : BorderSide.none;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: token.visualDensity,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: enableShadow ? 2 : 0,
        shadowColor: cardShadowColor(colorScheme.surfaceContainerHighest),
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(token.cardRadius),
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(token.inputRadius),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(token.inputRadius),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(token.inputRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(token.inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(token.inputRadius),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(token.buttonRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(token.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(token.buttonRadius),
          ),
          side: borderSide,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(token.buttonRadius),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(token.dialogRadius),
        ),
        backgroundColor: colorScheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(token.sheetRadius)),
        ),
        backgroundColor: colorScheme.surface,
      ),
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        space: 1,
        color: colorScheme.outline.withValues(alpha: 0.5),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(token.buttonRadius),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(token.cardRadius),
        ),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: colorScheme.primary, fontSize: 12);
          }
          return TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerColor: colorScheme.outline.withValues(alpha: 0.3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      extensions: <ThemeExtension<dynamic>>[
        UiStyleTheme(uiStyle),
        _BorderFlags(useBorder: useBorder, enableShadow: enableShadow),
      ],
    );
  }
}
