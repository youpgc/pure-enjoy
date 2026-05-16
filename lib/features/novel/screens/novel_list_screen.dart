import 'package:flutter/material.dart';
import '../../../services/database_service.dart';
import '../../../services/supabase_service.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';

/// 小说列表页面
class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  List<NovelModel> _novels = [];
  List<Map<String, dynamic>> _userNovels = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadNovels();
  }

  Future<void> _loadNovels() async {
    setState(() => _isLoading = true);

    try {
      // 加载所有公共小说
      final novels = await DatabaseService.instance.getNovels();

      // 根据分类筛选
      final filteredNovels = _selectedCategory == 'all'
          ? novels
          : novels.where((n) => n.category == _selectedCategory).toList();

      // 加载用户书架
      List<Map<String, dynamic>> userNovels = [];
      final userId = _userId;
      if (userId != null) {
        userNovels = await DatabaseService.instance.getUserNovels(userId);
      }

      setState(() {
        _novels = filteredNovels;
        _userNovels = userNovels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _addToBookshelf(NovelModel novel) async {
    final userId = _userId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    try {
      await DatabaseService.instance.addToBookshelf(userId, novel.id);
      await _loadNovels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到书架')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  void _openNovel(NovelModel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(novel: novel),
      ),
    );
  }

  List<NovelModel> get _readingNovels {
    final bookshelfNovelIds = _userNovels.map((un) => un['novel_id'] as String).toSet();
    return _novels.where((n) => bookshelfNovelIds.contains(n.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('小说'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 搜索功能
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNovels,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 阅读中的小说
                  if (_readingNovels.isNotEmpty) ...[
                    Text(
                      '继续阅读',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _readingNovels.length,
                        itemBuilder: (context, index) {
                          final novel = _readingNovels[index];
                          return _NovelCard(
                            novel: novel,
                            onTap: () => _openNovel(novel),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 分类筛选
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: '全部',
                          isSelected: _selectedCategory == 'all',
                          onTap: () {
                            setState(() => _selectedCategory = 'all');
                            _loadNovels();
                          },
                        ),
                        _CategoryChip(
                          label: '玄幻',
                          isSelected: _selectedCategory == '玄幻',
                          onTap: () {
                            setState(() => _selectedCategory = '玄幻');
                            _loadNovels();
                          },
                        ),
                        _CategoryChip(
                          label: '都市',
                          isSelected: _selectedCategory == '都市',
                          onTap: () {
                            setState(() => _selectedCategory = '都市');
                            _loadNovels();
                          },
                        ),
                        _CategoryChip(
                          label: '言情',
                          isSelected: _selectedCategory == '言情',
                          onTap: () {
                            setState(() => _selectedCategory = '言情');
                            _loadNovels();
                          },
                        ),
                        _CategoryChip(
                          label: '科幻',
                          isSelected: _selectedCategory == '科幻',
                          onTap: () {
                            setState(() => _selectedCategory = '科幻');
                            _loadNovels();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 小说列表
                  Text(
                    '全部小说',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _novels.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无小说',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _novels.length,
                          itemBuilder: (context, index) {
                            final novel = _novels[index];
                            final isInBookshelf = _userNovels.any((un) => un['novel_id'] == novel.id);
                            return _NovelCard(
                              novel: novel,
                              onTap: () => _openNovel(novel),
                              onAddToBookshelf: isInBookshelf ? null : () => _addToBookshelf(novel),
                              isInBookshelf: isInBookshelf,
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  final NovelModel novel;
  final VoidCallback onTap;
  final VoidCallback? onAddToBookshelf;
  final bool isInBookshelf;

  const _NovelCard({
    required this.novel,
    required this.onTap,
    this.onAddToBookshelf,
    this.isInBookshelf = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHighest,
                    child: novel.cover != null
                        ? Image.network(
                            novel.cover!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.book,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.book,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (onAddToBookshelf != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: onAddToBookshelf,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isInBookshelf)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已加入',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 信息
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author ?? '佚名',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                    ),
                    const Spacer(),
                    Text(
                      '${novel.chapterCount} 章',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
