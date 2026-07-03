import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../widgets/common_widgets.dart';
import '../../../services/dict_service.dart';
import '../models/favorite_model.dart';

/// 收藏夹页面 - Supabase 数据同步
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _selectedCategory;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFavorites();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadFavorites();
      }
    }
  }

  Future<void> _loadFavorites({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _favorites = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _favorites = [];
        _isLoading = true;
      });
    } else if (_offset == 0) {
      // 1. 先加载本地缓存（仅在初始第一页时）
      final cached = await CacheHelper.instance.loadList(CacheHelper.keyFavorites);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _favorites = cached.map((e) => FavoriteModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoadingMore = true);
    }

    // 2. 从网络分页加载
    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      if (_selectedCategory != null) {
        filters['category'] = 'eq.$_selectedCategory';
      }

      final result = await ApiClient.get(
        'user_favorites',
        filters: filters,
        order: 'created_at.desc',
        limit: _limit,
        offset: _offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final items = data.map((e) => FavoriteModel.fromJson(e)).toList();
        // 仅第一页时保存缓存
        if (_offset == 0) {
          await CacheHelper.instance.saveList(CacheHelper.keyFavorites, data);
        }
        if (mounted) {
          setState(() {
            if (refresh) {
              _favorites = items;
            } else {
              _favorites.addAll(items);
            }
            _offset += _limit;
            _hasMore = items.length >= _limit;
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        // 如果已有缓存数据，静默失败不提示
        if (_favorites.isEmpty) {
          _showError('加载收藏失败: $e');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('无法打开链接');
      }
    } catch (e) {
      _showError('打开链接失败: $e');
    }
  }

  Future<void> _deleteFavorite(String id) async {
    final confirmed = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这个收藏吗？');

    if (confirmed == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'user_favorites',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          _loadFavorites(refresh: true);
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({FavoriteModel? favorite}) async {
    final isEditing = favorite != null;
    final titleController = TextEditingController(text: favorite?.title ?? '');
    final urlController = TextEditingController(text: favorite?.url ?? '');
    final descController = TextEditingController(text: favorite?.description ?? '');
    final tagsController = TextEditingController(
      text: favorite?.tags?.join(', ') ?? '',
    );
    String category = favorite?.category ?? 'other';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑收藏' : '添加收藏'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题 *',
                    hintText: '输入收藏标题',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '链接 URL',
                    hintText: 'https://...',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '输入描述',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: DictService.instance.getItemsSync('favorite_category').map((item) {
                    return DropdownMenuItem(
                      value: item.code,
                      child: Text(item.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: '标签（可选）',
                    hintText: '用逗号分隔多个标签',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isSaving ? null : () async {
                if (titleController.text.trim().isEmpty) {
                  _showError('请输入标题');
                  return;
                }

                final userId = _userId ?? 'local_user';

                // 解析标签
                final tagsText = tagsController.text.trim();
                final tags = tagsText.isNotEmpty
                    ? tagsText.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
                    : null;

                final newFavorite = FavoriteModel(
                  id: isEditing ? favorite.id : const Uuid().v4(),
                  userId: isEditing ? favorite.userId : userId,
                  title: titleController.text.trim(),
                  url: urlController.text.trim().isEmpty
                      ? null
                      : urlController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  category: category,
                  tags: tags,
                );

                setDialogState(() => isSaving = true);
                try {
                  if (isEditing) {
                    final result = await ApiClient.patchByFilter(
                      'user_favorites',
                      filters: {'id': 'eq.${favorite.id}'},
                      body: {
                        'title': newFavorite.title,
                        'url': newFavorite.url,
                        'description': newFavorite.description,
                        'category': newFavorite.category,
                        'tags': newFavorite.tags,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
                    }
                  } else {
                    final result = await ApiClient.post(
                      'user_favorites',
                      {
                        'id': newFavorite.id,
                        'user_id': newFavorite.userId,
                        'title': newFavorite.title,
                        'url': newFavorite.url,
                        'description': newFavorite.description,
                        'category': newFavorite.category,
                        'tags': newFavorite.tags,
                        'is_pinned': newFavorite.isPinned,
                        'created_at': DateTime.now().toUtc().toIso8601String(),
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}: ${result.errorMessage}');
                    }
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadFavorites(refresh: true);
                } catch (e) {
                  _showError('保存失败: $e');
                } finally {
                  if (mounted) setDialogState(() => isSaving = false);
                }
              },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (value) {
              setState(() => _selectedCategory = value);
              _loadFavorites(refresh: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              ...DictService.instance.getItemsSync('favorite_category').map((item) => PopupMenuItem(
                value: item.code,
                child: Text(item.label),
              )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _favorites.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadFavorites(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(
                          child: EmptyWidget(icon: Icons.bookmark_border, message: '暂无收藏'),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadFavorites(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _favorites.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final favorite = _favorites[index];
                    final categoryLabel = DictService.instance.getLabelOrDefault('favorite_category', favorite.category ?? '', defaultValue: favorite.category ?? '其他');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _openUrl(favorite.url),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  favorite.url != null ? Icons.link : Icons.bookmark,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      favorite.title,
                                      style: Theme.of(context).textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            categoryLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (favorite.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        favorite.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (favorite.tags != null && favorite.tags!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        children: favorite.tags!.take(3).map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colorScheme.onTertiaryContainer,
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                    if (favorite.url != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        favorite.url!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      DateTimeUtils.formatStandard(favorite.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.outline.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              EditDeletePopupMenu(
                                onEdit: () => _showEditDialog(favorite: favorite),
                                onDelete: () => _deleteFavorite(favorite.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
