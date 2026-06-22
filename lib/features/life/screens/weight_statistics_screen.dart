import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// 体重统计页面
class WeightStatisticsScreen extends StatefulWidget {
  const WeightStatisticsScreen({super.key});

  @override
  State<WeightStatisticsScreen> createState() => _WeightStatisticsScreenState();
}

class _WeightStatisticsScreenState extends State<WeightStatisticsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体重统计'),
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

    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_weight_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无体重记录',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
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
