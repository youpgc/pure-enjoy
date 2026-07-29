part of 'reader_controller.dart';

class ReaderProgressModule {
  final ReaderController _c;
  ReaderProgressModule(this._c);

  void _pauseReadingTimer() {
    if (_c._readingStartTime != null && _c._hasStartedReading) {
      _c._totalReadingTime += DateTime.now().difference(_c._readingStartTime!);
      _c._readingStartTime = null;
    }
  }

  void _resumeReadingTimer() {
    if (_c._hasStartedReading) {
      _c._readingStartTime = DateTime.now();
    }
  }

  void _startReadingTimer() {
    if (!_c._hasStartedReading) {
      _c._hasStartedReading = true;
      _c._readingStartTime = DateTime.now();
    }
  }

  Duration get _currentReadingDuration {
    if (_c._readingStartTime != null) {
      return _c._totalReadingTime + DateTime.now().difference(_c._readingStartTime!);
    }
    return _c._totalReadingTime;
  }

  Future<void> _checkBookshelfStatus() async {
    final userId = _c._userId;
    if (userId == null) {
      if (!_c._bookshelfStatusCompleter.isCompleted) _c._bookshelfStatusCompleter.complete();
      return;
    }

    try {
      final result = await ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'novel_id': 'eq.${_c.novel.id}',
        },
        columns: 'id,is_collected',
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty && !_c._disposed) {
          _c._setState(() {
            _c._isInBookshelf = true;
            _c._bookshelfId = data.first['id'].toString();
            _c._isCollected = data.first['is_collected'] as bool? ?? false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('检查书架状态失败');
      }
    } finally {
      if (!_c._bookshelfStatusCompleter.isCompleted) _c._bookshelfStatusCompleter.complete();
    }
  }

  Future<void> _saveProgress() async {
    if (_c._currentChapter == null) return;
    final userId = _c._userId;
    if (userId == null) return;

    try {
      final chapterNum = _c._currentChapter!.chapterOrder;
      final totalChapters = _c.meta._totalChapterCount;
      final progress = totalChapters > 0 ? chapterNum / totalChapters : 0.0;

      // 并行执行：记录阅读历史 + 保存阅读进度（两者无依赖关系）
      final historyFuture = _recordReadingHistory(progress);

      // 保存阅读进度到 user_novels
      Future<void> progressFuture;
      if (_c._isInBookshelf && _c._bookshelfId != null) {
        progressFuture = _saveReadingProgress(progress: progress, chapterNum: chapterNum);
      } else {
        // 等待书架状态检查完成，避免重复创建记录（Bug 3 修复）
        progressFuture = () async {
          if (!_c._bookshelfStatusCompleter.isCompleted) {
            await _c._bookshelfStatusCompleter.future;
          }
          if (_c._isInBookshelf && _c._bookshelfId != null) {
            await _saveReadingProgress(progress: progress, chapterNum: chapterNum);
          } else {
            // 二次确认是否已有记录：阅读时自动建行与“加入书架”建行存在竞态，
            // 可能已存在 (user_id, novel_id) 行。若已存在则复用并 PATCH，
            // 避免重复创建导致入口读 data.first 取到旧行（定位到很早以前）。
            final existing = await ApiClient.get(
              'user_novels',
              filters: {
                'user_id': 'eq.$userId',
                'novel_id': 'eq.${_c.novel.id}',
              },
              columns: 'id',
              order: 'last_read_at.desc.nullslast',
              limit: 1,
            );
            if (existing.isSuccess &&
                existing.data != null &&
                existing.data!.isNotEmpty) {
              final id = existing.data!.first['id'].toString();
              if (!_c._disposed) {
                _c._setState(() {
                  _c._isInBookshelf = true;
                  _c._bookshelfId = id;
                });
              }
              await _saveReadingProgress(progress: progress, chapterNum: chapterNum);
            } else {
              final result = await ApiClient.post(
                'user_novels',
                {
                  'user_id': userId,
                  'novel_id': _c.novel.id,
                  'progress': progress,
                  'last_chapter': chapterNum,
                  'last_page': _c._currentPageIndex,
                  'is_collected': true,
                  'reading_status': progress >= 1.0 ? 'finished' : 'reading',
                  'last_read_at': DateTime.now().toUtc().toIso8601String(),
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
              );

              if (result.isSuccess) {
                final data = result.data!;
                if (data.isNotEmpty && !_c._disposed) {
                  _c._setState(() {
                    _c._isInBookshelf = true;
                    _c._bookshelfId = data.first['id'].toString();
                    _c._isCollected = true;
                  });
                }
              }
            }
          }
        }();
      }

      // 等待两个并行任务完成
      await Future.wait([historyFuture, progressFuture]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存阅读进度失败');
      }
    }
  }

  Future<void> _saveReadingProgress({
    required double progress,
    required int chapterNum,
  }) async {
    final result = await ApiClient.patchByFilter(
      'user_novels',
      filters: {'id': 'eq.${_c._bookshelfId}'},
      body: {
        'last_chapter': chapterNum,
        'progress': progress,
        'last_page': _c._currentPageIndex,
        'is_collected': true,
        'reading_status': progress >= 1.0 ? 'finished' : 'reading',
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    if (!result.isSuccess && kDebugMode) {
      debugPrint('阅读进度保存失败: ${result.error}');
    }
  }

  Future<void> _recordReadingHistory(double progress) async {
    if (_c._currentChapter == null) return;
    final userId = _c._userId;
    if (userId == null) return;

    final now = DateTime.now();
    final readDuration = _c._chapterReadStartTime != null
        ? now.difference(_c._chapterReadStartTime!).inSeconds
        : 0;

    // 至少阅读了5秒才记录
    if (readDuration < 5) return;

    await ReadingHistoryService().recordReading(
      novelId: _c.novel.id,
      chapterId: _c._currentChapter!.id,
      chapterOrder: _c._currentChapter!.chapterOrder,
      readDurationSeconds: readDuration,
      progress: progress,
    );

    _c._chapterReadStartTime = now;
  }

  Future<void> _addToBookshelf() async {
    final userId = _c._userId;
    if (userId == null) {
      if (!_c._disposed) {
        _c._safeSnack( '请先登录');
      }
      return;
    }

    try {
      final result = await ApiClient.post(
        'user_novels',
        {
          'user_id': userId,
          'novel_id': _c.novel.id,
          'progress': 0,
          'last_chapter': _c._currentChapter?.chapterOrder ?? 1,
          'is_collected': true,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty && !_c._disposed) {
          _c._setState(() {
            _c._isInBookshelf = true;
            _c._bookshelfId = data.first['id'].toString();
          });
        }
        if (!_c._disposed) {
          _c._safeSnack( '已加入书架');
          EventBus.instance.fire(EventType.bookshelfUpdated);
        }
      }
    } catch (e) {
      if (!_c._disposed) {
        _c._safeSnack( '操作失败，请稍后重试');
      }
    }
  }

  Future<void> _toggleCollection() async {
    if (_c._bookshelfId == null) {
      await _addToBookshelf();
      return;
    }

    try {
      final result = await ApiClient.patchByFilter(
        'user_novels',
        filters: {'id': 'eq.${_c._bookshelfId}'},
        body: {'is_collected': !_c._isCollected},
      );

      if (result.isSuccess) {
        if (!_c._disposed) {
          _c._setState(() => _c._isCollected = !_c._isCollected);
        }
      }
    } catch (e) {
      if (!_c._disposed) {
        _c._safeSnack( '操作失败，请稍后重试');
      }
    }
  }
}
