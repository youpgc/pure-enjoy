import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/dict_service.dart';

/// 获取心情表情（从字典服务）
String _getMoodEmoji(String mood) {
  final emoji = DictService.instance.getEmoji('mood_type', mood);
  return emoji.isNotEmpty ? emoji : '😐';
}

/// 获取心情标签（从字典服务）
String _getMoodLabel(String mood) {
  return DictService.instance.getLabelOrDefault('mood_type', mood, defaultValue: mood);
}

/// {@template mood_statistics_content}
/// [MoodStatisticsScreen] 的主体内容（从超长 _buildBody 抽取，便于维护）。
/// 仅读取传入字段，不持有状态。
/// {@endtemplate}
class MoodStatisticsContent extends StatelessWidget {
  /// {@macro mood_statistics_content}
  const MoodStatisticsContent({
    super.key,
    required this.diaries,
    required this.isLoading,
    required this.error,
  });

  final List<Map<String, dynamic>> diaries;
  final bool isLoading;
  final String error;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (error.isNotEmpty) {
      return Center(child: Text(error));
    }
    if (diaries.isEmpty) {
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
    return _MoodStatisticsLoaded(diaries: diaries);
  }
}

/// 已加载数据的主区域。
class _MoodStatisticsLoaded extends StatelessWidget {
  const _MoodStatisticsLoaded({required this.diaries});

  final List<Map<String, dynamic>> diaries;

  @override
  Widget build(BuildContext context) {
    // 按心情统计
    final moodMap = <String, int>{};
    for (var diary in diaries) {
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

    final total = diaries.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MoodOverviewCard(total: total, topMood: moods.isNotEmpty ? moods.first.key : null),
          const SizedBox(height: 24),
          Text(
            '心情分布',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _MoodPieChart(moods: moods, colors: colors, total: total),
          const SizedBox(height: 16),
          _MoodList(moods: moods, colors: colors, total: total),
        ],
      ),
    );
  }
}

/// 统计概览卡片。
class _MoodOverviewCard extends StatelessWidget {
  const _MoodOverviewCard({required this.total, required this.topMood});

  final int total;
  final String? topMood;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  topMood != null ? _getMoodEmoji(topMood!) : '😊',
                  style: const TextStyle(fontSize: 32),
                ),
                const Text('最常见'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 心情分布饼图。
class _MoodPieChart extends StatelessWidget {
  const _MoodPieChart({
    required this.moods,
    required this.colors,
    required this.total,
  });

  final List<MapEntry<String, int>> moods;
  final List<Color> colors;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}

/// 心情列表。
class _MoodList extends StatelessWidget {
  const _MoodList({required this.moods, required this.colors, required this.total});

  final List<MapEntry<String, int>> moods;
  final List<Color> colors;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: moods.asMap().entries.map((entry) {
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
                  backgroundColor: colors[index % colors.length].withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(colors[index % colors.length]),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
