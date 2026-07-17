part of 'life_screen.dart';

/// 单个 shimmer 占位卡片
class _LifeShimmerCard extends StatelessWidget {
  final Color baseColor;

  const _LifeShimmerCard(this.baseColor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: baseColor.withValues(alpha: 0.3),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 60,
                height: 10,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 加载中的占位卡片
class _LifeLoadingCards extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LifeLoadingCards({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          _LifeShimmerCard(colorScheme.primaryContainer),
          const SizedBox(width: 10),
          _LifeShimmerCard(colorScheme.tertiaryContainer),
        ],
      ),
    );
  }
}

/// 最新记录卡片组件
class _LatestRecordCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color backgroundColor;
  final String? summary;
  final String? description;
  final String? date;
  final VoidCallback onTap;

  const _LatestRecordCard({
    required this.icon,
    required this.title,
    required this.backgroundColor,
    this.summary,
    this.description,
    this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: backgroundColor,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：图标 + 模块名
              Row(
                children: [
                  Icon(icon, size: 20, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              // 摘要信息
              if (summary != null)
                Text(
                  summary!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  '暂无记录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                ),
              // 描述（如有）
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // 时间
              if (date != null && date!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  date!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 功能项数据类
class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Function(BuildContext) onTap;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

/// 功能入口卡片
class _LifeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LifeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
