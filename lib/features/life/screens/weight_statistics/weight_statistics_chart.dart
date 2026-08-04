part of './weight_statistics_content.dart';

/// 体重曲线图。
class _WeightChart extends StatelessWidget {
  const _WeightChart({
    required this.sortedRecords,
    required this.spots,
  });

  final List<Map<String, dynamic>> sortedRecords;
  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
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
              color: colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: spots.length < 20,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.1),
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
    );
  }
}
