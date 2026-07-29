part of 'reader_controller.dart';

class ReaderContentModule {
  final ReaderController _c;
  ReaderContentModule(this._c);

  void _goToChapter(int index) {
    if (index < 0 || index >= _c._chapters.length) return;

    final isNext = index > _c._currentChapterIndex;
    _c._shouldJumpToLastPage = !isNext;
    _c._hasTriggeredPreload = false;
    _c._overshootProgress = 0.0;

    _c._setState(() {
      _c._currentChapterIndex = index;
      // 导航切章不再复用入口恢复页，避免误定位到旧页内位置
      _c._restorePage = 0;
    });

    _loadChapterContent(_c._chapters[index]);
    _preloadAdjacentChapters(index);
  }

  Future<void> _loadChapterContent(NovelChapterModel chapter) async {
    // 记录当前加载的章节ID，用于防止竞态条件（Bug 2 修复）
    _c._loadingChapterId = chapter.id;
    // 重置页码信息
    _c._currentPageIndex = 0;
    _c._totalPages = 1;

    // 1. 优先从 _chapters 列表中加载已缓存的内容（无感切换）
    final index = _c._chapters.indexWhere((c) => c.id == chapter.id);
    if (index != -1 && _c._chapters[index].content.isNotEmpty) {
      if (!_c._disposed) {
        _c._setState(() {
          _c._currentChapter = _c._chapters[index];
          _c._isLoadingChapter = false;
        });
      }
      _scrollToPosition();
      _c.progress._saveProgress();
      _c.progress._startReadingTimer();
      _c.annotations._checkBookmarkStatus();
      _c._chapterReadStartTime = DateTime.now();
      // 后台静默更新（如果缓存过期）
      _silentRefreshChapter(chapter);
      return;
    }

    // 设置当前保护章节（内存压力时不清理）
    ChapterCacheService.instance.setProtectedChapter(chapter.id);

    try {
      // 2. 检查本地缓存（L1/L2）
      final cachedContent = await ChapterCacheService.instance.getCachedContent(chapter.id);

      // 检查是否已切换到其他章节
      if (_c._loadingChapterId != chapter.id) return;

      if (cachedContent != null) {
        // 缓存命中：立即显示缓存内容，不显示loading（无感切换）
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final cachedChapter = chapter.copyWith(content: normalizedContent);
        final chapterIndex = _c._chapters.indexWhere((c) => c.id == chapter.id);
        if (chapterIndex != -1) {
          _c._chapters[chapterIndex] = cachedChapter;
        }
        if (!_c._disposed) {
          _c._setState(() {
            _c._currentChapter = cachedChapter;
            _c._isLoadingChapter = false;
          });
        }
        _scrollToPosition();
        _c.progress._saveProgress();
        _c.progress._startReadingTimer();
        _c.annotations._checkBookmarkStatus();
        _c._chapterReadStartTime = DateTime.now();

        // 缓存过期时在后台静默刷新
        if (!ChapterCacheService.instance.isCacheFresh(chapter.id)) {
          _silentRefreshChapter(chapter);
        }
        return;
      }

      // 3. 无缓存：显示loading并发起网络请求
      if (!_c._disposed) {
        _c._setState(() => _c._isLoadingChapter = true);
      }

      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      // 再次检查是否已切换到其他章节（Bug 2 核心修复）
      if (_c._loadingChapterId != chapter.id) return;

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        final loadedChapter = parsedChapter.copyWith(content: normalizedContent);
        final loadedIndex = _c._chapters.indexWhere((c) => c.id == parsedChapter.id);
        if (loadedIndex != -1) {
          _c._chapters[loadedIndex] = loadedChapter;
        }

        if (!_c._disposed) {
          _c._setState(() {
            _c._currentChapter = loadedChapter;
            _c._isLoadingChapter = false;
          });
        }
        _scrollToPosition();
        _c.progress._saveProgress();
        _c.progress._startReadingTimer();
        _c.annotations._checkBookmarkStatus();
        _c._chapterReadStartTime = DateTime.now();

        if (normalizedContent.isNotEmpty) {
          ChapterCacheService.instance.cacheChapter(
            chapterId: parsedChapter.id,
            novelId: _c.novel.id,
            title: parsedChapter.title,
            chapterOrder: parsedChapter.chapterOrder,
            content: normalizedContent,
          );
        }
      } else {
        // 网络请求失败且无任何缓存：降级显示空内容章节
        if (!_c._disposed) {
          _c._setState(() {
            _c._currentChapter = chapter;
            _c._isLoadingChapter = false;
          });
        }
        _scrollToPosition();
      }
    } catch (e) {
      // 异常时也检查是否已切换章节
      if (_c._loadingChapterId != chapter.id) return;
      if (!_c._disposed) {
        _c._setState(() {
          _c._currentChapter = chapter;
          _c._isLoadingChapter = false;
        });
      }
      _scrollToPosition();
    }
  }

  Future<void> _silentRefreshChapter(NovelChapterModel chapter) async {
    try {
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      if (_c._loadingChapterId != chapter.id) return;

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

        // 只有当内容确实变化时才更新UI
        final currentIndex = _c._chapters.indexWhere((c) => c.id == chapter.id);
        if (currentIndex != -1) {
          final oldContent = _c._chapters[currentIndex].content;
          _c._chapters[currentIndex] = parsedChapter.copyWith(content: normalizedContent);

          // 如果当前正在显示此章节且内容有变化，无感更新
          if (_c._currentChapter?.id == chapter.id && oldContent != normalizedContent) {
            if (!_c._disposed) {
              _c._setState(() {
                _c._currentChapter = _c._chapters[currentIndex];
              });
            }
          }
        }

        if (normalizedContent.isNotEmpty) {
          ChapterCacheService.instance.cacheChapter(
            chapterId: parsedChapter.id,
            novelId: _c.novel.id,
            title: parsedChapter.title,
            chapterOrder: parsedChapter.chapterOrder,
            content: normalizedContent,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('静默刷新章节失败: ${chapter.title}');
    }
  }

  Future<void> _fetchChapterContent(NovelChapterModel chapter) async {
    // 已加载则跳过
    final idx = _c._chapters.indexWhere((c) => c.id == chapter.id);
    if (idx != -1 && _c._chapters[idx].content.isNotEmpty) return;

    try {
      // 优先检查缓存：缓存命中时立即使用，不等待网络
      final cachedContent = await ChapterCacheService.instance.getCachedContent(chapter.id);
      if (cachedContent != null) {
        final normalizedContent = cachedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (idx != -1) {
          _c._chapters[idx] = chapter.copyWith(content: normalizedContent);
        }
        return; // 缓存命中：直接返回，不阻塞等待网络刷新
      }

      // 缓存未命中：等待网络请求
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'id': 'eq.${chapter.id}'},
        columns: 'id,title,content,chapter_num,word_count',
      );

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final chapterData = result.data!.first;
        final parsedChapter = NovelChapterModel.fromJson(chapterData);
        final normalizedContent = parsedChapter.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final parsedIdx = _c._chapters.indexWhere((c) => c.id == parsedChapter.id);
        if (parsedIdx != -1) {
          _c._chapters[parsedIdx] = _c._chapters[parsedIdx].copyWith(content: normalizedContent);
        }
        if (normalizedContent.isNotEmpty) {
          ChapterCacheService.instance.cacheChapter(
            chapterId: parsedChapter.id,
            novelId: _c.novel.id,
            title: parsedChapter.title,
            chapterOrder: parsedChapter.chapterOrder,
            content: normalizedContent,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('预加载章节失败: ${chapter.title}');
      }
    }
  }

  Future<bool> _isWifiConnected() async {
    // 如需精确检测，可接入 connectivity_plus 包
    return false;
  }

  void _preloadAdjacentChapters(int index) async {
    _c._hasTriggeredPreload = false;

    // 检测网络环境（简单判断：如果有WiFi则多加载）
    final isWifi = await _isWifiConnected();
    final preloadCount = isWifi ? 2 : 1;

    final preloadIds = <String>[];

    // 预加载后续章节
    for (int i = index + 1; i < _c._chapters.length && preloadIds.length < preloadCount; i++) {
      final chapter = _c._chapters[i];
      if (chapter.content.isEmpty) {
        preloadIds.add(chapter.id);
      }
    }

    // 预加载前面章节
    for (int i = index - 1; i >= 0 && preloadIds.length < preloadCount * 2; i--) {
      final chapter = _c._chapters[i];
      if (chapter.content.isEmpty) {
        preloadIds.add(chapter.id);
      }
    }

    if (preloadIds.isEmpty) return;

    ChapterCacheService.instance.triggerPreload(
      chapterIds: preloadIds,
      fetcher: (chapterId) async {
        final chapter = _c._chapters.firstWhere((c) => c.id == chapterId);
        await _fetchChapterContent(chapter);
        return chapter.content;
      },
    );
  }

  void _scrollToPosition() {
    if (_c._pageTurnMode != PageTurnMode.scroll) return;
    // 延迟到下一帧执行，避免与正在进行的 BallisticScrollActivity 冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_c._scrollController.hasClients) return;
      try {
        if (_c._shouldJumpToLastPage) {
          // 上一章：跳转到末尾
          _c._scrollController.jumpTo(_c._scrollController.position.maxScrollExtent);
        } else {
          // 下一章：跳转到顶部
          _c._scrollController.jumpTo(0);
        }
      } catch (_) {
        // 忽略滚动中断异常
      }
    });
  }

  void _onScroll() {
    if (!_c._scrollController.hasClients) return;
    if (_c._pageTurnMode != PageTurnMode.scroll) return; // 只在滚动模式下生效

    // 70% 进度触发预加载（智能预加载）
    if (!_c._hasTriggeredPreload && !_c._isLoadingChapter) {
      final maxExtent = _c._scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final progress = _c._scrollController.position.pixels / maxExtent;
        if (progress >= 0.7) {
          _c._hasTriggeredPreload = true;
          _preloadAdjacentChapters(_c._currentChapterIndex);
        }
      }
    }

    // 注意：章节切换现在由 overscroll 手势触发（_handleScrollOvershoot），
    // 不再基于滚动位置自动触发，以便用户能明确控制切换时机。
  }
}
