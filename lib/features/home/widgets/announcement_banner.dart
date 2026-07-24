import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/announcement_service.dart';
import '../screens/announcement_list_screen.dart';

/// 首页公告横幅
///
/// 展示当前生效公告（最多 2 条预览），点击进入公告列表页。
/// 静默加载：加载过程中不展示；仅当加载完成且存在生效公告时才展示，避免打扰。
class AnnouncementBanner extends StatelessWidget {
  final List<Announcement> announcements;
  final bool isLoading;
  final VoidCallback onViewAll;

  const AnnouncementBanner({
    super.key,
    required this.announcements,
    this.isLoading = false,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    // 静默加载：加载中不展示；仅加载完成且有生效公告时展示
    if (isLoading || announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = announcements.take(2).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementListScreen()),
          ).then((_) => onViewAll());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: shown
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              if (a.priority == 'high')
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '重要',
                                    style: TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  '${a.typeLabel} · ${a.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
