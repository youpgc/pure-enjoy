import 'package:flutter/material.dart';
import 'expense_list_screen.dart';
import 'mood_diary_screen.dart';
import 'note_list_screen.dart';
import 'weight_record_screen.dart';
import 'favorites_screen.dart';
import 'reminders_screen.dart';
import 'habits_screen.dart';

/// 生活模块主页面
class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 功能卡片
          _LifeFeatureCard(
            icon: Icons.account_balance_wallet,
            title: '记账',
            subtitle: '记录每日支出',
            color: colorScheme.primaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.mood,
            title: '心情日记',
            subtitle: '记录每天的心情',
            color: colorScheme.secondaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoodDiaryScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.note,
            title: '笔记',
            subtitle: '记录想法和灵感',
            color: colorScheme.tertiaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteListScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.monitor_weight,
            title: '体重记录',
            subtitle: '追踪体重变化',
            color: colorScheme.errorContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeightRecordScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.bookmark,
            title: '我的收藏',
            subtitle: '管理收藏链接和内容',
            color: colorScheme.primaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.notifications_active,
            title: '提醒事项',
            subtitle: '日程安排和待办提醒',
            color: colorScheme.secondaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _LifeFeatureCard(
            icon: Icons.track_changes,
            title: '习惯打卡',
            subtitle: '培养好习惯，记录每一天',
            color: colorScheme.tertiaryContainer,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HabitsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
