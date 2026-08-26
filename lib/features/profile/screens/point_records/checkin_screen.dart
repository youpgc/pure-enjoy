import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/point_service.dart';
import '../../services/point_service_utils.dart';
import '../point_mall/point_mall_screen.dart';
import './point_records_screen.dart';
import './checkin_calendar_card.dart';

/// 积分签到页面（从原积分记录页拆分）。
///
/// 承载打卡日历卡（签到 / 补签 / 连续天数 / 补签卡），不含积分明细列表。
/// 右上角入口：积分记录（明细）、积分商城。
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _availablePoints = 0;
  bool _isLoadingPoints = false;
  bool _hasCheckedInToday = false;
  bool _isCheckingIn = false;
  int _consecutiveCheckinDays = 0;
  late DateTime _displayMonth;
  late DateTime _earliestDataMonth;
  Set<String> _checkedDates = {};
  bool _isLoadingCalendar = false;
  int _makeupCardCount = 0;

  @override
  void initState() {
    super.initState();
    // 初始化展示月份为当前北京月份，避免 late 字段未初始化导致首屏崩溃
    _displayMonth = DateTime(beijingToday().year, beijingToday().month, 1);
    // 向前翻月的下界：默认等同于当前月，待查询最早签到月份后修正
    _earliestDataMonth = _displayMonth;
    _loadCachedPoints();
    _loadAvailablePoints();
    _loadMakeupCardCount();
    _loadCheckedDates();
    _loadEarliestDataMonth();
  }

  /// 加载最早有签到数据的月份（约束向前翻月：更早的月份无数据则不再允许切换）
  Future<void> _loadEarliestDataMonth() async {
    final earliest = await PointService.instance.getEarliestCheckinMonth();
    if (mounted) {
      setState(() {
        _earliestDataMonth = earliest ?? _displayMonth;
      });
    }
  }

  /// 读取本地缓存的积分统计，进入页面时立即展示（避免闪现 0）
  Future<void> _loadCachedPoints() async {
    final cached = await PointService.instance.getCachedPointsStats();
    if (mounted) {
      setState(() {
        _availablePoints = (cached['availablePoints'] as int?) ?? 0;
        _hasCheckedInToday = (cached['hasCheckedInToday'] as bool?) ?? false;
        _consecutiveCheckinDays =
            (cached['consecutiveCheckinDays'] as int?) ?? 0;
      });
    }
  }

  /// 加载可用积分、签到状态和连续签到天数
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
      await PointService.instance.cachePointsStats(
        availablePoints: points,
        consecutiveCheckinDays: streak,
        lastCheckinDate: checkedIn ? beijingDateKey(DateTime.now()) : null,
      );
    }
  }

  /// 加载指定月份的已签到日期（供日历展示；只读查询）
  Future<void> _loadCheckedDates() async {
    if (mounted) setState(() => _isLoadingCalendar = true);
    final dates =
        await PointService.instance.getCheckinDatesInMonth(_displayMonth);
    if (mounted) {
      setState(() {
        _checkedDates = dates;
        _isLoadingCalendar = false;
      });
    }
  }

  /// 切换展示月份（delta = -1 上一月 / +1 下一月）。
  /// 不允许跳到未来月份；也不允许翻到早于最早签到数据的月份（更早月份无数据）。
  void _changeMonth(int delta) {
    final today = beijingToday();
    var y = _displayMonth.year;
    var m = _displayMonth.month + delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    if (y > today.year || (y == today.year && m > today.month)) return;
    if (y < _earliestDataMonth.year ||
        (y == _earliestDataMonth.year && m < _earliestDataMonth.month)) {
      return;
    }
    setState(() => _displayMonth = DateTime(y, m, 1));
    _loadCheckedDates();
  }

  /// 是否还能翻到下一月（当前月之后不可翻）
  bool _canGoNextMonth() {
    final today = beijingToday();
    return _displayMonth.year < today.year ||
        (_displayMonth.year == today.year &&
            _displayMonth.month < today.month);
  }

  /// 是否还能向前翻月（早于最早签到数据的月份无数据则不可翻）
  bool _canGoPrevMonth() {
    if (_displayMonth.year > _earliestDataMonth.year) return true;
    if (_displayMonth.year == _earliestDataMonth.year &&
        _displayMonth.month > _earliestDataMonth.month) {
      return true;
    }
    return false;
  }

  /// 加载持有的补签卡数量（供日历提示与补签弹窗使用）
  Future<void> _loadMakeupCardCount() async {
    final count = await PointService.instance.getMakeupCardCount();
    if (mounted) setState(() => _makeupCardCount = count);
  }

  /// 进入积分商城（返回后刷新库存与积分）
  void _openMall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PointMallScreen()),
    ).then((_) {
      _loadMakeupCardCount();
      _loadAvailablePoints();
    });
  }

  /// 补签入口：点击日历漏签日期触发。
  void _onMakeup(DateTime date) {
    final key = beijingDateKey(date);
    showDialog(
      context: context,
      builder: (ctx) {
        var making = false;
        return StatefulBuilder(
          builder: (_, setLocal) {
            final hasCard = _makeupCardCount > 0;
            return AlertDialog(
              title: const Text('补签确认'),
              content: Text(
                hasCard
                    ? '补签 $key ？将消耗 1 张补签卡（不额外发放积分，仅维持连续天数）。'
                    : '你还没有补签卡。\n补签卡可在「积分商城」消耗 ${PointService.makeupCardCost} 积分兑换。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                if (hasCard)
                  FilledButton(
                    onPressed: making
                        ? null
                        : () async {
                            setLocal(() => making = true);
                            final result =
                                await PointService.instance.makeupCheckin(date);
                            if (!mounted) return;
                            setLocal(() => making = false);
                            Navigator.pop(context);
                            showSnackBar(
                              context,
                              result['message'] ?? '补签完成',
                            );
                            if (result['success'] == true) {
                              _loadCheckedDates();
                              _loadMakeupCardCount();
                              _loadAvailablePoints();
                              _loadEarliestDataMonth();
                            }
                          },
                    child: making
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('确认补签'),
                  )
                else
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openMall();
                    },
                    child: const Text('去积分商城'),
                  ),
              ],
            );
          },
        );
      },
    );
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
        final streak = result['streak'] as int? ?? _consecutiveCheckinDays;
        setState(() {
          _consecutiveCheckinDays = streak;
          _hasCheckedInToday = true;
        });
        showSnackBar(context, result['message'] ?? '签到成功');
        _loadCheckedDates();
        _loadEarliestDataMonth();
      } else {
        showSnackBar(context, result['message'] ?? '签到失败');
      }
      await _loadAvailablePoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分签到'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: '积分记录',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PointRecordsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: '积分商城',
            onPressed: _openMall,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: CheckinCalendarCard(
          availablePoints: _availablePoints,
          isLoadingPoints: _isLoadingPoints,
          hasCheckedInToday: _hasCheckedInToday,
          isCheckingIn: _isCheckingIn,
          consecutiveCheckinDays: _consecutiveCheckinDays,
          displayMonth: _displayMonth,
          checkedDates: _checkedDates,
          isLoadingCalendar: _isLoadingCalendar,
          onCheckin: _handleCheckin,
          onPrevMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
          onMakeup: _onMakeup,
          canGoNext: _canGoNextMonth(),
          canGoPrev: _canGoPrevMonth(),
          makeupCardCount: _makeupCardCount,
        ),
      ),
    );
  }
}
