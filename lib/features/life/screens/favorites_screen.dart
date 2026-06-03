import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/cache_helper.dart';
import '../models/favorite_model.dart';

/// 收藏页面 - Supabase 数据同步
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    await _loadCache();
    await _loadFavorites();
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyFavorites);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _favorites = cached.map((e) => FavoriteModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/favorites?user_id=eq.$userId&select=*&order=created_at.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final favorites = data.map((e) => FavoriteModel.fromJson(e)).toList();

        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });

        // 写入缓存
        await CacheHelper.instance.saveList(
          CacheHelper.keyFavorites,
          favorites.map((f) => f.toJson()).toList(),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _addFavorite(FavoriteModel favorite) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/favorites'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode(favorite.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadFavorites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _updateFavorite(FavoriteModel favorite) async {
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/favorites?id=eq.${favorite.id}'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'title': favorite.title,
          'url': favorite.url,
          'category': favorite.category,
          'note': favorite.note,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadFavorites();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteFavorite(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条收藏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/favorites?id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadFavorites();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  void _showFavoriteForm([FavoriteModel? favorite]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FavoriteForm(
        userId: _userId ?? 'local_user',
        favorite: favorite,
        onSave: (newFavorite) {
          Navigator.pop(context);
          if (favorite != null) {
            _updateFavorite(newFavorite);
          } else {
            _addFavorite(newFavorite);
          }
        },
      ),
    );
  }

  List<FavoriteModel> get _filteredFavorites {
    if (_selectedCategory == 'all') return _favorites;
    return _favorites.where((f) => f.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
      ),
      body: Column(
        children: [
          // 分类筛选
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: '全部',
                  isSelected: _selectedCategory == 'all',
                  onTap: () => setState(() => _selectedCategory = 'all'),
                ),
                ...FavoriteCategory.values.map((cat) => _CategoryChip(
                  label: cat.label,
                  isSelected: _selectedCategory == cat.name,
                  onTap: () => setState(() => _selectedCategory = cat.name),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 收藏列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFavorites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无收藏',
                              style: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFavorites,
                        child: ListView.builder(
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
                              child: ListTile(
                                leading: Icon(category.icon),
                                title: Text(favorite.title),
                                subtitle: favorite.note != null && favorite.note!.isNotEmpty
                                    ? Text(favorite.note!)
                                    : Text(favorite.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        _showFavoriteForm(favorite);
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
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFavoriteForm(),
        child: const Icon(Icons.add),
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

class _FavoriteForm extends StatefulWidget {
  final String userId;
  final FavoriteModel? favorite;
  final Function(FavoriteModel) onSave;

  const _FavoriteForm({required this.userId, this.favorite, required this.onSave});

  @override
  State<_FavoriteForm> createState() => _FavoriteFormState();
}

class _FavoriteFormState extends State<_FavoriteForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  late FavoriteCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    final favorite = widget.favorite;
    _titleController.text = favorite?.title ?? '';
    _urlController.text = favorite?.url ?? '';
    _noteController.text = favorite?.note ?? '';
    _selectedCategory = favorite != null
        ? FavoriteCategory.values.firstWhere(
            (c) => c.name == favorite.category,
            orElse: () => FavoriteCategory.other,
          )
        : FavoriteCategory.other;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newFavorite = FavoriteModel(
      id: widget.favorite?.id ?? const Uuid().v4(),
      userId: widget.userId,
      title: _titleController.text,
      url: _urlController.text,
      category: _selectedCategory.name,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    widget.onSave(newFavorite);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '添加收藏',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入标题';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '链接',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入链接';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text('分类', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: FavoriteCategory.values.map((cat) => ChoiceChip(
                label: Text(cat.label),
                selected: _selectedCategory == cat,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
