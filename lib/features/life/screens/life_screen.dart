import 'package:flutter/material.dart';
import 'expense_list_screen.dart';
import 'mood_diary_screen.dart';
import 'note_list_screen.dart';
import 'weight_record_screen.dart';
import 'reminders_screen.dart';
import 'habits_screen.dart';
import 'anniversaries_screen.dart';
import 'favorites_screen.dart';
import 'feedback_list_screen.dart';
import 'feedback_submit_screen.dart';
import 'statistics_screen.dart';

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildFeatureCard(
            context,
            '记账本',
            Icons.account_balance_wallet,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '心情日记',
            Icons.sentiment_satisfied,
            Colors.amber,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoodDiaryScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '备忘录',
            Icons.note,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteListScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '体重记录',
            Icons.monitor_weight,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeightRecordScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '提醒事项',
            Icons.alarm,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '习惯打卡',
            Icons.check_circle,
            Colors.teal,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitsScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '纪念日',
            Icons.favorite,
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnniversariesScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '收藏夹',
            Icons.bookmark,
            Colors.indigo,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '我的反馈',
            Icons.feedback,
            Colors.cyan,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackListScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '提交反馈',
            Icons.add_comment,
            Colors.deepOrange,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackSubmitScreen()),
            ),
          ),
          _buildFeatureCard(
            context,
            '统计',
            Icons.bar_chart,
            Colors.pink,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
