import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/event_bus.dart';
import '../../../services/api_client.dart';
import '../../../services/dict_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../life/models/habit_model.dart';
import '../../life/models/reminder_model.dart';
import '../../life/screens/reminders_screen.dart';
import '../../novel/models/novel_model.dart';
import '../../novel/screens/novel_reader_screen.dart';
import 'notification_center_screen.dart';
import 'sheets/sheets.dart';
import '../widgets/dashboard/dashboard_widgets.dart';

/// 首页仪表板页面
///
/// 包含 DashboardPage 及其相关组件，展示用户欢迎信息、快捷工具、
/// 待办提醒、习惯打卡、最近阅读和最近活动等内容。



const String _prefsKeyTools = 'dashboard_visible_tools';

/// 首页仪表板
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingActivities = true;
  List<Map<String, dynamic>> _recentActivities = [];

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
    final types = [
      EventType.expenseUpdated,
      EventType.weightRecordUpdated,
      EventType.moodDiaryUpdated,
      EventType.noteUpdated,
      EventType.habitUpdated,
      EventType.reminderUpdated,
    ];
    for (final type in types) {
      _eventSubscriptions.add(
        EventBus.instance.on(type).listen((_) {
          if (mounted) _loadRecentActivities();
        }),
      );
    }
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
    ]);
  }

  /// 加载习惯数据（用于首页快捷打卡）
  Future<void> _loadHabitsForCheckin() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return;
    }

    try {
      final result = await ApiClient.get('habits',
          filters: {'user_id': 'eq.$userId', 'is_active': 'eq.true'},
          select: '*',
          order: 'created_at.desc',
          limit: 3);

      if (result.isSuccess) {
        final List data = result.data as List;
        final habits = data.map((e) => HabitModel.fromJson(e as Map<String, dynamic>)).toList();

        // 批量加载所有习惯的打卡记录
        final history = <String, List<HabitCheckinModel>>{};
        if (habits.isNotEmpty) {
          final habitIds = habits.map((h) => h.id).toList();
          final checkinsResult = await ApiClient.get('habit_checkins',
              filters: {'habit_id': 'in.(${habitIds.join(",")})'},
              select: '*',
              order: 'checkin_at.desc',
              limit: 3);

          if (checkinsResult.isSuccess) {
            final List checkinsData = checkinsResult.data as List;
            for (final checkin in checkinsData) {
              final model = HabitCheckinModel.fromJson(checkin as Map<String, dynamic>);
              final habitId = model.habitId;
              history.putIfAbsent(habitId, () => []).add(model);
            }
          }
          // 确保所有习惯都有条目
          for (final habit in habits) {
            history.putIfAbsent(habit.id, () => []);
          }
        }

        if (mounted) {
          setState(() {
            _habits = habits;
            _checkinHistory = history;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载习惯数据失败');
      }
    }
  }

  /// 获取今日待打卡的习惯列表
  List<HabitModel> get _pendingHabits {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _habits.where((habit) {
      final checkins = _checkinHistory[habit.id] ?? [];
      return !checkins.any((c) {
        final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
        return dateStr == todayStr;
      });
    }).toList();
  }

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

      // 刷新习惯数据
      await _loadHabitsForCheckin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${habit.name} 打卡成功！'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingHabitId = null);
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

  /// 从 Supabase 加载最近活动记录
  Future<void> _loadRecentActivities() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingActivities = false);
        return;
      }

      // 并行查询 expenses、mood_diaries、weight_records 各最新一条
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

      final activities = <Map<String, dynamic>>[];

      // 解析心情日记
      final diaryResult = results[1];
      if (diaryResult.isSuccess) {
        final list = diaryResult.data as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.edit_note,
            'title': '心情日记',
            'subtitle': item['content'] ?? item['mood']?.toString() ?? '记录了一条心情',
            'time': _formatDisplayDate(item['created_at'], item['entry_date']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      // 解析支出记录
      final expenseResult = results[0];
      if (expenseResult.isSuccess) {
        final list = expenseResult.data as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          final categoryLabel = DictService.instance.getLabelOrDefault(
            'expense_category',
            item['category'] as String? ?? '',
            defaultValue: item['category'] as String? ?? '其他',
          );
          activities.add({
            'icon': Icons.attach_money,
            'title': '支出记录',
            'subtitle': '$categoryLabel ¥${item['amount'] ?? 0}',
            'time': _formatDisplayDate(item['created_at'], item['date']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      // 解析体重记录
      final weightResult = results[2];
      if (weightResult.isSuccess) {
        final list = weightResult.data as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.monitor_weight,
            'title': '体重记录',
            'subtitle': '${item['weight'] ?? 0} kg',
            'time': _formatDisplayDate(item['created_at'], item['date']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _recentActivities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载最近活动失败');
      }
      if (mounted) {
        setState(() => _isLoadingActivities = false);
      }
    }
  }

  /// 加载待办提醒
  Future<void> _loadPendingReminders() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        return;
      }

      final result = await ApiClient.get('reminders',
          filters: {'user_id': 'eq.$userId', 'is_completed': 'eq.false'},
          select: '*',
          order: 'remind_at.asc',
          limit: 3);

      if (result.isSuccess) {
        final List data = result.data as List;
        final reminders = data.map((e) => ReminderModel.fromJson(e as Map<String, dynamic>)).toList();
        if (mounted) {
          setState(() {
            _pendingReminders = reminders;
          });
        }
      } else {
        throw Exception(result.errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载提醒失败');
      }
    }
  }

  /// 加载最近阅读的小说
  /// 分两步查询：先查 user_novels 获取阅读记录，再查 novels 获取详情
  /// 避免嵌套查询因外键关系或RLS导致解析失败
  Future<void> _loadRecentNovels() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      // 第一步：查询用户有阅读记录的小说（不限制 is_collected）
      final progressResult = await ApiClient.get('user_novels',
          filters: {'user_id': 'eq.$userId'},
          select: 'novel_id,last_chapter,progress,last_read_at',
          order: 'last_read_at.desc.nullslast',
          limit: 5);

      if (!progressResult.isSuccess ||
          progressResult.data == null ||
          progressResult.data!.isEmpty) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      // 收集 novel_id 列表
      final novelIds = <String>[];
      final progressMap = <String, Map<String, dynamic>>{};
      for (final item in progressResult.data!) {
        final novelId = item['novel_id']?.toString();
        if (novelId != null && novelId.isNotEmpty) {
          novelIds.add(novelId);
          progressMap[novelId] = item;
        }
      }

      if (novelIds.isEmpty) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      // 第二步：查询 novels 详情
      final novelsResult = await ApiClient.get('novels',
          filters: {'id': 'in.(${novelIds.join(",")})'},
          select: 'id,title,author,cover_url,category,chapter_count',
          limit: novelIds.length);

      final novels = <Map<String, dynamic>>[];
      if (novelsResult.isSuccess && novelsResult.data != null) {
        for (final novelData in novelsResult.data!) {
          final novelId = novelData['id']?.toString() ?? '';
          final progressItem = progressMap[novelId];
          if (progressItem != null) {
            novels.add({
              'novel': NovelModel.fromJson(novelData),
              'lastChapter': progressItem['last_chapter'] as int? ?? 1,
              'progress': progressItem['progress'] as num? ?? 0.0,
            });
          }
        }
      }

      // 按阅读时间排序（因为 novels 查询不保证顺序）
      novels.sort((a, b) {
        final idA = (a['novel'] as NovelModel).id;
        final idB = (b['novel'] as NovelModel).id;
        final idxA = novelIds.indexOf(idA);
        final idxB = novelIds.indexOf(idB);
        return idxA.compareTo(idxB);
      });

      if (mounted) {
        setState(() {
          _recentNovels = novels;
          _isLoadingNovels = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载最近阅读失败: $e');
      }
      if (mounted) setState(() => _isLoadingNovels = false);
    }
  }

  /// 格式化时间显示（优先创建时间，非同一天则展示选择日期）
  String _formatDisplayDate(String? createdAt, String? selectedDate) {
    if (createdAt == null && selectedDate == null) return '';
    final created = createdAt != null ? DateTime.tryParse(createdAt) : null;
    if (created == null) {
      final dt = selectedDate != null ? DateTime.tryParse(selectedDate) : null;
      if (dt == null) return '';
      return DateTimeUtils.formatStandard(dt);
    }
    if (selectedDate != null) {
      final selected = DateTime.tryParse(selectedDate);
      if (selected != null &&
          (created.year != selected.year ||
              created.month != selected.month ||
              created.day != selected.day)) {
        return DateTimeUtils.formatStandard(selected);
      }
    }
    return DateTimeUtils.formatStandard(created);
  }

  /// 通用保存记录并刷新
  Future<void> _postRecord(
    String table,
    Map<String, dynamic> data,
    String successMessage, {
    VoidCallback? onSuccess,
  }) async {
    try {
      final result = await ApiClient.post(
        table,
        data,
        returnRepresentation: false,
      );
      if (result.isSuccess) {
        if (mounted) {
          // 先显示提示再关闭弹窗，避免 SnackBar 被弹窗遮挡
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
          Navigator.pop(context);
          onSuccess?.call();
        }
      } else {
        throw Exception(result.errorMessage ?? '请求失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  /// 显示添加心情日记弹窗
  void _showAddMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMoodSheet(
        onSave: (diary) => _postRecord(
          'mood_diaries',
          diary.toJson(),
          '日记添加成功',
          onSuccess: _loadRecentActivities,
        ),
      ),
    );
  }

  /// 显示添加支出弹窗
  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseSheet(
        onSave: (expense) => _postRecord(
          'expenses',
          expense.toJson(),
          '支出添加成功',
          onSuccess: () {
            _loadRecentActivities();
            EventBus.instance.fire(EventType.expenseUpdated);
          },
        ),
      ),
    );
  }

  /// 显示添加体重弹窗
  void _showAddWeightSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddWeightSheet(
        onSave: (record) => _postRecord(
          'weight_records',
          record.toJson(),
          '体重记录添加成功',
          onSuccess: _loadRecentActivities,
        ),
      ),
    );
  }

  /// 显示添加笔记弹窗
  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddNoteSheet(
        onSave: (note) => _postRecord('notes', note.toJson(), '笔记添加成功',
          onSuccess: _loadRecentActivities,
        ),
      ),
    );
  }

  /// 显示添加提醒弹窗
  void _showAddReminderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddReminderSheet(
        onSave: (reminder) => _postRecord(
          'reminders',
          reminder.toJson(),
          '提醒添加成功',
          onSuccess: _loadPendingReminders,
        ),
      ),
    );
  }

  /// 显示添加习惯弹窗
  void _showAddHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddHabitSheet(
        onSave: (habit, reminderSchedule) async {
          try {
            final result = await ApiClient.post(
              'habits',
              habit.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              // 保存提醒计划
              if (reminderSchedule != null) {
                await ApiClient.post(
                  'reminder_schedules',
                  reminderSchedule.copyWith(habitId: habit.id).toJson(),
                  returnRepresentation: false,
                );
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('习惯添加成功')),
                );
              }
            } else {
              throw Exception(result.errorMessage ?? '请求失败');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('添加失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// 工具点击处理
  void _onToolTap(ToolItem tool) {
    switch (tool.id) {
      case 'diary':
        _showAddMoodSheet();
        break;
      case 'expense':
        _showAddExpenseSheet();
        break;
      case 'weight':
        _showAddWeightSheet();
        break;
      case 'note':
        _showAddNoteSheet();
        break;
      case 'reminder':
        _showAddReminderSheet();
        break;
      case 'habit':
        _showAddHabitSheet();
        break;
    }
  }

  /// 显示工具配置弹窗
  void _showToolConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ToolConfigSheet(
        visibleIds: _visibleToolIds,
        onSave: _saveToolConfig,
      ),
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
  void _continueReading(NovelModel novel, int lastChapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novel: novel,
          startChapter: lastChapter,
        ),
      ),
    ).then((_) => _loadRecentNovels());
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
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              onConfigTap: _showToolConfigSheet,
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


