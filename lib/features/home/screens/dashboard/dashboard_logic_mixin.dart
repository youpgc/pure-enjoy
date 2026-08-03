part of './dashboard_page.dart';

const String _prefsKeyTools = 'dashboard_visible_tools';

/// 首页各区块本地缓存键（stale-while-revalidate，秒开用）
// [小说模块暂时停用] const String _kCacheRecentNovels = 'cache_home_recent_novels';
const String _kCacheHabits = 'cache_home_habits';
const String _kCacheActivities = 'cache_home_activities';

/// 首页「低变数据」缓存新鲜度：最近阅读/最近活动读多写少，1h 内视为新鲜直接秒开
/// （与 DictService / 版本检查同策略）。写操作经事件 invalidate / forceRefresh 保证强一致。
const Duration _kHomeLongTtl = Duration(hours: 1);

/// 首页数据加载逻辑 mixin（从 [_DashboardPageState] 拆出，行为不变）
///
/// 与这些方法配套的实例字段一并放在本 mixin 中（Dart mixin 无法直接访问类实例字段，
/// 故字段随逻辑一起迁移；主类 [_DashboardPageState] 仅保留事件订阅字段）。所有
/// 初始值与原来完全一致，行为 100% 不变。
mixin _DashboardLogic on State<DashboardPage> {
  bool _isLoadingActivities = true;
  List<Map<String, dynamic>> _recentActivities = [];

  bool _isLoadingAnnouncements = true;
  List<Announcement> _announcements = [];

  List<ReminderModel> _pendingReminders = [];

  // 提醒加载：实时获取；10s 内重复调用（快速切 tab）不重复请求
  DateTime? _remindersLastFetched;
  static const Duration _remindersThrottle = Duration(seconds: 10);

  // [小说模块暂时停用] bool _isLoadingNovels = true;
  // [小说模块暂时停用] List<Map<String, dynamic>> _recentNovels = [];

  List<String> _visibleToolIds = [];

  // 习惯打卡数据
  List<HabitModel> _habits = [];
  Map<String, List<HabitCheckinModel>> _checkinHistory = {};
  String? _checkingHabitId; // 正在打卡的习惯ID，用于loading阻断

  /// 加载习惯数据（用于首页快捷打卡，带本地缓存）
  Future<void> _loadHabitsForCheckin() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    Future<ApiResponse> fetcher() async {
      final result = await ApiClient.get('habits',
          filters: {'user_id': 'eq.$userId', 'is_active': 'eq.true'},
          select:
              'id,user_id,name,description,target_days,current_streak,longest_streak,is_active,created_at',
          order: 'created_at.desc',
          limit: 3);
      if (!result.isSuccess) return ApiResponse.success([]);
      final habitsData = result.data as List;
      final checkinsData = <dynamic>[];
      if (habitsData.isNotEmpty) {
        final habitIds = habitsData.map((h) => h['id'].toString()).toList();
        final checkinsResult = await ApiClient.get('habit_checkins',
            filters: {'habit_id': 'in.(${habitIds.join(",")})'},
            select: 'id,habit_id,user_id,checkin_at,note,created_at',
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

    final (rows, _) = await RequestCache.getList(_kCacheHabits, fetcher,
        ttl: _kHomeLongTtl);
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
    // 闭环：已达成目标天数的习惯不再允许打卡
    final totalCheckins = _checkinHistory[habit.id]?.length ?? 0;
    if (isHabitCompleted(totalCheckins, habit.targetDays)) return;
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

  /// 从 Supabase 加载最近活动记录（带本地缓存：先秒开，后台静默刷新）
  /// [force] 为 true 时跳过缓存直接拉最新（事件回程/下拉刷新用，保证写后强一致）
  Future<void> _loadRecentActivities({bool force = false}) async {
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
            select: 'category,amount,created_at,date',
            order: 'created_at.desc',
            limit: 1),
        ApiClient.get('mood_diaries',
            filters: {'user_id': 'eq.$userId'},
            select: 'content,mood,created_at,date',
            order: 'created_at.desc',
            limit: 1),
        ApiClient.get('weight_records',
            filters: {'user_id': 'eq.$userId'},
            select: 'weight,created_at,date',
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
      final (rows, _) = await RequestCache.getList(
        _kCacheActivities,
        fetcher,
        ttl: _kHomeLongTtl,
        forceRefresh: force,
      );
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

  /// 加载待办提醒（实时获取；10s 内重复调用仅复用，避免快速切 tab 重复请求）
  Future<void> _loadPendingReminders({bool force = false}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;

    // 极短缓存：10s 内已拉取过且非强制刷新 → 直接复用，不重复请求
    final now = DateTime.now();
    if (!force &&
        _remindersLastFetched != null &&
        now.difference(_remindersLastFetched!) < _remindersThrottle) {
      return;
    }

    final result = await ApiClient.get('reminders',
        filters: {'user_id': 'eq.$userId', 'is_completed': 'eq.false'},
        select:
            'id,user_id,title,description,remind_at,is_completed,is_repeated,repeat_type,created_at',
        order: 'remind_at.asc',
        limit: 3);
    if (!mounted) return;
    // 请求失败保持上一轮数据，避免界面闪烁
    if (!result.isSuccess || result.data == null) return;

    _remindersLastFetched = DateTime.now();
    final reminders = (result.data as List).map((e) => ReminderModel.fromJson(e)).toList();
    setState(() => _pendingReminders = reminders);
  }

  /* [小说模块暂时停用]
  /// 加载最近阅读的小说（带本地缓存：先秒开，后台静默刷新）
  /// 仍分两步查询（保持原 RLS/外键兼容），但整体结果经 RequestCache 缓存为 plain JSON
  /// [force] 为 true 时跳过缓存直接拉最新（事件回程/下拉刷新用，保证加删书后强一致）
  Future<void> _loadRecentNovels({bool force = false}) async {
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

    final (rows, _) = await RequestCache.getList(
      _kCacheRecentNovels,
      fetcher,
      ttl: _kHomeLongTtl,
      forceRefresh: force,
    );
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
   */
}
