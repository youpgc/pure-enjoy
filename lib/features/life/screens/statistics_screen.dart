import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';

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

      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/expenses?user_id=eq.$userId'
          '&date=gte.${DateFormat('yyyy-MM-dd').format(startOfMonth)}'
          '&date=lte.${DateFormat('yyyy-MM-dd').format(endOfMonth)}'
          '&select=*&order=date.desc',
        ),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJson(response.body);
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
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
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
                          color: Colors.red,
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
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colors[index % colors.length],
                radius: 12,
              ),
              title: Text(category.key),
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
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/weight_records?user_id=eq.$userId'
          '&select=*&order=date.desc&limit=30',
        ),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJson(response.body);
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
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '最低',
                  value: '${minWeight.toStringAsFixed(1)} kg',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  title: '最高',
                  value: '${maxWeight.toStringAsFixed(1)} kg',
                  color: Colors.orange,
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
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: spots.length < 20,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
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

  // 心情表情映射
  static const moodEmojis = {
    'happy': '😊',
    'excited': '🤩',
    'calm': '😌',
    'neutral': '😐',
    'sad': '😢',
    'anxious': '😰',
    'angry': '😠',
    'tired': '😴',
  };

  static const moodLabels = {
    'happy': '开心',
    'excited': '兴奋',
    'calm': '平静',
    'neutral': '一般',
    'sad': '难过',
    'anxious': '焦虑',
    'angry': '生气',
    'tired': '疲惫',
  };

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
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/mood_diaries?user_id=eq.$userId'
          '&select=*&order=date.desc&limit=30',
        ),
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJson(response.body);
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
      Colors.amber,
      Colors.orange,
      Colors.lightBlue,
      Colors.grey,
      Colors.blueGrey,
      Colors.purple,
      Colors.red,
      Colors.brown,
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
                              color: Colors.blue,
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
                            ? moodEmojis[moods.first.key] ?? '😊'
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
                moodEmojis[mood.key] ?? '😐',
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(moodLabels[mood.key] ?? mood.key),
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
