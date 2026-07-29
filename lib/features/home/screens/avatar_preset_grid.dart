part of 'avatar_preset_page.dart';

const int _kGridCount = 24; // 网格头像数量（4 列 × 6 行）
const int _kPresetColumns = 4; // 网格列数

/// 从 DiceBear URL 取出 seed（按种子而非完整 URL 跟踪选中，使切色调不丢失选择）
String _seedOf(String url) {
  try {
    return Uri.parse(url).queryParameters['seed'] ?? '';
  } catch (_) {
    return '';
  }
}

/// 头像网格（原 [_AvatarPresetPageState._buildGrid]）
/// 点选通过 [onSelectSeed] 上抛（内部已用 [_seedOf] 提取种子），状态留在父 State。
class _AvatarPresetGrid extends StatelessWidget {
  final List<String> presets;
  final String? selectedSeed;
  final Color currentColor;
  final String? backgroundColor;
  final ColorScheme colorScheme;
  final ValueChanged<String> onSelectSeed;
  const _AvatarPresetGrid({
    required this.presets,
    required this.selectedSeed,
    required this.currentColor,
    required this.backgroundColor,
    required this.colorScheme,
    required this.onSelectSeed,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = backgroundColor != null;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kPresetColumns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 1,
      ),
      itemCount: presets.length,
      itemBuilder: (_, index) {
        final item = presets[index];
        final selected = selectedSeed != null && _seedOf(item) == selectedSeed;
        final tintColor = hasBg ? currentColor : colorScheme.primaryContainer;
        return GestureDetector(
          key: ValueKey<String>(item),
          onTap: () => onSelectSeed(_seedOf(item)),
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
                  url: item,
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
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
