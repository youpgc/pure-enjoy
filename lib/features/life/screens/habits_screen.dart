import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../models/habit_model.dart';
import '../models/reminder_schedule_model.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_history_dialog.dart';
import '../data/habit_repository.dart';
import './habit_edit_dialog.dart';
import '../../../core/utils/event_bus.dart';
import '../helpers/habit_screen_helpers.dart';
import '../helpers/habit_reminder_sync.dart';
import '../helpers/habit_checkin_action.dart';

/// 习惯打卡页面 - Supabase 数据同步
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<HabitModel> _habits = [];
  Map<String, List<HabitCheckinModel>> _checkinHistory = {};
  Map<String, ReminderScheduleModel> _reminderSchedules = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  /// 正在打卡中的习惯 ID（单习惯 loading，避免触发整列表 loading）
  String? _checkingHabitId;
  bool _hasMore = true;
  /// 是否已至少成功加载过一次（用于并发守卫，避免拦截首次加载）
  bool _hasLoadedOnce = false;
  /// 请求序号：每次进入 _loadHabits 自增，用于丢弃过期/乱序的响应，
  /// 避免切换筛选时先发的旧请求后返回，覆盖最新的「全部」结果
  int _loadSeq = 0;
  bool? _filterStatus;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHabits();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadHabits();
      }
    }
  }

  Future<void> _loadHabits({bool refresh = false, bool fromCheckIn = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _habits = [];
        _checkinHistory = {};
        _reminderSchedules = {};
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    // 标记本次请求为最新，旧请求返回时据此丢弃，避免乱序覆盖
    final seq = ++_loadSeq;

    // 防并发：如果已经在加载中（非刷新且已加载过一次），直接返回
    // 注意：不能用 _isLoading 判断首次加载，因其初始即为 true，
    // 否则会和"首次加载"互相死锁导致永久 loading。
    if (!refresh && _hasLoadedOnce && (_isLoading || _isLoadingMore)) return;

    final isFirstPage = _offset == 0;

    if (refresh) {
      if (fromCheckIn) {
        // 单习惯打卡刷新：保留列表可见，仅被打卡的按钮显示 loading，不触发整列表 loading
        setState(() {
          _offset = 0;
          _hasMore = true;
        });
      } else {
        setState(() {
          _offset = 0;
          _hasMore = true;
          _habits = [];
          _checkinHistory = {};
          _reminderSchedules = {};
          _isLoading = true;
        });
      }
    } else if (isFirstPage) {
      // 1. 先加载本地缓存（仅在初始第一页时）
      final cachedHabits = await CacheHelper.instance.loadList(CacheHelper.keyHabits);
      if (cachedHabits.isNotEmpty && mounted) {
        setState(() {
          _habits = cachedHabits.map((e) => HabitModel.fromJson(e)).toList();
          _checkinHistory = {}; // 缓存加载时重置打卡记录，避免显示旧状态
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoadingMore = true);
    }

    // 2. 从网络分页加载（数据层已抽离至 habit_repository.fetchHabitPage）
    try {
      final bundle = await fetchHabitPage(
        userId: userId,
        filterStatus: _filterStatus,
        offset: _offset,
        limit: _limit,
      );
      final items = bundle.habits;

      // 仅第一页时保存缓存
      if (_offset == 0) {
        await CacheHelper.instance.saveList(CacheHelper.keyHabits, bundle.rawHabits);
      }

      if (mounted) {
        // 已被更新的请求取代（如切换筛选），丢弃本次结果，避免覆盖最新数据
        if (seq != _loadSeq) return;
        setState(() {
          if (refresh || isFirstPage) {
            _habits = items;
            _checkinHistory = bundle.checkinHistory;
            _reminderSchedules = bundle.reminderSchedules;
          } else {
            _habits.addAll(items);
            _checkinHistory.addAll(bundle.checkinHistory);
            _reminderSchedules.addAll(bundle.reminderSchedules);
          }
          _offset += _limit;
          _hasMore = items.length >= _limit;
          _isLoading = false;
          _isLoadingMore = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      // 已过期（被更新的请求取代），交给更新的请求处理，不再处理本次异常
      if (seq != _loadSeq) return;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasLoadedOnce = true;
        });
        // 如果已有数据，静默失败不提示
        if (_habits.isEmpty) {
          showHabitError(context, '加载习惯失败，请稍后重试');
        }
      }
    }
  }

  Future<void> _checkIn(HabitModel habit) async {
    // 防重复：同一习惯正在打卡中则忽略后续点击
    if (_checkingHabitId == habit.id) return;
    // 未登录保护（createCheckin 需要非空业务 ID）
    if (_userId == null) {
      showHabitError(context, '请先登录后再打卡');
      return;
    }
    final today = DateTime.now();

    // 闭环：已达成目标天数则不再允许打卡（状态标记已完成，停止过程逻辑）
    if (isHabitCompleted(getTotalCheckins(_checkinHistory[habit.id] ?? []), habit.targetDays)) {
      showHabitError(context, '「${habit.name}」已达成目标天数，已自动完成');
      return;
    }

    // 检查今天是否已经打卡
    final checkins = _checkinHistory[habit.id] ?? [];
    if (checkins.any((c) => DateUtils.isSameDay(c.checkinAt, today))) {
      showHabitError(context, '今天已经打卡了');
      return;
    }

    // 标记该习惯正在打卡，对应按钮显示 loading（而非整列表 loading）
    if (mounted) setState(() => _checkingHabitId = habit.id);

    // 网络+本地反馈+事件+UI 提示已抽离至 habit_checkin_action.performHabitCheckIn
    await performHabitCheckIn(
      context: context,
      habit: habit,
      userId: _userId!,
      addLocalCheckin: (id, c) {
        if (mounted) {
          setState(() {
          _checkinHistory.putIfAbsent(id, () => []);
          _checkinHistory[id]!.add(c);
        });
        }
      },
      refresh: () => _loadHabits(refresh: true, fromCheckIn: true),
    );

    // 闭环：达成目标天数后取消该习惯的提醒，不再发起任何过程提醒
    if (isHabitCompleted(getTotalCheckins(_checkinHistory[habit.id] ?? []), habit.targetDays)) {
      await NotificationService.instance.cancelHabitReminder(habit.id);
    }

    // 无论成功失败，结束单习惯 loading
    if (mounted) setState(() => _checkingHabitId = null);
  }

  Future<void> _deleteHabit(String id) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '删除后无法恢复，是否继续？',
    );

    if (confirmed == true) {
      try {
        // 数据层已抽离至 habit_repository.deleteHabit
        await deleteHabit(id);
        // 删除习惯时同步取消其本地横幅提醒
        await NotificationService.instance.cancelHabitReminder(id);
        _loadHabits(refresh: true);
        EventBus.instance.fire(EventType.habitUpdated);
        if (mounted) {
          showSnackBar(context, '删除成功');
        }
      } catch (e) {
        if (mounted) showHabitError(context, '删除失败，请稍后重试');
      }
    }
  }

  Future<void> _toggleHabitActive(HabitModel habit) async {
    final action = habit.isActive ? '暂停' : '恢复';
    final confirmed = await showConfirmDialog(
      context,
      title: '确认$action',
      content: '确定要$action「${habit.name}」吗？',
    );

    if (confirmed != true) return;

    try {
      final newActive = !habit.isActive;
      // 数据层已抽离至 habit_repository.setHabitActive
      await setHabitActive(habit.id, newActive);
      // 暂停/恢复后的提醒同步已抽离至 habit_reminder_sync.syncHabitReminderOnToggle
      await syncHabitReminderOnToggle(
        isActiveNow: newActive,
        habit: habit,
        schedule: _reminderSchedules[habit.id],
        totalCheckins: getTotalCheckins(_checkinHistory[habit.id] ?? []),
      );
      _loadHabits(refresh: true);
      EventBus.instance.fire(EventType.habitUpdated);
    } catch (e) {
      if (mounted) showHabitError(context, '\$action失败，请稍后重试');
    }
  }

  Future<void> _showEditDialog({HabitModel? habit}) {
    return showHabitEditDialog(
      context: context,
      habit: habit,
      reminderSchedules: _reminderSchedules,
      currentUserId: _userId,
      onSaved: () {
        _loadHabits(refresh: true);
        EventBus.instance.fire(EventType.habitUpdated);
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯打卡'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (value) {
              // 注意：菜单项 value 不能用 null —— Flutter 的 PopupMenuButton
              // 在 showMenu 返回 null 时会误判为"用户取消菜单"而不调用 onSelected，
              // 导致「全部」选项永远不触发刷新。故用非 null 哨兵值再映射回 bool?。
              setState(() {
                _filterStatus = switch (value) {
                  'active' => true,
                  'paused' => false,
                  _ => null,
                };
              });
              _loadHabits(refresh: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('全部'),
              ),
              const PopupMenuItem(
                value: 'active',
                child: Text('进行中'),
              ),
              const PopupMenuItem(
                value: 'paused',
                child: Text('已暂停'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _habits.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadHabits(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(
                          child: EmptyWidget(icon: Icons.track_changes_outlined, message: '还没有习惯'),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadHabits(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _habits.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: LoadingWidget()),
                        );
                      }
                      final habit = _habits[index];
                      final isCheckedIn = isCheckedInToday(_checkinHistory[habit.id] ?? []);
                      final totalCheckins = getTotalCheckins(_checkinHistory[habit.id] ?? []);
                      final completed = isHabitCompleted(totalCheckins, habit.targetDays);
                      final schedule = _reminderSchedules[habit.id];
                      final shouldRemindToday = schedule?.shouldRemindToday(DateTime.now()) ?? false;
                      return HabitCard(
                        habit: habit,
                        isCheckedIn: isCheckedIn,
                        totalCheckins: totalCheckins,
                        isCompleted: completed,
                        reminderSchedule: schedule,
                        shouldRemindToday: shouldRemindToday,
                        isCheckingIn: _checkingHabitId == habit.id,
                        onCheckIn: () => _checkIn(habit),
                        onEdit: () => _showEditDialog(habit: habit),
                        onDelete: () => _deleteHabit(habit.id),
                        onViewHistory: () => showHabitHistoryDialog(context, habit.name, _checkinHistory[habit.id] ?? []),
                        onToggleActive: () => _toggleHabitActive(habit),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

