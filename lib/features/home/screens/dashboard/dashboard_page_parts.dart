part of './dashboard_page.dart';

/// 首页仪表板页面（主体逻辑）
///
/// 将原本超长的 [_DashboardPageState] 方法体整体抽到本 part，使主文件仅保留薄壳；
/// 数据加载相关方法已拆至 [dashboard_logic_mixin.dart] 的 [_DashboardLogic]，行为完全不变。
/// 注意：下方 ApiClient 调用的 `select` 显式列已在此保留，不要回退。
class _DashboardPageState extends State<DashboardPage> with _DashboardLogic {
  // 数据加载相关字段已随 [_DashboardLogic] 迁移，本类仅保留事件订阅相关状态
  final List<StreamSubscription<void>> _eventSubscriptions = [];

  @override
  void initState() {
    super.initState();
    // 字典缓存优先：先读本地缓存秒开，仅首次启动/缓存过期才后台刷新
    DictService.instance.loadCacheFirst(
      onCacheReady: () {
        if (mounted) setState(() {});
      },
    );
    _initLoadData();
    _listenDataChangeEvents();
  }

  /// 监听全局数据变更事件，从其他页面返回时自动刷新最新动态
  void _listenDataChangeEvents() {
    final handlers = <EventType, VoidCallback>{
      EventType.expenseUpdated: () => _loadRecentActivities(force: true),
      EventType.weightRecordUpdated: () => _loadRecentActivities(force: true),
      EventType.moodDiaryUpdated: () => _loadRecentActivities(force: true),
      EventType.noteUpdated: () => _loadRecentActivities(force: true),
      EventType.habitUpdated: () => _loadRecentActivities(force: true),
      EventType.reminderUpdated: () => _loadPendingReminders(force: true),
      // [小说模块暂时停用] EventType.bookshelfUpdated: _onBookshelfChanged,
    };
    handlers.forEach((type, handler) {
      _eventSubscriptions.add(
        EventBus.instance.on(type).listen((_) {
          if (mounted) handler();
        }),
      );
    });
  }

  // [小说模块暂时停用] 书架变化刷新最近阅读
  // void _onBookshelfChanged() {
  //   unawaited(RequestCache.invalidate(_kCacheRecentNovels));
  //   _loadRecentNovels(force: true);
  // }

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
      // [小说模块暂时停用] _loadRecentNovels(),
      _loadToolConfig(),
      _loadHabitsForCheckin(),
      _loadAnnouncements(),
    ]);
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
    ).then((_) => _loadPendingReminders(force: true));
  }

  // [小说模块暂时停用] 继续阅读小说入口
  // Future<void> _continueReading(NovelModel novel, int lastChapter) async {
  //   // 聚合小说按来源路由到外部；返回（内置阅读器/WebView 出栈）后刷新最近阅读
  //   await NovelLaunchService.instance.launch(
  //     context,
  //     novel,
  //     startChapter: lastChapter,
  //   );
  //   unawaited(RequestCache.invalidate(_kCacheRecentNovels));
  //   _loadRecentNovels();
  // }

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
              ).then((_) => _loadPendingReminders(force: true));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadRecentActivities(force: true),
            _loadPendingReminders(force: true),
            // [小说模块暂时停用] _loadRecentNovels(force: true),
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
            // [小说模块暂时停用] 首页「最近阅读」小说入口隐藏
            // RecentReadingSection(
            //   isLoading: _isLoadingNovels,
            //   novels: _recentNovels,
            //   onContinueReading: _continueReading,
            // ),
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
