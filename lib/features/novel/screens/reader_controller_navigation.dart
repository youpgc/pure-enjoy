part of 'reader_controller.dart';

extension _ReaderControllerNavigation on ReaderController {

  void _previousChapter() {
    final prevIndex = _currentChapterIndex - 1;

    if (prevIndex >= 0) {
      _goToChapter(prevIndex);
    } else {
      if (!_disposed) _safeSnack( '已经是第一章了');
    }
  }

  void _nextChapter() {
    final nextIndex = _currentChapterIndex + 1;

    if (nextIndex < _chapters.length) {
      _goToChapter(nextIndex);
    } else if (_hasMoreChapters) {
      // 还有更多章节未加载，先加载更多目录
      _ensureChapterMetaLoaded(nextIndex).then((_) {
        if (nextIndex < _chapters.length) {
          _goToChapter(nextIndex);
        } else {
          if (!_disposed) _safeSnack( '已经是最后一章了');
        }
      });
    } else {
      if (!_disposed) _safeSnack( '已经是最后一章了');
    }
  }

  void _onPageChanged(int currentPage, int totalPages) {
    _setState(() {
      _currentPageIndex = currentPage;
      _totalPages = totalPages;
    });
  }

  void _onPageBoundaryReached(bool isLastPage) {
    // 防抖：一次滑动手势中边界回调可能连续触发多次，
    // 700ms 内只处理一次，避免连续切换跳过多个章节
    final now = DateTime.now();
    if (_lastBoundarySwitchAt != null &&
        now.difference(_lastBoundarySwitchAt!).inMilliseconds < 700) {
      return;
    }
    _lastBoundarySwitchAt = now;

    if (isLastPage) {
      // 到达最后一页，跳转下一章
      if (_currentChapterIndex < _chapters.length - 1 || _hasMoreChapters) {
        _nextChapter();
      } else {
        _safeSnack( '已经是最后一章了');
      }
    } else {
      // 到达第一页，跳转上一章
      if (_currentChapterIndex > 0) {
        _previousChapter();
      } else {
        _safeSnack( '已经是第一章了');
      }
    }
  }

  void _handleScrollOvershoot(bool isEnd) {
    if (_pageTurnMode != PageTurnMode.scroll) return;
    if (_isLoadingChapter) return;

    if (isEnd) {
      if (_currentChapterIndex < _chapters.length - 1 || _hasMoreChapters) {
        _nextChapter();
      } else {
        _safeSnack( '已经是最后一章了');
      }
    } else {
      if (_currentChapterIndex > 0) {
        _previousChapter();
      } else {
        _safeSnack( '已经是第一章了');
      }
    }
  }

  void _handleScrollOvershootProgress(double progress) {
    if (_pageTurnMode != PageTurnMode.scroll) return;
    if (_overshootProgress == progress) return;
    _setState(() {
      _overshootProgress = progress;
    });
  }
}
