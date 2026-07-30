part of 'reader_controller.dart';

class ReaderUiModule {
  final ReaderController _c;
  ReaderUiModule(this._c);

  Widget _buildBottomStatusBar() {
    return ReaderBottomStatusBar(
      background: _c._background,
      chaptersNotEmpty: _c._chapters.isNotEmpty,
      readingProgress: _c.meta._readingProgress,
      currentTime: _c.meta._currentTime,
      batteryLevel: _c._batteryLevel,
    );
  }

  void _toggleMenu() {
    _c._setState(() => _c._showMenu = !_c._showMenu);
    if (_c._showMenu) {
      _c._toolbarAnimationController.forward();
      // 保持沉浸式模式，避免状态栏显示导致内容偏移
      // 工具栏使用 SafeArea 自动适配状态栏高度
    } else {
      _c._toolbarAnimationController.reverse();
    }
  }

  Widget _buildTopStatusBar(BuildContext context) {
    return ReaderTopStatusBar(
      background: _c._background,
      currentChapter: _c._currentChapter,
      novelTitle: _c.novel.title,
      onBack: () async {
        await _c.progress._saveProgress();
        if (!_c._disposed) Navigator.pop(context); // ignore: use_build_context_synchronously
      },
    );
  }

  Widget _buildTopMenu(BuildContext context) {
    return ReaderTopMenu(
      fadeAnimation: _c._toolbarFadeAnimation,
      slideAnimation: _c._topToolbarSlideAnimation,
      background: _c._background,
      novel: _c.novel,
      currentChapter: _c._currentChapter,
      currentChapterIndex: _c._currentChapterIndex,
      chapterCount: _c.meta._totalChapterCount,
      hasStartedReading: _c._hasStartedReading,
      currentReadingDuration: _c.progress._currentReadingDuration,
      isCollected: _c._isCollected,
      onBack: () => Navigator.pop(context),
      onToggleCollection: _c.progress._toggleCollection,
      onShowTtsPanel: () => showReaderTtsPanel(
        context,
        isPlaying: _c._isTtsPlaying,
        onPlayStateChanged: (playing) => _c._setState(() => _c._isTtsPlaying = playing),
        novelId: _c.novel.id,
        chapterId: _c._currentChapter?.id ?? '',
        chapterContent: _c._currentChapter?.content ?? '',
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    return ReaderBottomToolbar(
      fadeAnimation: _c._toolbarFadeAnimation,
      slideAnimation: _c._bottomToolbarSlideAnimation,
      background: _c._background,
      currentChapterIndex: _c._currentChapterIndex,
      chapterCount: _c.meta._totalChapterCount,
      onPreviousChapter: _c.navigation._previousChapter,
      onNextChapter: _c.navigation._nextChapter,
      onOpenDrawer: () => _c._scaffoldKey.currentState?.openDrawer(),
      onShowBookmarkList: () => showReaderBookmarkList(
        context,
        bookmarks: _c._bookmarks,
        currentChapter: _c._currentChapter,
        onBookmarkTap: _c.annotations._jumpToBookmark,
      ),
      onShowAnnotationList: () => showReaderAnnotationList(
        context,
        annotations: _c._annotations,
        onDelete: _c.annotations._deleteAnnotation,
      ),
      onShowSettings: _showSettings,
      onToggleDayNight: () {
        _c._setState(() {
          if (_c._background == ReaderBackground.pureBlack) {
            _c._background = _c._lastDayBackground;
          } else {
            _c._lastDayBackground = _c._background;
            _c._background = ReaderBackground.pureBlack;
          }
        });
        _c.settings._saveSettings();
      },
    );
  }

  void _showSettings() {
    final ctx = _c._context;
    if (ctx == null) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ReaderSettingsPanel(
          fontSize: _c._fontSize,
          fontSizeIndex: _c._fontSizeIndex,
          fontSizes: ReaderController._fontSizes,
          lineHeight: _c._lineHeight,
          lineHeightIndex: _c._lineHeightIndex,
          lineHeights: ReaderController._lineHeights,
          pageTurnMode: _c._pageTurnMode,
          font: _c._font,
          background: _c._background,
          onFontSizeIndexChanged: (index) {
            setModalState(() => _c._fontSizeIndex = index);
            _c._setState(() {});
          },
          onLineHeightIndexChanged: (index) {
            setModalState(() => _c._lineHeightIndex = index);
            _c._setState(() {});
          },
          onPageTurnModeChanged: (mode) {
            setModalState(() => _c._pageTurnMode = mode);
            _c._setState(() {});
          },
          onFontChanged: (font) {
            setModalState(() => _c._font = font);
            _c._setState(() {});
          },
          onBackgroundChanged: (bg) {
            setModalState(() => _c._background = bg);
            _c._setState(() {});
            if (bg != ReaderBackground.pureBlack) {
              _c._lastDayBackground = bg;
            }
          },
          onSave: _c.settings._saveSettings,
        ),
      ),
    );
  }

