import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'expense_list_page.dart';
import 'mood_diary_page.dart';
import 'weight_record_page.dart';
import 'note_list_page.dart';

/// 功能页面（生活记录聚合页）
class LifePage extends StatelessWidget {
  const LifePage({super.key});

  @override
  Widget build(BuildContext context) {
    final functions = [
      _LifeFunction(
        icon: Icons.account_balance_wallet,
        label: '消费记录',
        description: '记录每日消费，掌握支出情况',
        color: const Color(0xFFFF6B6B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExpenseListPage()),
        ),
      ),
      _LifeFunction(
        icon: Icons.emoji_emotions,
        label: '心情日记',
        description: '记录心情变化，留下美好回忆',
        color: const Color(0xFFFFBE0B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MoodDiaryPage()),
        ),
      ),
      _LifeFunction(
        icon: Icons.monitor_weight,
        label: '体重记录',
        description: '追踪体重变化，关注健康',
        color: const Color(0xFF4ECDC4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeightRecordPage()),
        ),
      ),
      _LifeFunction(
        icon: Icons.note_alt,
        label: '笔记本',
        description: '随时记录想法，整理思绪',
        color: const Color(0xFF6C63FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NoteListPage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活记录'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: functions.length,
        itemBuilder: (context, index) {
          final func = functions[index];
          return _buildFunctionCard(context, func);
        },
      ),
    );
  }

  Widget _buildFunctionCard(BuildContext context, _LifeFunction func) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: func.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(func.icon, color: func.color, size: 28),
        ),
        title: Text(
          func.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            func.description,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppTheme.textHint,
        ),
        onTap: func.onTap,
      ),
    );
  }
}

class _LifeFunction {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  _LifeFunction({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });
}
