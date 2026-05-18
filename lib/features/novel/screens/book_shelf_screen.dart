import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/supabase_service.dart';
import '../../../config.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';

/// 书架页面 - 显示用户已加入书架的小说列表
class BookShelfScreen extends StatefulWidget {
  const BookShelfScreen({super.key});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> {
  List<Map<String, dynamic>> _bookshelfItems = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, reading, completed, paused

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  /// 从 Supabase 加载书架数据（book_shelves + novels 联合查询）
  Future<void> _loadBookshelf() async {
    setState(() => _isLoading = true);

    try {
      final userId = _userId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 联合查询 book_shelves 和 novels 表
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/book_shelves?user_id=eq.$userId&select=id,novel_id,status,current_chapter,last_read_at,novels(id,title,author,cover_url,category,status,chapter_count)',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _bookshelfItems = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载书架失败: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书架出错: $e')),
        );
      }
    }
  }

  /// 从书架移除小说
  Future<void> _removeFromBookshelf(String bookshelfId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/book_shelves?id=eq.$bookshelfId',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadBookshelf();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已从书架移除')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('移除失败: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除出错: $e')),
        );
      }
    }
  }

  /// 更新阅读状态
  Future<void> _updateStatus(String bookshelfId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/book_shelves?id=eq.$bookshelfId',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'status': newStatus,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadBookshelf();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新状态失败: $e')),
        );
      }
    }
  }

  /// 获取筛选后的列表
  List<Map<String, dynamic>> get _filteredItems {
    if (_filterStatus == 'all') return _bookshelfItems;
    return _bookshelfItems
        .where((item) => item['status'] == _filterStatus)
        .toList();
  }

  /// 获取状态显示文本
  String _getStatusText(String? status) {
    switch (status) {
      case 'reading':
        return '在读';
      case 'completed':
        return '已读完';
      case 'paused':
        return '暂停';
      default:
        return '在读';
    }
  }

  /// 获取状态颜色
  Color _getStatusColor(String? status, ColorScheme colorScheme) {
    switch (status) {
      case 'reading':
        return colorScheme.primary;
      case 'completed':
        return Colors.green;
      case 'paused':
        return Colors.orange;
      default:
        return colorScheme.primary;
    }
  }

  /// 打开小说阅读
  void _openNovel(Map<String, dynamic> item) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    if (novelData == null) return;

    final novel = NovelModel(
      id: novelData['id'] as String? ?? '',
      title: novelData['title'] as String? ?? '',
      author: novelData['author'] as String?,
      cover: novelData['cover_url'] as String?,
      category: novelData['category'] as String?,
      status: novelData['status'] as String?,
      chapterCount: novelData['chapter_count'] as int? ?? 0,
      createdAt: novelData['created_at'] != null
          ? DateTime.parse(novelData['created_at'] as String)
          : DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(novel: novel),
      ),
    );
  }

  /// 显示状态选择底部弹窗
  void _showStatusBottomSheet(BuildContext context, Map<String, dynamic> item) {
    final bookshelfId = item['id'] as String;
    final currentStatus = item['status'] as String? ?? 'reading';

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '更改阅读状态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories),
              title: const Text('在读'),
              trailing: currentStatus == 'reading'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (currentStatus != 'reading') {
                  _updateStatus(bookshelfId, 'reading');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('已读完'),
              trailing: currentStatus == 'completed'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (currentStatus != 'completed') {
                  _updateStatus(bookshelfId, 'completed');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('暂停'),
              trailing: currentStatus == 'paused'
                  ? const Icon(Icons.check, color: Colors.orange)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (currentStatus != 'paused') {
                  _updateStatus(bookshelfId, 'paused');
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmRemove(bookshelfId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 确认移出书架
  void _confirmRemove(String bookshelfId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移除'),
        content: const Text('确定要将这本小说从书架移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFromBookshelf(bookshelfId);
            },
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  /// 格式化最后阅读时间
  String _formatLastRead(String? lastReadAt) {
    if (lastReadAt == null) return '';
    try {
      final dateTime = DateTime.parse(lastReadAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dateTime.month}-${dateTime.day}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          if (_userId != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // 跳转到小说列表页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NovelListScreen()),
                );
              },
              tooltip: '添加小说',
            ),
        ],
      ),
      body: _userId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '请先登录后查看书架',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _bookshelfItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '书架空空如也',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '去小说列表添加你喜欢的小说吧',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NovelListScreen()),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('去添加'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // 状态筛选栏
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _FilterChip(
                                label: '全部',
                                count: _bookshelfItems.length,
                                isSelected: _filterStatus == 'all',
                                onTap: () =>
                                    setState(() => _filterStatus = 'all'),
                              ),
                              _FilterChip(
                                label: '在读',
                                count: _bookshelfItems
                                    .where((i) => i['status'] == 'reading')
                                    .length,
                                isSelected: _filterStatus == 'reading',
                                onTap: () => setState(
                                    () => _filterStatus = 'reading'),
                              ),
                              _FilterChip(
                                label: '已读完',
                                count: _bookshelfItems
                                    .where((i) => i['status'] == 'completed')
                                    .length,
                                isSelected: _filterStatus == 'completed',
                                onTap: () => setState(
                                    () => _filterStatus = 'completed'),
                              ),
                              _FilterChip(
                                label: '暂停',
                                count: _bookshelfItems
                                    .where((i) => i['status'] == 'paused')
                                    .length,
                                isSelected: _filterStatus == 'paused',
                                onTap: () =>
                                    setState(() => _filterStatus = 'paused'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // 书架列表
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadBookshelf,
                            child: _filteredItems.isEmpty
                                ? ListView(
                                    children: [
                                      SizedBox(
                                        height: 300,
                                        child: Center(
                                          child: Text(
                                            '该分类下暂无小说',
                                            style: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    itemCount: _filteredItems.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _filteredItems[index];
                                      return _BookshelfItem(
                                        item: item,
                                        colorScheme: colorScheme,
                                        getStatusText: _getStatusText,
                                        getStatusColor: _getStatusColor,
                                        formatLastRead: _formatLastRead,
                                        onTap: () => _openNovel(item),
                                        onLongPress: () =>
                                            _showStatusBottomSheet(
                                                context, item),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

/// 书架列表项
class _BookshelfItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final ColorScheme colorScheme;
  final String Function(String?) getStatusText;
  final Color Function(String?, ColorScheme) getStatusColor;
  final String Function(String?) formatLastRead;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookshelfItem({
    required this.item,
    required this.colorScheme,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatLastRead,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final novelData = item['novels'] as Map<String, dynamic>?;
    final status = item['status'] as String?;
    final currentChapter = item['current_chapter'] as int? ?? 0;
    final lastReadAt = item['last_read_at'] as String?;

    if (novelData == null) return const SizedBox.shrink();

    final title = novelData['title'] as String? ?? '未知';
    final author = novelData['author'] as String? ?? '佚名';
    final coverUrl = novelData['cover_url'] as String?;
    final chapterCount = novelData['chapter_count'] as int? ?? 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 76,
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.book,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.book,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    author,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getStatusColor(status, colorScheme)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          getStatusText(status),
                          style: TextStyle(
                            fontSize: 11,
                            color: getStatusColor(status, colorScheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 阅读进度
                      Expanded(
                        child: Text(
                          '读到第 $currentChapter / $chapterCount 章',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (lastReadAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '上次阅读: ${formatLastRead(lastReadAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 继续阅读按钮
            if (status == 'reading')
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// 筛选标签
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
