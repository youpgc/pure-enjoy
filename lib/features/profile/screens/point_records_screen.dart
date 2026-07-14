import 'package:flutter/material.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../utils/date_time_utils.dart';
import '../models/point_record_model.dart';
import '../services/point_service.dart';

/// 积分记录页面
class PointRecordsScreen extends StatefulWidget {
  const PointRecordsScreen({super.key});

  @override
  State<PointRecordsScreen> createState() => _PointRecordsScreenState();
}

class _PointRecordsScreenState extends State<PointRecordsScreen> with PaginatedListMixin {
  final List<PointRecord> _records = [];
  bool _isLoading = false;
  bool _isCheckingIn = false;
  int _availablePoints = 0;
  bool _hasCheckedInToday = false;
  int _consecutiveCheckinDays = 0;

  @override
  int get pageSize => 20;

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadAvailablePoints();
    _loadRecords(refresh: true);
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadRecords();
  }

  /// 加载可用积分、打卡状态和连续签到天数
  Future<void> _loadAvailablePoints() async {
    final points = await PointService.instance.getAvailablePoints();
    final checkedIn = await PointService.instance.hasCheckedInToday();
    final streak = await PointService.instance.getConsecutiveCheckinDays();
    if (mounted) {
      setState(() {
        _availablePoints = points;
        _hasCheckedInToday = checkedIn;
        _consecutiveCheckinDays = streak;
      });
    }
  }

  /// 加载积分记录
  Future<void> _loadRecords({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      resetPagination();
    }

    // 如果是触底加载，使用 beginLoadMore
    if (!refresh && !beginLoadMore()) return;

    setState(() => _isLoading = true);

    final (limit, offset) = paginationParams;
    final newRecords = await PointService.instance.getRecords(
      page: offset ~/ limit + 1,
      pageSize: limit,
      statusFilter: 'active',
    );

    if (mounted) {
      setState(() {
        if (refresh) {
          _records.clear();
        }
        _records.addAll(newRecords);
        onPaginationDataLoaded(newRecords.length);
        _isLoading = false;
      });

      // 如果还有更多数据但内容未填满屏幕，自动加载下一页
      if (hasMore && newRecords.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final sc = scrollController;
          if (!sc.hasClients) return;
          if (sc.position.maxScrollExtent <= 200) {
            onLoadMore();
          }
        });
      }
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
  /// 积分类型映射（与数据库 point_records.type 和后台 POINT_TYPE_MAP 一致）
  /// 标准类型：checkin / earn / spend / adjust / admin_adjust
  /// 兼容历史类型：admin_recharge（已废弃，映射到 admin_adjust）
  _PointTypeInfo _getTypeInfo(String type) {
    switch (type) {
      case 'checkin':
        return _PointTypeInfo(
          icon: Icons.check_circle_outline,
          label: '签到',
          color: Colors.green,
        );
      case 'earn':
        return _PointTypeInfo(
          icon: Icons.add_circle_outline,
          label: '获得',
          color: Colors.green,
        );
      case 'spend':
        return _PointTypeInfo(
          icon: Icons.remove_circle_outline,
          label: '消费',
          color: Colors.red,
        );
      case 'adjust':
        return _PointTypeInfo(
          icon: Icons.swap_horiz,
          label: '调整',
          color: Colors.blue,
        );
      case 'admin_adjust':
      case 'admin_recharge': // 兼容历史数据
        return _PointTypeInfo(
          icon: Icons.admin_panel_settings_outlined,
          label: '管理员调整',
          color: Colors.purple,
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
          controller: scrollController,
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
                        onPressed: (_hasCheckedInToday || _isCheckingIn)
                            ? null
                            : _handleCheckin,
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
                              Icon(
                                _hasCheckedInToday
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                              ),
                              const SizedBox(width: 4),
                              Text(_hasCheckedInToday ? '已打卡' : '打卡'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 连续签到天数（为0时不显示）
            if (_consecutiveCheckinDays > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已连续签到 $_consecutiveCheckinDays 天',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
            if (_isLoading && _records.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            buildLoadMoreIndicator(),
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
