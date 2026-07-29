part of 'reader_controller.dart';

extension ReaderControllerUi on ReaderController {

  Widget _buildBottomStatusBar() {
    return ReaderBottomStatusBar(
      background: _background,
      chaptersNotEmpty: _chapters.isNotEmpty,
      readingProgress: _readingProgress,
      currentTime: _currentTime,
      batteryLevel: _batteryLevel,
    );
  }

  void _toggleMenu() {
    _setState(() => _showMenu = !_showMenu);
    if (_showMenu) {
      _toolbarAnimationController.forward();
      // 保持沉浸式模式，避免状态栏显示导致内容偏移
      // 工具栏使用 SafeArea 自动适配状态栏高度
    } else {
      _toolbarAnimationController.reverse();
    }
  }

  Widget _buildTopStatusBar(BuildContext context) {
    return ReaderTopStatusBar(
      background: _background,
      currentChapter: _currentChapter,
      novelTitle: novel.title,
      onBack: () async {
        await _saveProgress();
        if (!_disposed) Navigator.pop(context); // ignore: use_build_context_synchronously
      },
    );
  }

  Widget _buildTopMenu(BuildContext context) {
    return ReaderTopMenu(
      fadeAnimation: _toolbarFadeAnimation,
      slideAnimation: _topToolbarSlideAnimation,
      background: _background,
      novel: novel,
      currentChapter: _currentChapter,
      currentChapterIndex: _currentChapterIndex,
      chapterCount: _totalChapterCount,
      hasStartedReading: _hasStartedReading,
      currentReadingDuration: _currentReadingDuration,
      isCollected: _isCollected,
      onBack: () => Navigator.pop(context),
      onToggleCollection: _toggleCollection,
      onShowTtsPanel: () => showReaderTtsPanel(
        context,
        isPlaying: _isTtsPlaying,
        onPlayStateChanged: (playing) => _setState(() => _isTtsPlaying = playing),
        novelId: novel.id,
        chapterId: _currentChapter?.id ?? '',
        chapterContent: _currentChapter?.content ?? '',
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    return ReaderBottomToolbar(
      fadeAnimation: _toolbarFadeAnimation,
      slideAnimation: _bottomToolbarSlideAnimation,
      background: _background,
      currentChapterIndex: _currentChapterIndex,
      chapterCount: _totalChapterCount,
      onPreviousChapter: _previousChapter,
      onNextChapter: _nextChapter,
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      onShowBookmarkList: () => showReaderBookmarkList(
        context,
        bookmarks: _bookmarks,
        currentChapter: _currentChapter,
        onBookmarkTap: _jumpToBookmark,
      ),
      onShowAnnotationList: () => showReaderAnnotationList(
        context,
        annotations: _annotations,
        onDelete: _deleteAnnotation,
      ),
      onShowSettings: _showSettings,
      onToggleDayNight: () {
        _setState(() {
          if (_background == ReaderBackground.dark) {
            _background = _lastDayBackground;
          } else {
            _lastDayBackground = _background;
            _background = ReaderBackground.dark;
          }
        });
        _saveSettings();
      },
    );
  }

  void _showSettings() {
    final ctx = _context;
    if (ctx == null) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ReaderSettingsPanel(
          fontSize: _fontSize,
          fontSizeIndex: _fontSizeIndex,
          fontSizes: ReaderController._fontSizes,
          lineHeight: _lineHeight,
          lineHeightIndex: _lineHeightIndex,
          lineHeights: ReaderController._lineHeights,
          pageTurnMode: _pageTurnMode,
          font: _font,
          background: _background,
          onFontSizeIndexChanged: (index) {
            setModalState(() => _fontSizeIndex = index);
            _setState(() {});
          },
          onLineHeightIndexChanged: (index) {
            setModalState(() => _lineHeightIndex = index);
            _setState(() {});
          },
          onPageTurnModeChanged: (mode) {
            setModalState(() => _pageTurnMode = mode);
            _setState(() {});
          },
          onFontChanged: (font) {
            setModalState(() => _font = font);
            _setState(() {});
          },
          onBackgroundChanged: (bg) {
            setModalState(() => _background = bg);
            _setState(() {});
            if (bg != ReaderBackground.dark) {
              _lastDayBackground = bg;
            }
          },
          onSave: _saveSettings,
        ),
      ),
    );
  }

