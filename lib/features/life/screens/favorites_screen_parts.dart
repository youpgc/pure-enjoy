part of 'favorites_screen.dart';

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
