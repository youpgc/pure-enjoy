import 'package:flutter/material.dart';
import '../../../../core/widgets/paginated_list_mixin.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/point_record_model.dart';
import '../../services/point_service.dart';
import '../../services/point_service_utils.dart';
import './point_records_screen_content.dart';

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
  bool _isLoadingPoints = false;
  int _availablePoints = 0;
  bool _hasCheckedInToday = false;
  int _consecutiveCheckinDays = 0;

  @override
  int get pageSize => 20;

  @override
  void initState() {
    super.initState();
    initPagination();
    // 先读取本地缓存，立即展示上一次的积分值与连续签到天数，避免闪现 0
    _loadCachedPoints();
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

  /// 读取本地缓存的积分统计，进入页面时立即展示（避免闪现 0）
  Future<void> _loadCachedPoints() async {
    final cached = await PointService.instance.getCachedPointsStats();
    if (mounted) {
      setState(() {
        _availablePoints = (cached['availablePoints'] as int?) ?? 0;
        _hasCheckedInToday = (cached['hasCheckedInToday'] as bool?) ?? false;
        _consecutiveCheckinDays = (cached['consecutiveCheckinDays'] as int?) ?? 0;
      });
    }
  }

  /// 加载可用积分、签到状态和连续签到天数
  ///
  /// 加载期间显示 loading 指示，完成后将最新值写回本地缓存。
  Future<void> _loadAvailablePoints() async {
    if (mounted) setState(() => _isLoadingPoints = true);
    final points = await PointService.instance.getAvailablePoints();
    final checkedIn = await PointService.instance.hasCheckedInToday();
    final streak = await PointService.instance.getConsecutiveCheckinDays();
    if (mounted) {
      setState(() {
        _availablePoints = points;
        _hasCheckedInToday = checkedIn;
        _consecutiveCheckinDays = streak;
        _isLoadingPoints = false;
      });
      // 写回缓存，供下次进入页面立即展示（存北京日期键，由 lastCheckinDate 与今日比较得出签到状态）
      await PointService.instance.cachePointsStats(
        availablePoints: points,
        consecutiveCheckinDays: streak,
        lastCheckinDate: checkedIn ? beijingDateKey(DateTime.now()) : null,
      );
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

      if (result['success'] == true) {
        // 直接用签到结果刷新连续天数与今日已签到状态，立即生效
        final streak = result['streak'] as int? ?? _consecutiveCheckinDays;
        setState(() {
          _consecutiveCheckinDays = streak;
          _hasCheckedInToday = true;
        });
        showSnackBar(context, result['message'] ?? '签到成功');
        _loadRecords(refresh: true);
      } else {
        showSnackBar(context, result['message'] ?? '签到失败');
      }
      // 重新拉取最新积分并写回缓存（无论成功失败都刷新）
      await _loadAvailablePoints();
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
      availablePoints: _availablePoints,
      isLoadingPoints: _isLoadingPoints,
      hasCheckedInToday: _hasCheckedInToday,
      isCheckingIn: _isCheckingIn,
      consecutiveCheckinDays: _consecutiveCheckinDays,
      records: _records,
      isLoading: _isLoading,
      scrollController: scrollController,
      loadMoreIndicator: buildLoadMoreIndicator(),
      onShowRules: _showRulesDialog,
      onRefresh: () async {
        await _loadAvailablePoints();
        await _loadRecords(refresh: true);
      },
      onCheckin: _handleCheckin,
    );
  }
}
