part of 'reader_controller.dart';

class ReaderNavigationModule {
  final ReaderController _c;
  ReaderNavigationModule(this._c);

  void _previousChapter() {
    final prevIndex = _c._currentChapterIndex - 1;

    if (prevIndex >= 0) {
      _c.content._goToChapter(prevIndex);
    } else {
      if (!_c._disposed) _c._safeSnack( '已经是第一章了');
    }
  }

  void _nextChapter() {
    final nextIndex = _c._currentChapterIndex + 1;

    if (nextIndex < _c._chapters.length) {
      _c.content._goToChapter(nextIndex);
    } else if (_c._hasMoreChapters) {
      // 还有更多章节未加载，先加载更多目录
      _c.meta._ensureChapterMetaLoaded(nextIndex).then((_) {
        if (nextIndex < _c._chapters.length) {
          _c.content._goToChapter(nextIndex);
        } else {
          if (!_c._disposed) _c._safeSnack( '已经是最后一章了');
        }
      });
    } else {
      if (!_c._disposed) _c._safeSnack( '已经是最后一章了');
    }
  }

  void _onPageChanged(int currentPage, int totalPages) {
    _c._setState(() {
      _c._currentPageIndex = currentPage;
      _c._totalPages = totalPages;
    });
  }

  void _onPageBoundaryReached(bool isLastPage) {
    // 防抖：一次滑动手势中边界回调可能连续触发多次，
    // 700ms 内只处理一次，避免连续切换跳过多个章节
    final now = DateTime.now();
    if (_c._lastBoundarySwitchAt != null &&
        now.difference(_c._lastBoundarySwitchAt!).inMilliseconds < 700) {
      return;
    }
    _c._lastBoundarySwitchAt = now;

    if (isLastPage) {
      // 到达最后一页，跳转下一章
      if (_c._currentChapterIndex < _c._chapters.length - 1 || _c._hasMoreChapters) {
        _nextChapter();
      } else {
        _c._safeSnack( '已经是最后一章了');
      }
    } else {
      // 到达第一页，跳转上一章
      if (_c._currentChapterIndex > 0) {
        _previousChapter();
      } else {
        _c._safeSnack( '已经是第一章了');
      }
    }
  }

  void _handleScrollOvershoot(bool isEnd) {
    if (_c._pageTurnMode != PageTurnMode.scroll) return;
    if (_c._isLoadingChapter) return;

    if (isEnd) {
      if (_c._currentChapterIndex < _c._chapters.length - 1 || _c._hasMoreChapters) {
        _nextChapter();
      } else {
        _c._safeSnack( '已经是最后一章了');
      }
    } else {
      if (_c._currentChapterIndex > 0) {
        _previousChapter();
      } else {
        _c._safeSnack( '已经是第一章了');
      }
    }
  }

  void _handleScrollOvershootProgress(double progress) {
    if (_c._pageTurnMode != PageTurnMode.scroll) return;
    if (_c._overshootProgress == progress) return;
    _c._setState(() {
      _c._overshootProgress = progress;
    });
  }
}
