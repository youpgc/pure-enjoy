part of 'reader_controller.dart';

extension _ReaderControllerAnnotations on ReaderController {

  Future<void> _checkBookmarkStatus() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) return;

    // 并行加载书签列表和批注，避免串行请求延迟
    final bookmarkFuture = BookmarkService().getBookmarks(novel.id);
    final annotationFuture = _loadAnnotations();

    final bookmarks = await bookmarkFuture;
    await annotationFuture;

    if (!_disposed) {
      _setState(() {
        _bookmarks = bookmarks;
      });
    }
  }

  Future<void> _loadAnnotations() async {
    if (_currentChapter == null) return;
    final userId = _userId;
    if (userId == null) {
      _setState(() => _annotations = []);
      return;
    }

    try {
      final result = await AnnotationService().getChapterAnnotations(
        novel.id,
        _currentChapter!.id,
      );
      if (!_disposed) {
        _setState(() => _annotations = result);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载批注失败');
      }
      if (!_disposed) {
        _setState(() => _annotations = []);
      }
    }
  }

  void _jumpToBookmark(NovelBookmark bookmark) {
    // 安全查找：按 chapterOrder 匹配，避免数组越界
    final index = _chapters.indexWhere((c) => c.chapterOrder == bookmark.chapterOrder);
    if (index == -1) {
      if (!_disposed) _safeSnack( '该章节尚未加载，请稍后再试');
      return;
    }
    _loadChapterContent(_chapters[index]);
    // 章节加载完成后，滚动到字符偏移位置
    if (bookmark.charOffset > 0 && _pageTurnMode == PageTurnMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || _currentChapter == null) return;
        final content = _currentChapter!.content;
        final ratio = bookmark.charOffset / content.length;
        final targetOffset = ratio * _scrollController.position.maxScrollExtent;
        try {
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {
          // 忽略滚动中断异常
        }
      });
    }
  }

  TextSpan _buildAnnotatedTextSpan(String content, TextStyle baseStyle) {
    return _annotatedTextBuilder.build(
      content: content,
      baseStyle: baseStyle,
      chapterId: _currentChapter?.id ?? '',
      fontStyleHash: _fontStyleHash,
    );
  }

  Future<void> _addAnnotation({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required String? note,
    required String color,
  }) async {
    final userId = _userId;
    if (userId == null) {
      _safeSnack( '请先登录');
      return;
    }
    if (_currentChapter == null) return;

    try {
      await AnnotationService().addAnnotation(
        novelId: novel.id,
        chapterId: _currentChapter!.id,
        chapterOrder: _currentChapter!.chapterOrder,
        startOffset: startOffset,
        endOffset: endOffset,
        highlightedText: selectedText,
        note: note,
        color: parseAnnotationColor(color),
      );
      if (!_disposed) {
        _safeSnack( '批注已添加');
        await _loadAnnotations();
      }
    } catch (e) {
      if (!_disposed) {
        _safeSnack( '添加批注失败');
      }
    }
  }

  Future<void> _deleteAnnotation(NovelAnnotation annotation) async {
    final ctx = _context;
    if (ctx == null) return;
    final confirmed = await showConfirmDialog(
      ctx,
      title: '确认删除',
      content: '确定要删除这条批注吗？',
    );
    if (!confirmed) return;
    try {
      await AnnotationService().deleteAnnotation(annotation.id);
      _setState(() {
        _annotations.removeWhere((a) => a.id == annotation.id);
      });
      if (!_disposed) _safeSnack( '批注已删除'); // ignore: use_build_context_synchronously
    } catch (e) {
      if (!_disposed) _safeSnack( '删除失败'); // ignore: use_build_context_synchronously
    }
  }
}
