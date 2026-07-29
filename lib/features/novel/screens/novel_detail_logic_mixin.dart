part of 'novel_detail_screen.dart';

/// 小说详情页的「数据 + 操作」逻辑混合层。
///
/// 把原本集中在 [_NovelDetailScreenState] 的实例字段与所有数据加载 / 书架 /
/// 评分 / 缓存 / 阅读跳转方法整体搬到这里，使主 State 文件保持在 500 行以内。
/// 这些成员在 mixin 或 State 中并无行为差异（仍是同一个类实例的成员），
/// State 的 [build] 照常读取这里的字段。
mixin _NovelDetailLogic on State<NovelDetailScreen> {
  bool _isInBookshelf = false;
  bool _isLoadingShelf = true;
  bool _isDownloading = false;
  int _cachedChapterCount = 0;
  String? _bookshelfId;
  int _currentChapter = 1;
  List<NovelChapterModel> _chapters = [];
  bool _isLoadingChapters = true;
  bool _isCollected = false;
  double? _userRating; // 用户对这本小说的评分

  // 章节列表分页
  static const int _chapterPageSize = 10;
  int _currentChapterPage = 0;
  bool _hasMoreChapters = true;
  bool _isLoadingMoreChapters = false;

  String? get _userId => AuthService.instance.currentUserId;

  /// 加载用户对本书的评分
  Future<void> _loadUserRating() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final result = await ApiClient.get('novel_ratings',
          filters: {'user_id': 'eq.$userId', 'novel_id': 'eq.${widget.novel.id}'},
          columns: 'rating',
          limit: 1);
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userRating = (result.data!.first['rating'] as num?)?.toDouble();
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('加载用户评分失败: $e');
    }
  }

  /// 提交/更新用户评分
  Future<void> _submitRating(double rating) async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) showSnackBar(context, '请先登录');
      return;
    }
    try {
      await upsertNovelRating(userId, widget.novel.id, rating);
      if (mounted) {
        setState(() => _userRating = rating);
        showSnackBar(context, '评分成功');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('评分提交失败: $e');
      if (mounted) showSnackBar(context, '评分失败');
    }
  }

  /// 检查书架状态
  Future<void> _checkBookshelfStatus() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoadingShelf = false);
      return;
    }

    try {
      final result = await ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$userId',
          'novel_id': 'eq.${widget.novel.id}',
        },
        columns: 'id,is_collected,last_chapter,last_read_at',
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          setState(() {
            _isInBookshelf = true;
            _bookshelfId = data.first['id'].toString();
            _currentChapter = data.first['last_chapter'] as int? ?? 1;
            _isCollected = data.first['is_collected'] as bool? ?? false;
            _isLoadingShelf = false;
          });
        } else {
          setState(() => _isLoadingShelf = false);
        }
      } else {
        setState(() => _isLoadingShelf = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingShelf = false);
      }
    }
  }

  /// 加载章节列表第一页
  Future<void> _loadChapters() async {
    try {
      final page = await fetchNovelChapterPage(widget.novel.id, _chapterPageSize, 0);
      if (page.isSuccess) {
        if (mounted) {
          setState(() {
            _chapters = page.chapters;
            _isLoadingChapters = false;
            _hasMoreChapters = page.hasMore;
            _currentChapterPage = 1;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingChapters = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  /// 触底加载更多章节
  Future<void> _loadMoreChapters() async {
    if (_isLoadingMoreChapters || !_hasMoreChapters) return;
    setState(() => _isLoadingMoreChapters = true);

    try {
      final page = await fetchNovelChapterPage(
        widget.novel.id,
        _chapterPageSize,
        _currentChapterPage * _chapterPageSize,
      );
      if (page.isSuccess) {
        if (mounted) {
          setState(() {
            _chapters.addAll(page.chapters);
            _hasMoreChapters = page.hasMore;
            _currentChapterPage++;
            _isLoadingMoreChapters = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMoreChapters = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMoreChapters = false);
    }
  }

  /// 加入/移出书架
  Future<void> _toggleBookshelf() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        showSnackBar(context, '请先登录');
      }
      return;
    }

    if (_isInBookshelf && _bookshelfId != null) {
      // 移出书架 - 二次确认
      final confirm = await showRemoveFromBookshelfDialog(context);
      if (confirm != true) return;

      try {
        final result = await ApiClient.batchDeleteByFilter(
          'user_novels',
          filters: {'id': 'eq.$_bookshelfId'},
        );

        if (!mounted) return;
        if (result.isSuccess) {
          setState(() {
            _isInBookshelf = false;
            _bookshelfId = null;
          });
          if (mounted) {
            showSnackBar(context, '已从书架移除');
          }
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, '操作失败，请稍后重试');
        }
      }
    } else {
      // 加入书架
      try {
        final result = await ApiClient.post(
          'user_novels',
          {
            'user_id': userId,
            'novel_id': widget.novel.id,
            'progress': 0,
            'last_chapter': 0,
            'is_collected': true,
            'last_read_at': DateTime.now().toUtc().toIso8601String(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );

        if (!mounted) return;
        if (result.isSuccess) {
          final data = result.data!;
          if (data.isNotEmpty) {
            setState(() {
              _isInBookshelf = true;
              _bookshelfId = data.first['id'].toString();
            });
          }
          if (mounted) {
            showSnackBar(context, '已加入书架');
            EventBus.instance.fire(EventType.bookshelfUpdated);
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, '操作失败，请稍后重试');
        }
      }
    }
  }

  /// 切换收藏状态
  Future<void> _toggleCollect() async {
    if (_bookshelfId == null) {
      // 如果不在书架中，先加入书架
      await _toggleBookshelf();
      return;
    }

    try {
      final result = await ApiClient.patchByFilter(
        'user_novels',
        filters: {'id': 'eq.$_bookshelfId'},
        body: {'is_collected': !_isCollected},
      );

      if (result.isSuccess) {
        if (mounted) {
          setState(() => _isCollected = !_isCollected);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '操作失败，请稍后重试');
      }
    }
  }

  /// 更新缓存状态
  void _updateCacheStatus() {
    setState(() {
      _cachedChapterCount = ChapterCacheService.instance.getCachedCount(widget.novel.id);
    });
  }

  /// 下载全部章节（离线缓存）
  Future<void> _downloadAllChapters() async {
    if (_chapters.isEmpty) return;
    setState(() => _isDownloading = true);

    int downloaded = 0;
    final uncachedChapters = _chapters.where((c) => !ChapterCacheService.instance.isCached(c.id)).toList();

    // 分批查询所有未缓存章节内容（每批100条）
    if (uncachedChapters.isNotEmpty) {
      try {
        final contentMap = <String, String>{};
        const downloadBatchSize = 100;

        for (int i = 0; i < uncachedChapters.length; i += downloadBatchSize) {
          final batch = uncachedChapters.skip(i).take(downloadBatchSize).toList();
          final chapterIds = batch.map((c) => c.id).toList();
          final result = await ApiClient.get(
            'novel_chapters',
            filters: {'id': 'in.(${chapterIds.join(",")})'},
            columns: 'id,content',
            limit: downloadBatchSize,
          );

          if (result.isSuccess) {
            for (final item in result.data!) {
              final id = item['id'] as String?;
              final content = item['content'] as String?;
              if (id != null && content != null && content.isNotEmpty) {
                contentMap[id] = content;
              }
            }
          }
        }

        for (final chapter in uncachedChapters) {
          final content = contentMap[chapter.id];
          if (content != null) {
            await ChapterCacheService.instance.cacheChapter(
              chapterId: chapter.id,
              novelId: widget.novel.id,
              title: chapter.title,
              chapterOrder: chapter.chapterOrder,
              content: content,
            );
            downloaded++;
            if (mounted) {
              setState(() => _cachedChapterCount = _cachedChapterCount + 1);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('批量缓存章节失败');
        }
      }
    }

    // 已缓存的章节直接计数
    downloaded += _chapters.length - uncachedChapters.length;
    if (mounted) {
      setState(() => _cachedChapterCount = downloaded);
      setState(() => _isDownloading = false);
    }
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    await ChapterCacheService.instance.clearNovelCache(widget.novel.id);
    _updateCacheStatus();
  }

  /// 开始阅读
  Future<void> _startReading() async {
    // 聚合小说按来源路由到外部（原生 App / WebView）
    await NovelLaunchService.instance.launch(
      context,
      widget.novel,
      startChapter: _isInBookshelf ? _currentChapter : 1,
    );
  }

  /// 跳转到指定章节
  Future<void> _jumpToChapter(int chapterNum) async {
    // 聚合小说按来源路由到外部
    await NovelLaunchService.instance.launch(
      context,
      widget.novel,
      startChapter: chapterNum,
    );
  }
}
