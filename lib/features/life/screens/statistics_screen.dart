import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      // 并行加载各类统计数据
      final results = await Future.wait([
        ApiClient.get(
          'expenses',
          filters: {'user_id': 'eq.$_userId'},
          select: 'amount',
        ),
        ApiClient.get(
          'mood_records',
          filters: {'user_id': 'eq.$_userId'},
          select: 'mood_level',
        ),
        ApiClient.get(
          'habits',
          filters: {'user_id': 'eq.$_userId'},
          select: 'check_in_count',
        ),
        ApiClient.get(
          'notes',
          filters: {'user_id': 'eq.$_userId'},
          select: 'id',
        ),
      ]);

      final expensesResult = results[0];
      final moodResult = results[1];
      final habitsResult = results[2];
      final notesResult = results[3];

      double totalExpense = 0;
      if (expensesResult.isSuccess) {
        for (final item in expensesResult.data!) {
          totalExpense += (item['amount'] as num?)?.toDouble() ?? 0;
        }
      }

      double avgMood = 0;
      if (moodResult.isSuccess && moodResult.data!.isNotEmpty) {
        double totalMood = 0;
        for (final item in moodResult.data!) {
          totalMood += (item['mood_level'] as num?)?.toDouble() ?? 0;
        }
        avgMood = totalMood / moodResult.data!.length;
      }

      int totalCheckIns = 0;
      if (habitsResult.isSuccess) {
        for (final item in habitsResult.data!) {
          totalCheckIns += (item['check_in_count'] as num?)?.toInt() ?? 0;
        }
      }

      setState(() {
        _statistics = {
          'totalExpense': totalExpense,
          'avgMood': avgMood,
          'totalCheckIns': totalCheckIns,
          'notesCount': notesResult.isSuccess ? notesResult.data!.length : 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatCard(
                    '总支出',
                    '¥${_statistics['totalExpense']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.account_balance_wallet,
                    Colors.red,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    '平均心情',
                    '${_statistics['avgMood']?.toStringAsFixed(1) ?? '0.0'}',
                    Icons.sentiment_satisfied,
                    Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    '总打卡次数',
                    '${_statistics['totalCheckIns'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    '笔记数量',
                    '${_statistics['notesCount'] ?? 0}',
                    Icons.note,
                    Colors.blue,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
