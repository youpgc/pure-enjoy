part of 'reader_controller.dart';

class ReaderSettingsModule {
  final ReaderController _c;
  ReaderSettingsModule(this._c);

  Future<void> _loadSettings() async {
    final ctx = _c._context;
    final prefs = await SharedPreferences.getInstance();
    if (_c._disposed) return;
    _c._setState(() {
      final savedFontSize = prefs.getDouble('reader_font_size') ?? 18;
      _c._fontSizeIndex = ReaderController._fontSizes.indexOf(savedFontSize);
      if (_c._fontSizeIndex < 0) _c._fontSizeIndex = 3;
      final savedLineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      _c._lineHeightIndex = ReaderController._lineHeights.indexOf(savedLineHeight);
      if (_c._lineHeightIndex < 0) _c._lineHeightIndex = 2;
      // 阅读背景统一使用主题模块 readerBg（按用户隔离），与主题设置页保持一致
      final tp = ctx != null
          ? ProviderScope.containerOf(ctx).read(themeProvider)
          : null;
      _c._background = tp?.readerBg ?? ReaderBackground.defaultWhite;
      final savedLastDayBg = prefs.getInt('reader_last_day_background') ?? 0;
      _c._lastDayBackground = ReaderBackground.values[savedLastDayBg.clamp(0, ReaderBackground.values.length - 1)];
      final savedFont = prefs.getInt('reader_font') ?? 0;
      _c._font = ReaderFont.values[savedFont.clamp(0, ReaderFont.values.length - 1)];
      final savedMode = prefs.getInt('reader_page_turn_mode') ?? 0;
      _c._pageTurnMode = PageTurnMode.values[savedMode.clamp(0, PageTurnMode.values.length - 1)];
    });
  }

  Future<void> _saveSettings() async {
    // 在首个 await 前捕获 context，避免跨 async gap 使用 BuildContext 的 lint
    final ctx = _c._context;
    final prefs = await SharedPreferences.getInstance();
    // 阅读背景统一持久化到主题模块（按用户隔离），与主题设置页共用 readerBg
    if (ctx != null) {
      // 仅读取 Provider，非同步 UI 操作，忽略跨 async gap 的启发式 lint
      // ignore: use_build_context_synchronously
      await ProviderScope.containerOf(ctx).read(themeProvider).setReaderBackground(_c._background);
    } else {
      await prefs.setInt('reader_background', _c._background.index);
    }
    await prefs.setDouble('reader_font_size', _c._fontSize);
    await prefs.setDouble('reader_line_height', _c._lineHeight);
    await prefs.setInt('reader_last_day_background', _c._lastDayBackground.index);
    await prefs.setInt('reader_font', _c._font.index);
    await prefs.setInt('reader_page_turn_mode', _c._pageTurnMode.index);
  }

  TextStyle _getCachedTextStyle({bool isTitle = false}) {
    final hash = Object.hash(_c._fontStyleHash, isTitle);
    return ReaderController._textStyleCache.putIfAbsent(hash, () => TextStyle(
      fontSize: isTitle ? _c._fontSize + 4 : _c._fontSize,
      height: isTitle ? 1.6 : _c._lineHeight,
      color: _c._background.textColor,
      letterSpacing: isTitle ? 0 : 0.5,
      fontFamily: _c._font.fontFamily == 'system' ? null : _c._font.fontFamily,
      fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
    ));
  }
}
