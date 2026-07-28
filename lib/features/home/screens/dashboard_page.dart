import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/event_bus.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import '../../../services/dict_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/request_cache.dart';
import '../../life/models/habit_model.dart';
import '../../life/models/reminder_model.dart';
import '../../life/screens/reminders_screen.dart';
import '../../novel/models/novel_model.dart';
import '../../novel/services/novel_launch_service.dart';
import 'notification_center_screen.dart';
import 'sheets/sheets.dart';
import 'dashboard_helpers.dart';
import '../widgets/dashboard/dashboard_widgets.dart';
import 'dashboard_activity_helpers.dart';
import 'dashboard_tool_handlers.dart';
import '../services/announcement_service.dart';
import '../widgets/announcement_banner.dart';

/// 首页仪表板页面
///
/// 包含 DashboardPage 及其相关组件，展示用户欢迎信息、快捷工具、
/// 待办提醒、习惯打卡、最近阅读和最近活动等内容。



const String _prefsKeyTools = 'dashboard_visible_tools';

/// 首页各区块本地缓存键（stale-while-revalidate，秒开用）
const String _kCacheRecentNovels = 'cache_home_recent_novels';
const String _kCacheHabits = 'cache_home_habits';
const String _kCacheActivities = 'cache_home_activities';
const String _kCacheReminders = 'cache_home_reminders';

