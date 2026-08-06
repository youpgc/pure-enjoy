part of './favorites_screen.dart';

/// 收藏 状态 + 新增/编辑对话框逻辑抽为 mixin (膨胀修复), 避免 [_FavoritesScreenState] 超 400 行。
///
/// 关键约束：Dart 的 `mixin on State<T>` 只能访问声明在 `State<T>` 或 mixin 自身上的成员，
/// 无法看到被混入具体类里定义的私有字段/方法。`_showEditDialog` 依赖的 `_showError` /
/// `_userId` / `_loadFavorites` 以及它们依赖的状态字段一并放入 mixin，保证行为完全等价。
mixin _FavoritesScreenDialogMixin on State<FavoritesScreen> {
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();
  String? get _userId => AuthService.instance.currentUserId;
  void _showError(String message) {
    showSnackBar(context, message, isError: true);
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

    final isFirstPage = _offset == 0;

    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _favorites = [];
        _isLoading = true;
      });
    } else if (isFirstPage) {
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
            if (refresh || isFirstPage) {
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
          _showError('加载收藏失败，请稍后重试');
        }
      }
    }
  }
  Future<void> _showEditDialog({FavoriteModel? favorite}) async {
    // 确保字典已加载，避免下拉选项为空
    await DictService.instance.ensureInitialized();

    final isEditing = favorite != null;
    final titleController = TextEditingController(text: favorite?.title ?? '');
    final urlController = TextEditingController(text: favorite?.url ?? '');
    final descController = TextEditingController(text: favorite?.description ?? '');
    final tagsController = TextEditingController(
      text: favorite?.tags?.join(', ') ?? '',
    );
    String category = favorite?.category ?? 'other';
    bool isSaving = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final catItems = DictService.instance.getItemsSync('favorite_category');
          return AlertDialog(
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
                  initialValue: catItems.any((i) => i.code == category) ? category : null,
                  hint: const Text('请选择分类'),
                  decoration: const InputDecoration(labelText: '分类'),
                  items: catItems.map((item) {
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
                  EventBus.instance.fire(EventType.favoritesUpdated);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadFavorites(refresh: true);
                } catch (e) {
                  _showError('保存失败，请稍后重试');
                } finally {
                  if (mounted) setDialogState(() => isSaving = false);
                }
              },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEditing ? '保存' : '添加'),
            ),
          ],
        );
      },
      ),
    );
  }
}
