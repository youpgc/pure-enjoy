import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';

/// 心情统计页面
class MoodStatisticsScreen extends StatefulWidget {
  const MoodStatisticsScreen({super.key});

  @override
  State<MoodStatisticsScreen> createState() => _MoodStatisticsScreenState();
}

class _MoodStatisticsScreenState extends State<MoodStatisticsScreen> {
  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;
  String _error = '';

  /// 获取心情表情（从字典服务）
  String _getMoodEmoji(String mood) {
    final emoji = DictService.instance.getEmoji('mood_type', mood);
    return emoji.isNotEmpty ? emoji : '😐';
  }

  /// 获取心情标签（从字典服务）
  String _getMoodLabel(String mood) {
    return DictService.instance.getLabelOrDefault('mood_type', mood, defaultValue: mood);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = AuthService.instance.currentUserId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '请先登录';
      });
      return;
    }

    try {
      // 获取最近30天记录
      final result = await ApiClient.get(
        'mood_diaries',
        filters: {'user_id': 'eq.$userId'},
        order: 'date.desc',
        limit: 30,
      );

      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _diaries = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情统计'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_diaries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mood_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无心情记录',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 按心情统计
    final moodMap = <String, int>{};
    for (var diary in _diaries) {
      final mood = diary['mood'] ?? 'neutral';
      moodMap[mood] = (moodMap[mood] ?? 0) + 1;
    }

    final moods = moodMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.onSurfaceVariant,
      Theme.of(context).colorScheme.outline,
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.outline,
    ];

    final total = _diaries.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计概览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$total',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Text('记录天数'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        moods.isNotEmpty
                            ? _getMoodEmoji(moods.first.key)
                            : '😊',
                        style: const TextStyle(fontSize: 32),
                      ),
                      const Text('最常见'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 心情分布饼图
          Text(
            '心情分布',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: moods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mood = entry.value;
                  final percentage = (mood.value / total * 100);
                  return PieChartSectionData(
                    value: mood.value.toDouble(),
                    title: '${percentage.toStringAsFixed(0)}%',
                    color: colors[index % colors.length],
                    radius: 80,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 心情列表
          ...moods.asMap().entries.map((entry) {
            final index = entry.key;
            final mood = entry.value;
            return ListTile(
              leading: Text(
                _getMoodEmoji(mood.key),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(_getMoodLabel(mood.key)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${mood.value}天'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      value: mood.value / total,
                      backgroundColor: colors[index % colors.length].withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(colors[index % colors.length]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