  void _handleScreenTap(TapUpDetails details) {
    final ctx = _c._context;
    if (ctx == null) return;
    final width = MediaQuery.of(ctx).size.width;
    final dx = details.globalPosition.dx;

    if (_c._pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式下点击任意位置唤起/关闭菜单
      _toggleMenu();
      return;
    }

    // 分页模式
    if (dx < width * 0.3) {
      // 左侧区域
      if (_c._currentPageIndex <= 0) {
        // 第一页，跳转上一章
        _c.navigation._previousChapter();
      } else {
        // 上一页
        _c._pagedContentKey.currentState?.previousPage();
        _c._curlContentKey.currentState?.previousPage();
      }
    } else if (dx > width * 0.7) {
      // 右侧区域
      if (_c._currentPageIndex >= _c._totalPages - 1) {
        // 最后一页，跳转下一章
        _c.navigation._nextChapter();
      } else {
        // 下一页
        _c._pagedContentKey.currentState?.nextPage();
        _c._curlContentKey.currentState?.nextPage();
      }
    } else {
      // 中间区域：切换菜单
      _toggleMenu();
    }
  }

  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _c.progress._saveProgress();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
      key: _c._scaffoldKey,
      backgroundColor: _c._background.bgColor,
      appBar: null, // 始终不显示 AppBar
      drawer: ReaderChapterDrawerWidget(
        chapters: _c._chapters,
        currentChapterIndex: _c._currentChapterIndex,
        background: _c._background,
        totalChapterCount: _c.meta._totalChapterCount,
        hasMoreChapters: _c._hasMoreChapters,
        isLoadingMore: _c._isLoadingMoreMeta,
        onCloseDrawer: () => _c._scaffoldKey.currentState?.closeDrawer(),
        onChapterTap: (globalIndex, chapter) {
          _c._shouldJumpToLastPage = false;
          _c._setState(() => _c._currentChapterIndex = globalIndex);
          _c.content._loadChapterContent(chapter);
        },
        onLoadMore: () => _c.meta._loadMoreChapterMeta(),
        onRefresh: _c._chapters.isNotEmpty && _c._chapters.first.chapterOrder > 1
            ? _c.meta._refreshChapterMeta
            : null,
      ),
      body: _c._isLoading
          ? const Center(child: LoadingWidget())
          : Stack(
              children: [
                // Column 布局：顶部状态栏 → 内容铺满 → 底部状态栏
                Column(
                  children: [
                    // 顶部信息栏
                    _buildTopStatusBar(context),
                    // 小说内容（铺满中间剩余空间）
                    // 优先显示已有内容，无缓存且正在加载时才显示loading
                    Expanded(
                      child: (_c._isLoadingChapter && _c._currentChapter == null)
                          ? const Center(child: LoadingWidget())
                          : _buildContent(context),
                    ),
                    // 底部状态栏
                    _buildBottomStatusBar(),
                  ],
                ),

                // scroll 模式 overshoot 视觉指示器
                if (_c._pageTurnMode == PageTurnMode.scroll && _c._overshootProgress != 0)
                  _buildOvershootIndicator(),

                // 顶部菜单（菜单显示时才显示，覆盖在内容上方）
                if (_c._showMenu)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: _buildTopMenu(context),
                  ),

                // 底部菜单（菜单显示时才显示，覆盖在内容上方）
                if (_c._showMenu)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: _buildBottomToolbar(context),
                  ),
              ],
            ),
              ),
            );
  }

  /// scroll 模式下越界拖拽的"释放切章"提示条
  Widget _buildOvershootIndicator() {
    return Positioned(
      top: _c._overshootProgress < 0 ? 0 : null,
      bottom: _c._overshootProgress > 0 ? 0 : null,
      left: 0,
      right: 0,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Opacity(
          opacity: _c._overshootProgress.abs().clamp(0.0, 1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _c._overshootProgress < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: _c._background.textColor.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _c._overshootProgress < 0 ? '释放切换到上一章' : '释放切换到下一章',
                style: TextStyle(
                  color: _c._background.textColor.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
      return ReaderContentArea(
        pageTurnMode: _c._pageTurnMode,
        chapter: _c._currentChapter,
        background: _c._background,
        font: _c._font,
        fontSize: _c._fontSize,
        lineHeight: _c._lineHeight,
        pagedContentKey: _c._pagedContentKey,
        curlContentKey: _c._curlContentKey,
        onPageChanged: _c.navigation._onPageChanged,
        onBoundaryReached: _c.navigation._onPageBoundaryReached,
        onTapScreen: _handleScreenTap,
        shouldJumpToLastPage: _c._shouldJumpToLastPage,
        startPage: _c._restorePage,
        scrollController: _c._scrollController,
        buildAnnotatedTextSpan: _c.annotations._buildAnnotatedTextSpan,
        onShowAnnotationInput: (selectedText, startOffset, endOffset) =>
            showReaderAnnotationInput(
          context,
          selectedText,
          startOffset,
          endOffset,
          onSave: (selectedText, startOffset, endOffset, note, color) =>
              _c.annotations._addAnnotation(
            selectedText: selectedText,
            startOffset: startOffset,
            endOffset: endOffset,
            note: note,
            color: color,
          ),
        ),
        getCachedTextStyle: _c.settings._getCachedTextStyle,
        onScrollOvershoot: _c.navigation._handleScrollOvershoot,
        onScrollOvershootProgress: _c.navigation._handleScrollOvershootProgress,
      );
    }
}
