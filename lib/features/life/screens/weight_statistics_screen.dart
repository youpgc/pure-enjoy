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
  DateTime _startMonth = DateTime.now();
  DateTime _endMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startMonth = DateTime.now();
    _endMonth = DateTime.now();
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
      final startOfRange = DateTime(_startMonth.year, _startMonth.month, 1);
      final firstOfNextMonth = DateTime(_endMonth.year, _endMonth.month + 1, 1);

      final result = await ApiClient.get(
        'weight_records',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${DateFormat('yyyy-MM-dd').format(startOfRange)},date.lt.${DateFormat('yyyy-MM-dd').format(firstOfNextMonth)})',
        },
        order: 'date.desc',
        limit: 500,
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

  Future<void> _pickStartMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择起始月份',
    );
    if (picked != null) {
      final newStart = DateTime(picked.year, picked.month);
      final maxEnd = DateTime(newStart.year, newStart.month + 6, 0);
      setState(() {
        _startMonth = newStart;
        if (_endMonth.isBefore(_startMonth)) {
          _endMonth = _startMonth;
        } else if (_endMonth.isAfter(maxEnd)) {
          _endMonth = maxEnd;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  Future<void> _pickEndMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择结束月份',
    );
    if (picked != null) {
      final newEnd = DateTime(picked.year, picked.month);
      final minStart = DateTime(newEnd.year, newEnd.month - 5, 1);
      setState(() {
        _endMonth = newEnd;
        if (_startMonth.isAfter(_endMonth)) {
          _startMonth = _endMonth;
        } else if (_startMonth.isBefore(minStart)) {
          _startMonth = minStart;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  String get _rangeText {
    final sameYear = _startMonth.year == _endMonth.year;
    if (_startMonth.year == _endMonth.year && _startMonth.month == _endMonth.month) {
      return '${_startMonth.year}年${_startMonth.month}月';
    }
    if (sameYear) {
      return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.month}月';
    }
    return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.year}年${_endMonth.month}月';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体重统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '选择时间区间',
            onPressed: () async {
              await _pickStartMonth();
            },
          ),
        ],
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.monitor_weight_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '$_rangeText暂无体重记录',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickStartMonth,
                  icon: const Icon(Icons.date_range),
                  label: Text('${_startMonth.year}-${_startMonth.month.toString().padLeft(2, '0')}'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickEndMonth,
                  icon: const Icon(Icons.date_range),
                  label: Text('${_endMonth.year}-${_endMonth.month.toString().padLeft(2, '0')}'),
                ),
              ],
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
          // 时间区间标题与选择
          Center(
            child: Column(
              children: [
                Text(
                  _rangeText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickStartMonth,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text('${_startMonth.year}-${_startMonth.month.toString().padLeft(2, '0')}'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('至'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickEndMonth,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text('${_endMonth.year}-${_endMonth.month.toString().padLeft(2, '0')}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                gridData: const FlGridData(
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
      color: color.withValues(alpha: 0.1),
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