  void _handleScreenTap(TapUpDetails details) {
    final ctx = _context;
    if (ctx == null) return;
    final width = MediaQuery.of(ctx).size.width;
    final dx = details.globalPosition.dx;

    if (_pageTurnMode == PageTurnMode.scroll) {
      // 滚动模式下点击任意位置唤起/关闭菜单
      _toggleMenu();
      return;
    }

    // 分页模式
    if (dx < width * 0.3) {
      // 左侧区域
      if (_currentPageIndex <= 0) {
        // 第一页，跳转上一章
        _previousChapter();
      } else {
        // 上一页
        _pagedContentKey.currentState?.previousPage();
        _curlContentKey.currentState?.previousPage();
      }
    } else if (dx > width * 0.7) {
      // 右侧区域
      if (_currentPageIndex >= _totalPages - 1) {
        // 最后一页，跳转下一章
        _nextChapter();
      } else {
        // 下一页
        _pagedContentKey.currentState?.nextPage();
        _curlContentKey.currentState?.nextPage();
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
        await _saveProgress();
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: _background.bgColor,
      appBar: null, // 始终不显示 AppBar
      drawer: ReaderChapterDrawerWidget(
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        background: _background,
        totalChapterCount: _totalChapterCount,
        hasMoreChapters: _hasMoreChapters,
        isLoadingMore: _isLoadingMoreMeta,
        onCloseDrawer: () => _scaffoldKey.currentState?.closeDrawer(),
        onChapterTap: (globalIndex, chapter) {
          _shouldJumpToLastPage = false;
          _setState(() => _currentChapterIndex = globalIndex);
          _loadChapterContent(chapter);
        },
        onLoadMore: () => _loadMoreChapterMeta(),
        onRefresh: _chapters.isNotEmpty && _chapters.first.chapterOrder > 1
            ? _refreshChapterMeta
            : null,
      ),
      body: _isLoading
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
                      child: (_isLoadingChapter && _currentChapter == null)
                          ? const Center(child: LoadingWidget())
                          : _buildContent(context),
                    ),
                    // 底部状态栏
                    _buildBottomStatusBar(),
                  ],
                ),

                // scroll 模式 overshoot 视觉指示器
                if (_pageTurnMode == PageTurnMode.scroll && _overshootProgress != 0)
                  Positioned(
                    top: _overshootProgress < 0 ? 0 : null,
                    bottom: _overshootProgress > 0 ? 0 : null,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: _overshootProgress.abs().clamp(0.0, 1.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _overshootProgress < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              color: _background.textColor.withValues(alpha: 0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _overshootProgress < 0 ? '释放切换到上一章' : '释放切换到下一章',
                              style: TextStyle(
                                color: _background.textColor.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 顶部菜单（菜单显示时才显示，覆盖在内容上方）
                if (_showMenu)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: _buildTopMenu(context),
                  ),

                // 底部菜单（菜单显示时才显示，覆盖在内容上方）
                if (_showMenu)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: _buildBottomToolbar(context),
                  ),
              ],
            ),
              ),
            );
  }

  Widget _buildContent(BuildContext context) {
      return ReaderContentArea(
        pageTurnMode: _pageTurnMode,
        chapter: _currentChapter,
        background: _background,
        font: _font,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        pagedContentKey: _pagedContentKey,
        curlContentKey: _curlContentKey,
        onPageChanged: _onPageChanged,
        onBoundaryReached: _onPageBoundaryReached,
        onTapScreen: _handleScreenTap,
        shouldJumpToLastPage: _shouldJumpToLastPage,
        startPage: _restorePage,
        scrollController: _scrollController,
        buildAnnotatedTextSpan: _buildAnnotatedTextSpan,
        onShowAnnotationInput: (selectedText, startOffset, endOffset) =>
            showReaderAnnotationInput(
          context,
          selectedText,
          startOffset,
          endOffset,
          onSave: (selectedText, startOffset, endOffset, note, color) =>
              _addAnnotation(
            selectedText: selectedText,
            startOffset: startOffset,
            endOffset: endOffset,
            note: note,
            color: color,
          ),
        ),
        getCachedTextStyle: _getCachedTextStyle,
        onScrollOvershoot: _handleScrollOvershoot,
        onScrollOvershootProgress: _handleScrollOvershootProgress,
      );
    }
}
