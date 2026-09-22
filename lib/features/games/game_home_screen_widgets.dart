part of 'game_home_screen.dart';

// 【文件拆分 2026-09-22】单文件超 500 行红线，入口卡片与说明分段两个私有组件
// 拆至此（逻辑零变更），与主文件同库、共享其 import。
/// 说明弹窗里的一段
class _GuideSectionView extends StatelessWidget {
  final GameGuideSection section;
  const _GuideSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (section.icon != null) ...<Widget>[
                Icon(section.icon, size: 18, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
              ],
              Text(section.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(section.body, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// 主界面入口行
class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback? onTap;
  final bool primary;
  final bool enabled;

  const _EntryTile({
    required this.icon,
    required this.label,
    required this.desc,
    this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary
                          ? AppTheme.primaryOrange.withAlpha(26)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: primary ? AppTheme.primaryOrange : null, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.neutral600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.neutral500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
