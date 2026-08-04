part of './favorites_screen.dart';

/// 收藏列表单项卡片
class _FavoriteListItem extends StatelessWidget {
  final FavoriteModel favorite;
  final String categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FavoriteListItem({
    required this.favorite,
    required this.categoryLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
                  ),
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
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 收藏新增/编辑对话框逻辑抽为 mixin (膨胀修复), 避免 [_FavoritesScreenState] 超 400 行。
mixin _FavoritesScreenDialogMixin on State<FavoritesScreen> {
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
