import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
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
  int _availablePoints = 0;

  @override
  void initState() {
    super.initState();
    _loadAvailablePoints();
    _loadRecords();
  }

  /// 加载可用积分
  Future<void> _loadAvailablePoints() async {
    final points = await PointService.instance.getAvailablePoints();
    if (mounted) {
      setState(() => _availablePoints = points);
    }
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
      });
      _loadAvailablePoints();

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
  /// 注意：point_type 字典类型目前未在后台配置，暂使用硬编码映射
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

  /// 获取过期状态标签信息
  _ExpiryInfo _getExpiryInfo(PointRecord record) {
    if (record.status == 'expired') {
      return _ExpiryInfo(
        label: '已过期',
        color: Colors.grey,
      );
    }
    if (record.expiresAt != null) {
      final now = DateTime.now();
      final diff = record.expiresAt!.difference(now);
      if (diff.inDays <= 30 && diff.inDays >= 0) {
        return _ExpiryInfo(
          label: '即将过期',
          color: Colors.orange,
        );
      }
    }
    return _ExpiryInfo(
      label: '有效',
      color: Colors.green,
    );
  }

  /// 显示积分规则说明
  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('积分规则说明'),
        content: const Text(
          '1. 积分有效期为180天，从获取当天开始计算\n'
          '2. 积分过期后将自动失效，不可继续使用\n'
          '3. 距离过期30天时，系统将发送提醒通知\n'
          '4. 每日0:00系统自动更新积分过期状态',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAvailablePoints();
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
                              '$_availablePoints',
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
                              '可用积分',
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
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              final expiryInfo = _getExpiryInfo(record);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: typeInfo.color.withValues(alpha: 0.1),
                  child: Icon(
                    typeInfo.icon,
                    color: typeInfo.color,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Text(typeInfo.label),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: expiryInfo.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        expiryInfo.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: expiryInfo.color,
                        ),
                      ),
                    ),
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
                      DateTimeUtils.formatStandard(record.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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

/// 过期状态信息
class _ExpiryInfo {
  final String label;
  final Color color;

  _ExpiryInfo({
    required this.label,
    required this.color,
  });
}
