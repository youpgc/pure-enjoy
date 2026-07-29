part of 'reader_controller.dart';

class ReaderMetaModule {
  final ReaderController _c;
  ReaderMetaModule(this._c);

  Future<void> _refreshChapterMeta() async {
    final firstOrder = _c._chapters.first.chapterOrder;
    final rangeStart = math.max(1, firstOrder - 50);
    final rangeEnd = firstOrder - 1;

    final result = await ApiClient.get(
      'novel_chapters',
      filters: {
        'novel_id': 'eq.${_c.novel.id}',
        'and': '(chapter_num.gte.$rangeStart,chapter_num.lte.$rangeEnd)',
      },
      columns: 'id,title,chapter_num',
      order: 'chapter_num.asc',
      limit: null, // 取消默认 limit=10
    );
    if (result.isSuccess && result.data != null && !_c._disposed) {
      final newChapters = result.data!
          .map((json) => NovelChapterModel.fromJson(json))
          .toList();
      newChapters.removeWhere((c) => c.chapterOrder <= 0);
      if (newChapters.isNotEmpty) {
        _c._setState(() {
          // 插入到列表头部
          _c._chapters.insertAll(0, newChapters);
          // 更新当前章节索引（因为前面插入了新章节）
          _c._currentChapterIndex += newChapters.length;
        });
      }
    }
  }

  double get _readingProgress {
    final total = _c.novel.chapterCount;
    if (total <= 0) return 0;
    final currentOrder = _c._currentChapter?.chapterOrder ?? _c._currentChapterIndex + 1;
    return currentOrder / total;
  }

  int get _totalChapterCount {
    final novelCount = _c.novel.chapterCount;
    return novelCount > 0 ? novelCount : _c._chapters.length;
  }

  String get _currentTime {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _initializeReader() async {
    _c._setState(() => _c._isLoading = true);

    try {
      final userId = _c._userId;
      int targetChapterNum = _c.startChapter;

      // 1. 先确定目标章节号：如果需要查询阅读进度，先等待结果
      // 避免用错误的初始范围查询章节列表，导致后续额外的 _loadMoreChapterMeta 调用
      if (targetChapterNum <= 0 && userId != null) {
        final progressResult = await ApiClient.get(
          'user_novels',
          filters: {
            'user_id': 'eq.$userId',
            'novel_id': 'eq.${_c.novel.id}',
          },
          columns: 'last_chapter,last_page',
          // 按最近阅读时间倒序取最新一行，防御重复行(data.first 取到旧行导致定位很早以前)
          // nullslast：避免 last_read_at 为 NULL 的行被优先取到（DESC 默认 NULLS FIRST）
          order: 'last_read_at.desc.nullslast',
          limit: 1,
        );
        if (progressResult.isSuccess &&
            progressResult.data != null &&
            progressResult.data!.isNotEmpty) {
          final row = progressResult.data!.first;
          targetChapterNum = row['last_chapter'] as int? ?? 1;
          // 记录页内位置，供首章显示时恢复到该页（导航后由 _goToChapter 重置为 0）
          _c._restorePage = (row['last_page'] as int? ?? 0).clamp(0, 1000000);
        }
        if (targetChapterNum <= 0) targetChapterNum = 1;
      }

      // 2. 使用正确的章节号范围查询章节列表
      final rangeStart = math.max(1, targetChapterNum - 25);
      final rangeEnd = targetChapterNum + 25;

      final chaptersResult = await ApiClient.get(
        'novel_chapters',
        filters: {
          'novel_id': 'eq.${_c.novel.id}',
          'and': '(chapter_num.gte.$rangeStart,chapter_num.lte.$rangeEnd)',
        },
        columns: 'id,title,chapter_num',
        order: 'chapter_num.asc',
        limit: null, // 取消默认 limit=10，按范围查询全部章节
      );

      final allChapters = <NovelChapterModel>[];
      if (chaptersResult.isSuccess && chaptersResult.data != null) {
        allChapters.addAll(
          chaptersResult.data!.map((json) => NovelChapterModel.fromJson(json)),
        );
      }
      allChapters.removeWhere((c) => c.chapterOrder <= 0);

      _c._hasMoreChapters = allChapters.length >= 50;

      // 找到当前章节索引
      int startIndex = 0;
      for (int i = 0; i < allChapters.length; i++) {
        if (allChapters[i].chapterOrder >= targetChapterNum) {
          startIndex = i;
          break;
        }
      }

      _c._chapters = allChapters;

      // 如果目标章超出已加载范围（小说实际章节数小于目标值），定位到最后一章
      // 避免触发额外的 _loadMoreChapterMeta 串行请求
      if (startIndex == 0 &&
          allChapters.isNotEmpty &&
          targetChapterNum > allChapters.last.chapterOrder) {
        startIndex = allChapters.length - 1;
      }

      if (!_c._disposed) {
        _c._setState(() {
          _c._currentChapterIndex = startIndex;
          _c._isLoading = false;
        });
      }

      // 并行加载当前章 + 前后各1章内容
      if (_c._chapters.isNotEmpty) {
        final current = _c._chapters[startIndex];
        final futures = <Future<void>>[_c.content._loadChapterContent(current)];

        if (startIndex > 0) {
          futures.add(_c.content._fetchChapterContent(_c._chapters[startIndex - 1]));
        }
        if (startIndex < _c._chapters.length - 1) {
          futures.add(_c.content._fetchChapterContent(_c._chapters[startIndex + 1]));
        }

        await Future.wait(futures);
        _c.content._preloadAdjacentChapters(startIndex);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('初始化阅读器失败: $e');
      if (!_c._disposed) {
        _c._setState(() => _c._isLoading = false);
        _c._safeSnack( '加载章节失败，请稍后重试');
      }
    }
  }

  Future<void> _loadMoreChapterMeta({int? targetChapterNum}) async {
    if (_c._isLoadingMoreMeta) return;
    if (!_c._hasMoreChapters && targetChapterNum == null) return;

    _c._setState(() => _c._isLoadingMoreMeta = true);

    try {
      // 获取当前已加载的最大章节号作为游标
      final lastChapterNum = _c._chapters.isNotEmpty ? _c._chapters.last.chapterOrder : 0;

      // 如果指定了目标章节号且已在范围内，无需加载
      if (targetChapterNum != null && targetChapterNum <= lastChapterNum) {
        _c._setState(() => _c._isLoadingMoreMeta = false);
        return;
      }

      // 键集分页：以上一批最后一条 chapter_num 为起点
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {
          'novel_id': 'eq.${_c.novel.id}',
          'chapter_num': 'gt.$lastChapterNum',
        },
        columns: 'id,title,chapter_num',
        order: 'chapter_num.asc',
        limit: ReaderController._metaBatchSize,
      );

      if (result.isSuccess && result.data != null) {
        final newChapters = result.data!
            .map((json) => NovelChapterModel.fromJson(json))
            .toList();
        newChapters.removeWhere((c) => c.chapterOrder <= 0);

        if (!_c._disposed) {
          _c._setState(() {
            _c._chapters.addAll(newChapters);
            _c._hasMoreChapters = newChapters.length >= ReaderController._metaBatchSize;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('加载更多目录失败: $e');
    } finally {
      if (!_c._disposed) _c._setState(() => _c._isLoadingMoreMeta = false);
    }
  }

  Future<void> _ensureChapterMetaLoaded(int targetIndex) async {
    while (targetIndex >= _c._chapters.length && _c._hasMoreChapters && !_c._isLoadingMoreMeta) {
      await _loadMoreChapterMeta();
    }
  }
}
