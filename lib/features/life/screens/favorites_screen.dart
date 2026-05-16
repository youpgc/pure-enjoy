import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/favorite_model.dart';
import '../../../services/database_service.dart';

/// 收藏夹页面
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseService _db = DatabaseService();
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final items = await _db.getFavorites();
      setState(() {
        _favorites = items..sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载收藏失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  Future<void> _togglePin(FavoriteModel favorite) async {
    try {
      final updated = favorite.copyWith(
        isPinned: !favorite.isPinned,
        updatedAt: DateTime.now(),
      );
      await _db.updateFavorite(updated);
      _loadFavorites();
    } catch (e) {
      _showError('操作失败: $e');
    }
  }

  Future<void> _deleteFavorite(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个收藏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteFavorite(id);
        _loadFavorites();
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({FavoriteModel? favorite}) async {
    final isEditing = favorite != null;
    final titleController = TextEditingController(text: favorite?.title ?? '');
    final urlController = TextEditingController(text: favorite?.url ?? '');
    final tagsController = TextEditingController(
      text: favorite?.tags?.join(', ') ?? '',
    );
    String category = favorite?.category ?? 'other';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: FavoriteCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c.name,
                      child: Text(c.label),
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
                    labelText: '标签',
                    hintText: '用逗号分隔多个标签',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  _showError('请输入标题');
                  return;
                }

                final tags = tagsController.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                final newFavorite = FavoriteModel(
                  id: isEditing ? favorite.id : const Uuid().v4(),
                  title: titleController.text.trim(),
                  url: urlController.text.trim().isEmpty
                      ? null
                      : urlController.text.trim(),
                  category: category,
                  tags: tags.isEmpty ? null : tags,
                  isPinned: favorite?.isPinned ?? false,
                  createdAt: isEditing ? favorite.createdAt : DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  if (isEditing) {
                    await _db.updateFavorite(newFavorite);
                  } else {
                    await _db.insertFavorite(newFavorite);
                  }
                  Navigator.pop(context);
                  _loadFavorites();
                } catch (e) {
                  _showError('保存失败: $e');
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  List<FavoriteModel> get _filteredFavorites {
    if (_selectedCategory == null) return _favorites;
    return _favorites.where((f) => f.category == _selectedCategory).toList();
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
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              ...FavoriteCategory.values.map((c) => PopupMenuItem(
                value: c.name,
                child: Text(c.label),
              )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredFavorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收藏',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredFavorites.length,
                  itemBuilder: (context, index) {
                    final favorite = _filteredFavorites[index];
                    return _FavoriteCard(
                      favorite: favorite,
                      onTap: () => _openUrl(favorite.url),
                      onEdit: () => _showEditDialog(favorite: favorite),
                      onDelete: () => _deleteFavorite(favorite.id),
                      onTogglePin: () => _togglePin(favorite),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteModel favorite;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _FavoriteCard({
    required this.favorite,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final category = FavoriteCategory.values.firstWhere(
      (c) => c.name == favorite.category,
      orElse: () => FavoriteCategory.other,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
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
                    Row(
                      children: [
                        if (favorite.isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        if (favorite.isPinned) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            favorite.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                            category.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (favorite.tags != null && favorite.tags!.isNotEmpty)
                          ...favorite.tags!.take(2).map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          )),
                      ],
                    ),
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
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'pin':
                      onTogglePin();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          favorite.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(favorite.isPinned ? '取消置顶' : '置顶'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
