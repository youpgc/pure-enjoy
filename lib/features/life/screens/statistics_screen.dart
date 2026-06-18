import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// 统计图表页面
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据统计'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '消费'),
            Tab(text: '体重'),
            Tab(text: '心情'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ExpenseStatistics(),
          _WeightStatistics(),
          _MoodStatistics(),
        ],
      ),
    );
  }
}

/// 消费统计
class _ExpenseStatistics extends StatefulWidget {
  const _ExpenseStatistics();

  @override
  State<_ExpenseStatistics> createState() => _ExpenseStatisticsState();
}

class _ExpenseStatisticsState extends State<_ExpenseStatistics> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _error = '';

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
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final result = await ApiClient.get(
        'expenses',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${DateFormat('yyyy-MM-dd').format(startOfMonth)},date.lte.${DateFormat('yyyy-MM-dd').format(endOfMonth)})',
        },
        order: 'date.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _expenses = data.cast<Map<String, dynamic>>();
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

  List<dynamic> _parseJson(String body) {
    if (body.isEmpty) return [];
    return jsonDecode(body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_expenses.isEmpty) {
      return const Center(child: Text('本月暂无消费记录'));
    }

    // 按分类统计
    final categoryMap = <String, double>{};
    double total = 0;
    for (var expense in _expenses) {
      final category = expense['category'] ?? '其他';
      final amount = (expense['amount'] ?? 0).toDouble();
      categoryMap[category] = (categoryMap[category] ?? 0) + amount;
      total += amount;
    }

    final categories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      AppTheme.success,
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.primary,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 本月总消费
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '本月消费',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${_expenses.length} 笔消费',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 分类饼图
          Text(
            '消费分类',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: categories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final percentage = total > 0 ? (category.value / total * 100) : 0;
                  return PieChartSectionData(
                    value: category.value,
                    title: '${percentage.toStringAsFixed(1)}%',
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

          // 分类列表
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final categoryLabel = DictService.instance.getLabelOrDefault(DictService.expenseCategory, category.key, defaultValue: category.key);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colors[index % colors.length],
                radius: 12,
              ),
              title: Text(categoryLabel),
              trailing: Text(
                '¥${category.value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 体重统计
class _WeightStatistics extends StatefulWidget {
  const _WeightStatistics();

  @override
  State<_WeightStatistics> createState() => _WeightStatisticsState();
}

class _WeightStatisticsState extends State<_WeightStatistics> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String _error = '';

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
      // 获取最近30条记录
      final result = await ApiClient.get(
        'weight_records',
        filters: {'user_id': 'eq.$userId'},
        order: 'date.desc',
        limit: 30,
      );

      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _records = data.cast<Map<String, dynamic>>();
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

  List<dynamic> _parseJson(String body) {
    if (body.isEmpty) return [];
    return jsonDecode(body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_records.isEmpty) {
      return const Center(child: Text('暂无体重记录'));
    }

    // 反转数据按日期升序排列
    final sortedRecords = _records.reversed.toList();

    // 提取数据点
    final spots = sortedRecords.asMap().entries.map((entry) {
      final index = entry.key;
      final record = entry.value;
      return FlSpot(index.toDouble(), (record['weight'] ?? 0).toDouble());
    }).toList();

    // 计算统计信息
    final weights = sortedRecords.map((r) => (r['weight'] ?? 0).toDouble()).toList();
    final currentWeight = weights.isNotEmpty ? weights.last : 0.0;
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计卡片
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '当前',
                  value: '${currentWeight.toStringAsFixed(1)} kg',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '最低',
                  value: '${minWeight.toStringAsFixed(1)} kg',
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '最高',
                  value: '${maxWeight.toStringAsFixed(1)} kg',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 体重曲线图
          Text(
            '体重变化曲线',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (sortedRecords.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedRecords.length) {
                          final date = sortedRecords[index]['date'];
                          if (date != null) {
                            return Text(
                              DateFormat('MM/dd').format(DateTime.parse(date.toString())),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: spots.length < 20,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.x.toInt();
                        if (index >= 0 && index < sortedRecords.length) {
                          final date = sortedRecords[index]['date'];
                          return LineTooltipItem(
                            '${DateFormat('MM/dd').format(DateTime.parse(date.toString()))}\n${spot.y.toStringAsFixed(1)} kg',
                            const TextStyle(color: Colors.white),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 最近记录列表
          Text(
            '最近记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...sortedRecords.reversed.take(10).map((record) {
            final date = DateTime.parse(record['date'].toString());
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.monitor_weight)),
              title: Text('${record['weight']} kg'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
              trailing: record['bmi'] != null
                  ? Text('BMI: ${(record['bmi']).toStringAsFixed(1)}')
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

/// 心情统计
class _MoodStatistics extends StatefulWidget {
  const _MoodStatistics();

  @override
  State<_MoodStatistics> createState() => _MoodStatisticsState();
}

class _MoodStatisticsState extends State<_MoodStatistics> {
  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;
  String _error = '';

  /// 获取心情表情（从字典服务）
  String _getMoodEmoji(String mood) {
    final emoji = DictService.instance.getEmoji(DictService.moodType, mood);
    return emoji.isNotEmpty ? emoji : '😐';
  }

  /// 获取心情标签（从字典服务）
  String _getMoodLabel(String mood) {
    return DictService.instance.getLabelOrDefault(DictService.moodType, mood, defaultValue: mood);
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

  List<dynamic> _parseJson(String body) {
    if (body.isEmpty) return [];
    return jsonDecode(body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }

    if (_diaries.isEmpty) {
      return const Center(child: Text('暂无心情记录'));
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

/// 统计卡片组件
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
