import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../models/point_record_model.dart';
import '../services/point_service.dart';

/// 积分记录页面
class PointRecordsScreen extends StatefulWidget {
  const PointRecordsScreen({super.key});

  @override
  State<PointRecordsScreen> createState() => _PointRecordsScreenState();
}

class _PointRecordsScreenState extends State<PointRecordsScreen> {
  final List<PointRecord> _records = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isCheckingIn = false;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _totalPoints = PointService.instance.getTotalPoints();
    _loadRecords();
  }

  /// 加载积分记录
  Future<void> _loadRecords({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    final newRecords = await PointService.instance.getRecords(
      page: _currentPage,
      pageSize: 20,
    );

    if (mounted) {
      setState(() {
        if (refresh) {
          _records.clear();
        }
        _records.addAll(newRecords);
        _hasMore = newRecords.length >= 20;
        _isLoading = false;
      });
    }
  }

  /// 打卡
  Future<void> _handleCheckin() async {
    if (_isCheckingIn) return;

    setState(() => _isCheckingIn = true);

    final result = await PointService.instance.checkin();

    if (mounted) {
      setState(() {
        _isCheckingIn = false;
        _totalPoints = PointService.instance.getTotalPoints();
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '打卡成功'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRecords(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '打卡失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 获取类型对应的图标和颜色
  _PointTypeInfo _getTypeInfo(String type) {
    switch (type) {
      case 'checkin':
        return _PointTypeInfo(
          icon: Icons.check_circle_outline,
          label: '打卡',
          color: Colors.green,
        );
      case 'recharge':
        return _PointTypeInfo(
          icon: Icons.add_circle_outline,
          label: '充值',
          color: Colors.blue,
        );
      case 'deduct':
        return _PointTypeInfo(
          icon: Icons.remove_circle_outline,
          label: '抵扣',
          color: Colors.orange,
        );
      case 'admin_recharge':
        return _PointTypeInfo(
          icon: Icons.add_circle_outline,
          label: '后台充值',
          color: Colors.blue,
        );
      case 'admin_deduct':
        return _PointTypeInfo(
          icon: Icons.remove_circle_outline,
          label: '后台抵扣',
          color: Colors.orange,
        );
      default:
        return _PointTypeInfo(
          icon: Icons.help_outline,
          label: type,
          color: Colors.grey,
        );
    }
  }

  /// 格式化时间
  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分记录'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _totalPoints = PointService.instance.getTotalPoints();
          await _loadRecords(refresh: true);
        },
        child: ListView(
          children: [
            // 总积分卡片
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_totalPoints',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '总积分',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: _isCheckingIn ? null : _handleCheckin,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isCheckingIn)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else ...[
                              const Icon(Icons.check_circle_outline),
                              const SizedBox(width: 4),
                              const Text('打卡'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 积分记录列表
            if (_records.isEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.monetization_on_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无积分记录',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ..._records.map((record) {
              final typeInfo = _getTypeInfo(record.type);
              final isPositive = record.amount > 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: typeInfo.color.withOpacity(0.1),
                  child: Icon(
                    typeInfo.icon,
                    color: typeInfo.color,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Text(typeInfo.label),
                    const Spacer(),
                    Text(
                      isPositive
                          ? '+${record.amount}'
                          : '${record.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.remark != null && record.remark!.isNotEmpty)
                      Text(
                        record.remark!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      _formatTime(record.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // 加载更多指示器
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_hasMore && _records.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '没有更多了',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 积分类型信息
class _PointTypeInfo {
  final IconData icon;
  final String label;
  final Color color;

  _PointTypeInfo({
    required this.icon,
    required this.label,
    required this.color,
  });
}
