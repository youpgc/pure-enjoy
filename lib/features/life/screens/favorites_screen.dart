import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
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
  String? _selectedCategory;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) {
        setState(() {
          _favorites = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/user_favorites?user_id=eq.$userId&select=*&order=created_at.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final items = data.map((e) => FavoriteModel.fromJson(e)).toList();
        setState(() {
          _favorites = items;
          _isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
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
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/user_favorites?id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          _loadFavorites();
        } else {
          throw Exception('HTTP ${response.statusCode}');
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
                    labelText: '标签（可选）',
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

                try {
                  // 构建请求头
                  final headers = {
                    'apikey': SupabaseConfig.anonKey,
                    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  };

                  if (isEditing) {
                    final response = await http.patch(
                      Uri.parse('${SupabaseConfig.url}/rest/v1/user_favorites?id=eq.${favorite.id}'),
                      headers: headers,
                      body: jsonEncode({
                        'title': newFavorite.title,
                        'url': newFavorite.url,
                        'description': newFavorite.description,
                        'category': newFavorite.category,
                        'tags': newFavorite.tags,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      }),
                    );
                    if (response.statusCode != 200 && response.statusCode != 204) {
                      throw Exception('HTTP ${response.statusCode}: ${response.body}');
                    }
                  } else {
                    // 新增：手动构建 JSON，确保字段正确
                    final body = jsonEncode({
                      'id': newFavorite.id,
                      'user_id': newFavorite.userId,
                      'title': newFavorite.title,
                      'url': newFavorite.url,
                      'description': newFavorite.description,
                      'category': newFavorite.category,
                      'tags': newFavorite.tags,
                      'is_pinned': newFavorite.isPinned,
                      'created_at': DateTime.now().toUtc().toIso8601String(),
                    });
                    debugPrint('📤 新增收藏请求体: $body');
                    
                    final response = await http.post(
                      Uri.parse('${SupabaseConfig.url}/rest/v1/user_favorites'),
                      headers: headers,
                      body: body,
                    );
                    debugPrint('📥 新增收藏响应: ${response.statusCode} - ${response.body}');
                    if (response.statusCode != 201 && response.statusCode != 200) {
                      throw Exception('HTTP ${response.statusCode}: ${response.body}');
                    }
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
                    final category = FavoriteCategory.values.firstWhere(
                      (c) => c.name == favorite.category,
                      orElse: () => FavoriteCategory.other,
                    );

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
                                            category.label,
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
                                        color: colorScheme.outline.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _showEditDialog(favorite: favorite);
                                      break;
                                    case 'delete':
                                      _deleteFavorite(favorite.id);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
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
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
