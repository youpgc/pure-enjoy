import 'package:flutter/material.dart';
import 'expense_list_screen.dart';
import 'mood_diary_screen.dart';
import 'note_list_screen.dart';
import 'weight_record_screen.dart';
import 'favorites_screen.dart';
import 'reminders_screen.dart';
import 'habits_screen.dart';

/// 生活模块主页面 - 一行两项布局
class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final features = [
      _FeatureItem(
        icon: Icons.account_balance_wallet,
        title: '记账',
        subtitle: '记录每日支出',
        color: colorScheme.primaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.mood,
        title: '心情日记',
        subtitle: '记录每天的心情',
        color: colorScheme.secondaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MoodDiaryScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.note,
        title: '笔记',
        subtitle: '记录想法和灵感',
        color: colorScheme.tertiaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteListScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.monitor_weight,
        title: '体重记录',
        subtitle: '追踪体重变化',
        color: colorScheme.errorContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeightRecordScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.bookmark,
        title: '我的收藏',
        subtitle: '管理收藏链接',
        color: colorScheme.primaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.notifications_active,
        title: '提醒事项',
        subtitle: '日程和待办',
        color: colorScheme.secondaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          );
        },
      ),
      _FeatureItem(
        icon: Icons.track_changes,
        title: '习惯打卡',
        subtitle: '培养好习惯',
        color: colorScheme.tertiaryContainer,
        onTap: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HabitsScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 使用 GridView 实现一行两项
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 一行两项
              crossAxisSpacing: 12, // 横向间距
              mainAxisSpacing: 12, // 纵向间距
              childAspectRatio: 1.3, // 宽高比
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              return _LifeFeatureCard(
                icon: features[index].icon,
                title: features[index].title,
                subtitle: features[index].subtitle,
                color: features[index].color,
                onTap: () => features[index].onTap(context),
              );
            },
          ),
        ],
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