/// 首页仪表板
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingActivities = true;
  List<Map<String, dynamic>> _recentActivities = [];

  // 公告横幅
  bool _isLoadingAnnouncements = true;
  List<Announcement> _announcements = [];

  List<ReminderModel> _pendingReminders = [];

  bool _isLoadingNovels = true;
  List<Map<String, dynamic>> _recentNovels = [];

  List<String> _visibleToolIds = [];

  // 习惯打卡数据
  List<HabitModel> _habits = [];
  Map<String, List<HabitCheckinModel>> _checkinHistory = {};
  String? _checkingHabitId; // 正在打卡的习惯ID，用于loading阻断

  final List<StreamSubscription<void>> _eventSubscriptions = [];

  @override
  void initState() {
    super.initState();
    DictService.instance.loadFromNetwork();
    _initLoadData();
    _listenDataChangeEvents();
  }

  /// 监听全局数据变更事件，从其他页面返回时自动刷新最新动态
  void _listenDataChangeEvents() {
    final handlers = <EventType, VoidCallback>{
      EventType.expenseUpdated: _loadRecentActivities,
      EventType.weightRecordUpdated: _loadRecentActivities,
      EventType.moodDiaryUpdated: _loadRecentActivities,
      EventType.noteUpdated: _loadRecentActivities,
      EventType.habitUpdated: _loadRecentActivities,
      EventType.reminderUpdated: _loadRecentActivities,
      EventType.bookshelfUpdated: _onBookshelfChanged,
    };
    handlers.forEach((type, handler) {
      _eventSubscriptions.add(
        EventBus.instance.on(type).listen((_) {
          if (mounted) handler();
        }),
      );
    });
  }

  /// 书架变化：使最近阅读缓存失效并刷新（保证加/删书后首页即时更新）
  void _onBookshelfChanged() {
    unawaited(RequestCache.invalidate(_kCacheRecentNovels));
    _loadRecentNovels();
  }

  @override
  void dispose() {
    for (final sub in _eventSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _initLoadData() async {
    await Future.wait([
      _loadRecentActivities(),
      _loadPendingReminders(),
      _loadRecentNovels(),
      _loadToolConfig(),
      _loadHabitsForCheckin(),
      _loadAnnouncements(),
    ]);
  }

  /// 加载习惯数据（用于首页快捷打卡）
  /// 加载习惯数据（用于首页快捷打卡，带本地缓存）
  Future<void> _loadHabitsForCheckin() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    Future<ApiResponse> fetcher() async {
      final result = await ApiClient.get('habits',
          filters: {'user_id': 'eq.$userId', 'is_active': 'eq.true'},
          select: '*',
          order: 'created_at.desc',
          limit: 3);
      if (!result.isSuccess) return ApiResponse.success([]);
      final habitsData = result.data as List;
      final checkinsData = <dynamic>[];
      if (habitsData.isNotEmpty) {
        final habitIds = habitsData.map((h) => h['id'].toString()).toList();
        final checkinsResult = await ApiClient.get('habit_checkins',
            filters: {'habit_id': 'in.(${habitIds.join(",")})'},
            select: '*',
            order: 'checkin_at.desc',
            limit: 3);
        if (checkinsResult.isSuccess && checkinsResult.data != null) {
          checkinsData.addAll(checkinsResult.data!);
        }
      }
      // 合并为可缓存 plain JSON（单一元素 list）
      return ApiResponse.success([
        {'habits': habitsData, 'checkins': checkinsData}
      ]);
    }

    final (rows, _) = await RequestCache.getList(_kCacheHabits, fetcher);
    if (!mounted) return;
    final plain =
        rows.isNotEmpty ? rows[0] : {'habits': <dynamic>[], 'checkins': <dynamic>[]};
    final habitsData = (plain['habits'] as List?) ?? <dynamic>[];
    final checkinsData = (plain['checkins'] as List?) ?? <dynamic>[];
    final habits = parseHabits(habitsData);
    final history = buildCheckinHistory(checkinsData, habits);
    setState(() {
      _habits = habits;
      _checkinHistory = history;
    });
  }

  /// 获取今日待打卡的习惯列表
  List<HabitModel> get _pendingHabits => computePendingHabits(_habits, _checkinHistory);

  /// 一键打卡
  Future<void> _quickCheckIn(HabitModel habit) async {
    if (_checkingHabitId != null) return; // 防止重复请求
    setState(() => _checkingHabitId = habit.id);
    try {
      final today = DateTime.now();

      final checkinResult = await ApiClient.post(
        'habit_checkins',
        {
          'id': const Uuid().v4(),
          'habit_id': habit.id,
          'user_id': AuthService.instance.currentUserId,
          'checkin_at': today.toUtc().toIso8601String(),
        },
        returnRepresentation: false,
      );

      if (!checkinResult.isSuccess) {
        throw Exception('打卡失败: HTTP ${checkinResult.statusCode}');
      }

      // 刷新习惯数据（先使缓存失效，保证打卡后即时刷新）
      unawaited(RequestCache.invalidate(_kCacheHabits));
      await _loadHabitsForCheckin();

      if (mounted) {
        // TODO: showSnackBar 不支持自定义 backgroundColor，保留原样
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${habit.name} 打卡成功！'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '打卡失败，请稍后重试', isError: true);
      }
    } finally {
      if (mounted) setState(() => _checkingHabitId = null);
    }
  }

  /// 加载首页生效公告（后台发布 → 此处展示）
  Future<void> _loadAnnouncements() async {
    try {
      final list = await AnnouncementService.fetchActive();
      if (mounted) {
        setState(() {
          _announcements = list;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  /// 加载工具配置
  Future<void> _loadToolConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKeyTools);
    if (saved != null && saved.isNotEmpty) {
      if (mounted) setState(() => _visibleToolIds = saved);
    } else {
      // 默认全部显示
      if (mounted) setState(() => _visibleToolIds = allTools.map((t) => t.id).toList());
    }
  }

  /// 保存工具配置
  Future<void> _saveToolConfig(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyTools, ids);
    if (mounted) setState(() => _visibleToolIds = ids);
  }

  /// 从 Supabase 加载最近活动记录（带本地缓存）
  Future<void> _loadRecentActivities() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingActivities = false);
      return;
    }

    // fetcher 只缓存原始 plain JSON（Supabase 返回），不缓存 IconData 等非序列化对象；
    // 读取时再 buildXxxActivity 生成含图标的渲染条目。否则 jsonEncode 缓存会抛异常。
    Future<ApiResponse> fetcher() async {
      final futures = [
        ApiClient.get('expenses',
            filters: {'user_id': 'eq.$userId'},
            select: '*,created_at',
            order: 'created_at.desc',
            limit: 1),
        ApiClient.get('mood_diaries',
            filters: {'user_id': 'eq.$userId'},
            select: '*,created_at',
            order: 'created_at.desc',
            limit: 1),
        ApiClient.get('weight_records',
            filters: {'user_id': 'eq.$userId'},
            select: '*,created_at',
            order: 'created_at.desc',
            limit: 1),
      ];
      final results = await Future.wait(futures);
      final raw = <Map<String, dynamic>>[];
      const sources = ['expense', 'mood', 'weight'];
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        if (r.isSuccess && r.data != null && r.data!.isNotEmpty) {
          final item = Map<String, dynamic>.from(r.data![0]);
          item['__source'] = sources[i];
          raw.add(item);
        }
      }
      return ApiResponse.success(raw);
    }

    try {
      final (rows, _) = await RequestCache.getList(_kCacheActivities, fetcher);
      if (!mounted) return;
      final activities = <Map<String, dynamic>>[];
      for (final r in rows) {
        final source = r['__source'] as String?;
        final item = Map<String, dynamic>.from(r)..remove('__source');
        if (source == 'mood') {
          activities.add(buildDiaryActivity(item));
        } else if (source == 'expense') {
          activities.add(buildExpenseActivity(item));
        } else if (source == 'weight') {
          activities.add(buildWeightActivity(item));
        }
      }
      setState(() {
        _recentActivities = activities;
        _isLoadingActivities = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 加载最近活动失败: $e');
      if (mounted) setState(() => _isLoadingActivities = false);
    }
  }

  /// 加载待办提醒（带本地缓存）
  Future<void> _loadPendingReminders() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    final (rows, _) = await RequestCache.getList(_kCacheReminders, () async {
      final result = await ApiClient.get('reminders',
          filters: {'user_id': 'eq.$userId', 'is_completed': 'eq.false'},
          select: '*',
          order: 'remind_at.asc',
          limit: 3);
      return result; // data 已是 plain JSON，可直接缓存
    });
    if (!mounted) return;
    final reminders = rows.map((e) => ReminderModel.fromJson(e)).toList();
    setState(() {
      _pendingReminders = reminders;
    });
  }

  /// 加载最近阅读的小说（带本地缓存：先秒开，后台静默刷新）
  /// 仍分两步查询（保持原 RLS/外键兼容），但整体结果经 RequestCache 缓存为 plain JSON
  Future<void> _loadRecentNovels() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoadingNovels = false);
      return;
    }

    // fetcher 返回 plain JSON（可缓存），读取时再转 NovelModel
    Future<ApiResponse> fetcher() async {
      // 第一步：用户阅读记录
      final progressResult = await ApiClient.get('user_novels',
          filters: {'user_id': 'eq.$userId'},
          select: 'novel_id,last_chapter,progress,last_read_at',
          order: 'last_read_at.desc.nullslast',
          limit: 5);

      if (!progressResult.isSuccess ||
          progressResult.data == null ||
          progressResult.data!.isEmpty) {
        return ApiResponse.success([]);
      }

      final novelIds = <String>[];
      final progressMap = <String, Map<String, dynamic>>{};
      for (final item in progressResult.data!) {
        final novelId = item['novel_id']?.toString();
        if (novelId != null && novelId.isNotEmpty) {
          novelIds.add(novelId);
          progressMap[novelId] = item;
        }
      }
      if (novelIds.isEmpty) return ApiResponse.success([]);

      // 第二步：小说详情（含 source/source_url，聚合书路由必需）
      final novelsResult = await ApiClient.get('novels',
          filters: {'id': 'in.(${novelIds.join(",")})'},
          select: 'id,title,author,cover_url,category,chapter_count,source,source_url',
          limit: novelIds.length);

      final novels = <Map<String, dynamic>>[];
      if (novelsResult.isSuccess && novelsResult.data != null) {
        for (final nd in novelsResult.data!) {
          final id = nd['id']?.toString() ?? '';
          final p = progressMap[id];
          if (p != null) {
            novels.add({
              'novel': nd,
              'lastChapter': p['last_chapter'] as int? ?? 1,
              'progress': p['progress'] as num? ?? 0.0,
            });
          }
        }
      }
      return ApiResponse.success(novels);
    }

    final (rows, _) = await RequestCache.getList(_kCacheRecentNovels, fetcher);
    if (!mounted) return;
    final novels = rows.map((m) {
      final novelJson = m['novel'] as Map<String, dynamic>? ?? {};
      return {
        'novel': NovelModel.fromJson(novelJson),
        'lastChapter': m['lastChapter'] as int? ?? 1,
        'progress': m['progress'] as num? ?? 0.0,
      };
    }).toList();
    setState(() {
      _recentNovels = novels;
      _isLoadingNovels = false;
    });
  }

  /// 工具点击处理（分发逻辑抽至 dashboard_tool_handlers.dart，行为不变）
  void _onToolTap(ToolItem tool) {
    dashboardHandleToolTap(
      context,
      tool,
      reloadActivities: _loadRecentActivities,
      reloadReminders: _loadPendingReminders,
      fireExpense: () => EventBus.instance.fire(EventType.expenseUpdated),
      fireWeight: () => EventBus.instance.fire(EventType.weightRecordUpdated),
    );
  }

  /// 跳转到提醒详情
  void _goToReminderDetail(ReminderModel reminder) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RemindersScreen()),
    ).then((_) => _loadPendingReminders());
  }

  /// 继续阅读小说
  Future<void> _continueReading(NovelModel novel, int lastChapter) async {
    // 聚合小说按来源路由到外部；返回（内置阅读器/WebView 出栈）后刷新最近阅读
    await NovelLaunchService.instance.launch(
      context,
      novel,
      startChapter: lastChapter,
    );
    unawaited(RequestCache.invalidate(_kCacheRecentNovels));
    _loadRecentNovels();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTools = allTools.where((t) => _visibleToolIds.contains(t.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('纯享'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
              ).then((_) => _loadPendingReminders());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadRecentActivities(),
            _loadPendingReminders(),
            _loadRecentNovels(),
            _loadAnnouncements(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnnouncementBanner(
              announcements: _announcements,
              isLoading: _isLoadingAnnouncements,
              onViewAll: _loadAnnouncements,
            ),
            const WelcomeSection(),
            TodoReminderSection(
              reminders: _pendingReminders,
              onTap: _goToReminderDetail,
            ),
            HabitCheckinSection(
              pendingHabits: _pendingHabits,
              checkingHabitId: _checkingHabitId,
              onCheckIn: _quickCheckIn,
              onViewAll: _loadHabitsForCheckin,
            ),
            QuickToolsSection(
              visibleTools: visibleTools,
              onConfigTap: () => showToolConfigSheet(
                context,
                visibleIds: _visibleToolIds,
                onSave: _saveToolConfig,
              ),
              onToolTap: _onToolTap,
            ),
            RecentReadingSection(
              isLoading: _isLoadingNovels,
              novels: _recentNovels,
              onContinueReading: _continueReading,
            ),
            RecentActivitySection(
              isLoading: _isLoadingActivities,
              activities: _recentActivities,
            ),
          ],
        ),
      ),
    );
  }
}


