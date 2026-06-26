import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/chapter_cache_service.dart';
import '../../../utils/format_utils.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';

/// 小说详情页面
class NovelDetailScreen extends StatefulWidget {
  final NovelModel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  bool _isInBookshelf = false;
  bool _isLoadingShelf = true;
  bool _isDownloading = false;
  int _cachedChapterCount = 0;
  String? _bookshelfId;
  int _currentChapter = 1;
  List<NovelChapterModel> _chapters = [];
  bool _isLoadingChapters = true;
  bool _isCollected = false;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _checkBookshelfStatus();
    _loadChapters();
    _updateCacheStatus();
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
      setState(() => _isLoadingShelf = false);
    }
  }

  /// 加载章节列表（分批加载，无数量上限）
  Future<void> _loadChapters() async {
    const batchSize = 50;
    final allChapters = <NovelChapterModel>[];
    int offset = 0;
    bool hasMore = true;

    try {
      while (hasMore) {
        final result = await ApiClient.get(
          'novel_chapters',
          filters: {
            'novel_id': 'eq.${widget.novel.id}',
            'chapter_num': 'gte.1',
          },
          columns: 'id,title,chapter_num,word_count',
          order: 'chapter_num.asc',
          limit: batchSize,
          offset: offset,
        );

        if (result.isSuccess) {
          final data = result.data!;
          final batch = data.map((json) => NovelChapterModel.fromJson(json)).toList();
          allChapters.addAll(batch);
          hasMore = data.length >= batchSize;
          offset += batchSize;
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        setState(() {
          _chapters = allChapters;
          _isLoadingChapters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChapters = false);
      }
    }
  }

  /// 加入/移出书架
  Future<void> _toggleBookshelf() async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    if (_isInBookshelf && _bookshelfId != null) {
      // 移出书架 - 二次确认
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认移除'),
          content: const Text('确定要将这本小说从书架移除吗？阅读进度将不会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('移除'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      try {
        final result = await ApiClient.batchDeleteByFilter(
          'user_novels',
          filters: {'id': 'eq.$_bookshelfId'},
        );

        if (result.isSuccess) {
          setState(() {
            _isInBookshelf = false;
            _bookshelfId = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已从书架移除')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
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

        if (result.isSuccess) {
          final data = result.data!;
          if (data.isNotEmpty) {
            setState(() {
              _isInBookshelf = true;
              _bookshelfId = data.first['id'].toString();
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已加入书架')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
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
            setState(() => _cachedChapterCount = _cachedChapterCount + 1);
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
    setState(() => _cachedChapterCount = downloaded);
    setState(() => _isDownloading = false);
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    await ChapterCacheService.instance.clearNovelCache(widget.novel.id);
    _updateCacheStatus();
  }

  /// 开始阅读
  void _startReading() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novel: widget.novel,
          startChapter: _isInBookshelf ? _currentChapter : 1,
        ),
      ),
    );
  }

  /// 跳转到指定章节
  void _jumpToChapter(int chapterNum) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novel: widget.novel,
          startChapter: chapterNum,
        ),
      ),
    );
  }

  /// 显示章节目录
  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '章节目录',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '共 ${_chapters.length} 章',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoadingChapters
                  ? const Center(child: CircularProgressIndicator())
                  : _chapters.isEmpty
                      ? const Center(child: Text('暂无章节'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = _chapters[index];
                            final isCurrent = chapter.chapterOrder == _currentChapter;

                            return ListTile(
                              dense: true,
                              title: Text(
                                chapter.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isCurrent
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: isCurrent ? FontWeight.bold : null,
                                ),
                              ),
                              trailing: isCurrent
                                  ? Icon(
                                      Icons.play_arrow,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    )
                                  : Text(
                                      '${chapter.wordCount ?? ""}字',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                              onTap: () {
                                Navigator.pop(context);
                                _jumpToChapter(chapter.chapterOrder);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化字数
  String _formatWordCount(int? wordCount) {
    if (wordCount == null) return '未知';
    return FormatUtils.formatWordCount(wordCount);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final novel = widget.novel;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部应用栏 + 封面
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景封面（模糊效果）
                  if (novel.cover != null)
                    Image.network(
                      novel.cover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colorScheme.primaryContainer,
                      ),
                    )
                  else
                    Container(color: colorScheme.primaryContainer),
                  // 渐变遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          colorScheme.surface,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // 小说信息
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 封面缩略图
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 90,
                            height: 120,
                            child: novel.cover != null
                                ? Image.network(
                                    novel.cover!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.book,
                                        size: 40,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.book,
                                      size: 40,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 标题和作者
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                novel.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                novel.author ?? '佚名',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (novel.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    DictService.instance.getLabelOrDefault(
                                      'novel_category',
                                      novel.category!,
                                      defaultValue: novel.category!,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 统计信息
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  _StatItem(
                    label: '字数',
                    value: _formatWordCount(novel.wordCount),
                  ),
                  Container(width: 1, height: 32, color: colorScheme.outlineVariant),
                  _StatItem(
                    label: '章节',
                    value: '${novel.chapterCount} 章',
                  ),
                  Container(width: 1, height: 32, color: colorScheme.outlineVariant),
                  _StatItem(
                    label: '状态',
                    value: DictService.instance.getLabelOrDefault('novel_status', novel.status ?? '', defaultValue: novel.status == 'completed' ? '已完结' : '连载中'),
                  ),
                  Container(width: 1, height: 32, color: colorScheme.outlineVariant),
                  _StatItem(
                    label: '评分',
                    value: novel.rating != null ? '${novel.rating}' : '--',
                  ),
                ],
              ),
            ),
          ),

          // 操作按钮
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 开始阅读按钮
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _startReading,
                      icon: const Icon(Icons.menu_book),
                      label: Text(
                        _isInBookshelf && _currentChapter > 1
                            ? '继续阅读 第$_currentChapter章'
                            : '开始阅读',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 书架按钮
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: _isLoadingShelf
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : OutlinedButton(
                            onPressed: _toggleBookshelf,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                            ),
                            child: Icon(
                              _isInBookshelf
                                  ? Icons.library_books
                                  : Icons.library_add_outlined,
                              color: _isInBookshelf ? colorScheme.primary : null,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // 缓存下载按钮
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: _isDownloading
                        ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : OutlinedButton(
                            onPressed: _cachedChapterCount > 0 && _cachedChapterCount >= _chapters.length
                                ? _clearCache
                                : _downloadAllChapters,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                            ),
                            child: Icon(
                              _cachedChapterCount > 0
                                  ? Icons.download_done
                                  : Icons.download_outlined,
                              color: _cachedChapterCount > 0 ? AppTheme.success : null,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // 收藏按钮
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isInBookshelf ? _toggleCollect : null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                      ),
                      child: Icon(
                        _isCollected
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _isCollected ? Theme.of(context).colorScheme.error : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 小说简介
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '简介',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    novel.description ?? '暂无简介',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // 章节目录
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '章节目录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (!_isLoadingChapters)
                    Text(
                      '共 ${_chapters.length} 章',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showChapterList,
                    child: Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // 章节列表（显示前20章）
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_isLoadingChapters) {
                  return const ListTile(
                    dense: true,
                    title: Center(child: CircularProgressIndicator()),
                  );
                }

                if (index >= _chapters.length) return null;

                final chapter = _chapters[index];
                final isCurrent = chapter.chapterOrder == _currentChapter;

                return ListTile(
                  dense: true,
                  title: Text(
                    chapter.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCurrent ? colorScheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.bold : null,
                    ),
                  ),
                  trailing: isCurrent
                      ? Icon(
                          Icons.play_arrow,
                          color: colorScheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () => _jumpToChapter(chapter.chapterOrder),
                );
              },
              childCount: _isLoadingChapters ? 1 : _chapters.length,
            ),
          ),

          // 底部间距
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

/// 统计信息项
class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
