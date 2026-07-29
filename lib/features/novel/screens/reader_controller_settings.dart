part of 'reader_controller.dart';

class ReaderSettingsModule {
  final ReaderController _c;
  ReaderSettingsModule(this._c);

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_c._disposed) return;
    _c._setState(() {
      final savedFontSize = prefs.getDouble('reader_font_size') ?? 18;
      _c._fontSizeIndex = ReaderController._fontSizes.indexOf(savedFontSize);
      if (_c._fontSizeIndex < 0) _c._fontSizeIndex = 3;
      final savedLineHeight = prefs.getDouble('reader_line_height') ?? 1.8;
      _c._lineHeightIndex = ReaderController._lineHeights.indexOf(savedLineHeight);
      if (_c._lineHeightIndex < 0) _c._lineHeightIndex = 2;
      final savedBg = prefs.getInt('reader_background') ?? 2;
      _c._background = ReaderBackground.values[savedBg.clamp(0, ReaderBackground.values.length - 1)];
      final savedLastDayBg = prefs.getInt('reader_last_day_background') ?? 2;
      _c._lastDayBackground = ReaderBackground.values[savedLastDayBg.clamp(0, ReaderBackground.values.length - 1)];
      final savedFont = prefs.getInt('reader_font') ?? 0;
      _c._font = ReaderFont.values[savedFont.clamp(0, ReaderFont.values.length - 1)];
      final savedMode = prefs.getInt('reader_page_turn_mode') ?? 0;
      _c._pageTurnMode = PageTurnMode.values[savedMode.clamp(0, PageTurnMode.values.length - 1)];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _c._fontSize);
    await prefs.setDouble('reader_line_height', _c._lineHeight);
    await prefs.setInt('reader_background', _c._background.index);
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
