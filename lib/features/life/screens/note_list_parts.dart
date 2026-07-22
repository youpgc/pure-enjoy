part of 'note_list_screen.dart';

/// 笔记搜索框
class _NoteSearchBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _NoteSearchBar({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: '搜索笔记...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}

/// 笔记列表空状态
class _NoteEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _NoteEmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyWidget(icon: Icons.note_alt_outlined, message: '暂无笔记'),
          ),
        ],
      ),
    );
  }
}

/// 笔记网格单项卡片
class _NoteGridItem extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteGridItem({
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      note.content ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isPinned)
                    Container(
                      width: 4,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateTimeUtils.formatStandard(note.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.outline.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (note.isPinned)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.push_pin,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
