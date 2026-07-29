part of 'reader_controller.dart';

class ReaderAnnotationsModule {
  final ReaderController _c;
  ReaderAnnotationsModule(this._c);

  Future<void> _checkBookmarkStatus() async {
    if (_c._currentChapter == null) return;
    final userId = _c._userId;
    if (userId == null) return;

    // 并行加载书签列表和批注，避免串行请求延迟
    final bookmarkFuture = BookmarkService().getBookmarks(_c.novel.id);
    final annotationFuture = _loadAnnotations();

    final bookmarks = await bookmarkFuture;
    await annotationFuture;

    if (!_c._disposed) {
      _c._setState(() {
        _c._bookmarks = bookmarks;
      });
    }
  }

  Future<void> _loadAnnotations() async {
    if (_c._currentChapter == null) return;
    final userId = _c._userId;
    if (userId == null) {
      _c._setState(() => _c._annotations = []);
      return;
    }

    try {
      final result = await AnnotationService().getChapterAnnotations(
        _c.novel.id,
        _c._currentChapter!.id,
      );
      if (!_c._disposed) {
        _c._setState(() => _c._annotations = result);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载批注失败');
      }
      if (!_c._disposed) {
        _c._setState(() => _c._annotations = []);
      }
    }
  }

  void _jumpToBookmark(NovelBookmark bookmark) {
    // 安全查找：按 chapterOrder 匹配，避免数组越界
    final index = _c._chapters.indexWhere((c) => c.chapterOrder == bookmark.chapterOrder);
    if (index == -1) {
      if (!_c._disposed) _c._safeSnack( '该章节尚未加载，请稍后再试');
      return;
    }
    _c.content._loadChapterContent(_c._chapters[index]);
    // 章节加载完成后，滚动到字符偏移位置
    if (bookmark.charOffset > 0 && _c._pageTurnMode == PageTurnMode.scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_c._scrollController.hasClients || _c._currentChapter == null) return;
        final content = _c._currentChapter!.content;
        final ratio = bookmark.charOffset / content.length;
        final targetOffset = ratio * _c._scrollController.position.maxScrollExtent;
        try {
          _c._scrollController.animateTo(
            targetOffset.clamp(0.0, _c._scrollController.position.maxScrollExtent),
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
    return _c._annotatedTextBuilder.build(
      content: content,
      baseStyle: baseStyle,
      chapterId: _c._currentChapter?.id ?? '',
      fontStyleHash: _c._fontStyleHash,
    );
  }

  Future<void> _addAnnotation({
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required String? note,
    required String color,
  }) async {
    final userId = _c._userId;
    if (userId == null) {
      _c._safeSnack( '请先登录');
      return;
    }
    if (_c._currentChapter == null) return;

    try {
      await AnnotationService().addAnnotation(
        novelId: _c.novel.id,
        chapterId: _c._currentChapter!.id,
        chapterOrder: _c._currentChapter!.chapterOrder,
        startOffset: startOffset,
        endOffset: endOffset,
        highlightedText: selectedText,
        note: note,
        color: parseAnnotationColor(color),
      );
      if (!_c._disposed) {
        _c._safeSnack( '批注已添加');
        await _loadAnnotations();
      }
    } catch (e) {
      if (!_c._disposed) {
        _c._safeSnack( '添加批注失败');
      }
    }
  }

  Future<void> _deleteAnnotation(NovelAnnotation annotation) async {
    final ctx = _c._context;
    if (ctx == null) return;
    final confirmed = await showConfirmDialog(
      ctx,
      title: '确认删除',
      content: '确定要删除这条批注吗？',
    );
    if (!confirmed) return;
    try {
      await AnnotationService().deleteAnnotation(annotation.id);
      _c._setState(() {
        _c._annotations.removeWhere((a) => a.id == annotation.id);
      });
      if (!_c._disposed) _c._safeSnack( '批注已删除'); // ignore: use_build_context_synchronously
    } catch (e) {
      if (!_c._disposed) _c._safeSnack( '删除失败'); // ignore: use_build_context_synchronously
    }
  }
}
