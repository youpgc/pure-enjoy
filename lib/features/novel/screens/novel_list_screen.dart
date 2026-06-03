import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../models/novel_model.dart';
import 'novel_detail_screen.dart';
import 'book_shelf_screen.dart';

/// 小说列表页面
class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  List<NovelModel> _novels = [];
  List<NovelModel> _allNovels = [];
  List<Map<String, dynamic>> _userNovels = [];
  bool _isLoading = true;
  String _selectedCategory = '全部';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// 分类列表（从字典服务获取）
  List<String> get _categories {
    final items = DictService.instance.getItemsSync(DictService.novelCategory);
    return ['全部', ...items.map((item) => item.label)];
  }

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadNovels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNovels() async {
    setState(() => _isLoading = true);

    try {
      // 从 Supabase 加载已发布的小说
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/novels?user_id=is.null&select=*&order=created_at.desc&limit=100',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      List<NovelModel> novels = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        novels = data.map((json) => NovelModel.fromJson(json)).toList();
      }

      // 加载用户书架
      List<Map<String, dynamic>> userNovels = [];
      final userId = _userId;
      if (userId != null) {
        try {
          final shelfResponse = await http.get(
            Uri.parse(
              '${AppConfig.supabaseUrl}/rest/v1/user_novels?user_id=eq.$userId&select=id,novel_id,is_collected,last_chapter,last_read_at',
            ),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            },
          );
          if (shelfResponse.statusCode == 200) {
            userNovels = jsonDecode(shelfResponse.body).cast<Map<String, dynamic>>();
          }
        } catch (e) {
          debugPrint('加载用户书架数据失败: $e');
        }
      }

      setState(() {
        _allNovels = novels;
        _novels = _applyFilters(novels);
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

  /// 应用分类和搜索筛选
  List<NovelModel> _applyFilters(List<NovelModel> novels) {
    var filtered = novels;

    // 分类筛选
    if (_selectedCategory != '全部') {
      filtered = filtered.where((n) => n.category == _selectedCategory).toList();
    }

    // 搜索筛选
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(query) ||
            (n.author?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// 切换分类
  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _novels = _applyFilters(_allNovels);
    });
  }

  /// 搜索
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _novels = _applyFilters(_allNovels);
    });
  }

  /// 添加到书架
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
      final response = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_novels'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'user_id': userId,
          'novel_id': novel.id,
          'progress': 0,
          'last_chapter': 0,
          'is_collected': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadNovels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已添加到书架')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  /// 打开小说详情页
  void _openNovelDetail(NovelModel novel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    );
  }

  /// 获取正在阅读的小说
  List<NovelModel> get _readingNovels {
    final bookshelfNovelIds = _userNovels.map((un) => un['novel_id'] as String).toSet();
    return _allNovels.where((n) => bookshelfNovelIds.contains(n.id)).toList();
  }

  /// 显示搜索对话框
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索小说'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入小说名或作者名',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('搜索'),
          ),
        ],
      ),
    );
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
            onPressed: _showSearchDialog,
            tooltip: '搜索',
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
                  // 搜索提示
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '搜索: "$_searchQuery" (${_novels.length} 结果)',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                  // 阅读中的小说
                  if (_readingNovels.isNotEmpty && _searchQuery.isEmpty) ...[
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
                            onTap: () => _openNovelDetail(novel),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 分类筛选
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _CategoryChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () => _onCategoryChanged(category),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 小说列表
                  Text(
                    _selectedCategory == '全部' ? '全部小说' : _selectedCategory,
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
                                  _searchQuery.isNotEmpty ? '没有找到匹配的小说' : '暂无小说',
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
                              onTap: () => _openNovelDetail(novel),
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
