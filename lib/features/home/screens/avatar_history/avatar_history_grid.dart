part of './avatar_history_page.dart';

/// 历史头像网格可视高度：最多展示 [_kHistoryRows] 行（行×列），超出由网格内部滚动。
const double _kHistoryCellSpacing = 18;
const int _kHistoryColumns = 4;
const int _kHistoryRows = 3;

double _avatarHistoryGridHeight(BuildContext context, int count) {
  if (count <= 0) return 0;
  final w = MediaQuery.of(context).size.width;
  final cellW = (w - 32 - (_kHistoryColumns - 1) * _kHistoryCellSpacing) / _kHistoryColumns;
  var rows = (count / _kHistoryColumns).ceil();
  if (rows > _kHistoryRows) rows = _kHistoryRows;
  return rows * cellW + (rows - 1) * _kHistoryCellSpacing + 16 + 24; // 纵向 padding 16+24
}

/// 标题（原 [_AvatarHistoryViewState._buildTitle]）
class _AvatarHistoryTitle extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;
  const _AvatarHistoryTitle({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

/// 空状态文案（原 [_AvatarHistoryViewState._buildEmpty]）
class _AvatarHistoryEmpty extends StatelessWidget {
  final String type;
  final ColorScheme colorScheme;
  const _AvatarHistoryEmpty({required this.type, required this.colorScheme});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          type == 'upload'
              ? '还没有上传头像历史，上传过的头像会自动出现在这里。'
              : '还没有历史头像，去「选择预设头像」用过的头像会自动出现在这里。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

/// 历史头像网格（原 [_AvatarHistoryViewState._buildGridSection]）
/// 选中高亮、点选、删除均通过显式回调上抛，状态留在父 State。
class _AvatarHistoryGrid extends StatelessWidget {
  final List<AvatarHistoryItem> items;
  final bool manageMode;
  final String? selectedId;
  final ColorScheme colorScheme;
  final ValueChanged<AvatarHistoryItem> onSelect;
  final ValueChanged<AvatarHistoryItem> onDelete;
  const _AvatarHistoryGrid({
    required this.items,
    required this.manageMode,
    required this.selectedId,
    required this.colorScheme,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _avatarHistoryGridHeight(context, items.length),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kHistoryColumns,
            mainAxisSpacing: _kHistoryCellSpacing,
            crossAxisSpacing: _kHistoryCellSpacing,
            childAspectRatio: 1,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            final selected = !manageMode && item.id == selectedId;
            // 按记录自身背景色渲染（透明风格也能正确显示底色），无背景则回退主题色
            final itemBg =
                item.backgroundColor ?? parseDiceBearUrl(item.avatarUrl)?.bg;
            final tintColor = itemBg != null
                ? avatarHexToColor(itemBg)
                : colorScheme.primaryContainer;
            return GestureDetector(
              key: ValueKey<String>(item.id),
              onTap: manageMode ? null : () => onSelect(item),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.18)
                          : null,
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: selected ? 3 : 0,
                      ),
                    ),
                    child: cachedAvatarCircle(
                      url: item.avatarUrl,
                      radius: 31,
                      tint: tintColor,
                      colorScheme: colorScheme,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (manageMode)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => onDelete(item),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}
