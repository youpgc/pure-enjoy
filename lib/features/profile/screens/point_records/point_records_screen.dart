import 'package:flutter/material.dart';
import '../../../../core/widgets/paginated_list_mixin.dart';
import '../../models/point_record_model.dart';
import '../../services/point_service.dart';
import './point_records_screen_content.dart';

/// 积分明细页面（从原积分记录页拆分，仅展示积分流水列表；签到/补签见 CheckinScreen）。
class PointRecordsScreen extends StatefulWidget {
  const PointRecordsScreen({super.key});

  @override
  State<PointRecordsScreen> createState() => _PointRecordsScreenState();
}

class _PointRecordsScreenState extends State<PointRecordsScreen>
    with PaginatedListMixin {
  final List<PointRecord> _records = [];
  bool _isLoading = false;
  int _expiringPoints = 0;

  @override
  int get pageSize => 20;

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadExpiringPoints();
    _loadRecords(refresh: true);
  }

  /// 加载 30 天内即将过期的积分数（用于头部提示，独立于列表分页）
  Future<void> _loadExpiringPoints() async {
    final count = await PointService.instance.getExpiringSoonPoints();
    if (mounted) setState(() => _expiringPoints = count);
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
      // 拉全量记录（含已过期），使「已过期 / 即将过期」标签生效；不再仅限 active
      statusFilter: null,
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
    return PointRecordsContent(
      records: _records,
      isLoading: _isLoading,
      expiringPoints: _expiringPoints,
      scrollController: scrollController,
      loadMoreIndicator: buildLoadMoreIndicator(),
      onShowRules: _showRulesDialog,
      onRefresh: () => _loadRecords(refresh: true),
    );
  }
}
