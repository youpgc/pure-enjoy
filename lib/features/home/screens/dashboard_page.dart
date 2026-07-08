import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/event_bus.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../services/api_client.dart';
import '../../../services/dict_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../life/models/habit_model.dart';
import '../../life/models/reminder_model.dart';
import '../../life/screens/habits_screen.dart';
import '../../life/screens/reminders_screen.dart';
import '../../novel/models/novel_model.dart';
import '../../novel/screens/novel_reader_screen.dart';
import 'notification_center_screen.dart';
import 'sheets/sheets.dart';
import '../widgets/activity_item.dart';
import '../widgets/tool_card.dart';

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

  @override
  void initState() {
    super.initState();
    DictService.instance.loadFromNetwork();
    _initLoadData();
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

  /// 加载最近阅读的小说（嵌套查询：通过外键一次获取 user_novels + novels）
  Future<void> _loadRecentNovels() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      // 嵌套查询：一次请求获取 user_novels + novels 详情
      final result = await ApiClient.get('user_novels',
          filters: {'user_id': 'eq.$userId', 'is_collected': 'eq.true'},
          select: 'novel_id,last_chapter,progress,last_read_at,novels(id,title,author,cover_url,category)',
          order: 'last_read_at.desc.nullslast',
          limit: 5);

      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      // 直接从嵌套数据中构建结果
      final novels = <Map<String, dynamic>>[];
      for (final item in result.data!) {
        final novelData = item['novels'] as Map<String, dynamic>?;
        if (novelData != null) {
          novels.add({
            'novel': NovelModel.fromJson(novelData),
            'lastChapter': item['last_chapter'] as int? ?? 1,
            'progress': item['progress'] as num? ?? 0.0,
          });
        }
      }

      if (mounted) {
        setState(() {
          _recentNovels = novels;
          _isLoadingNovels = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载最近阅读失败');
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

  /// 显示添加心情日记弹窗
  void _showAddMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMoodSheet(
        onSave: (diary) async {
          try {
            final result = await ApiClient.post(
              'mood_diaries',
              diary.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日记添加成功')),
                );
                _loadRecentActivities();
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

  /// 显示添加支出弹窗
  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseSheet(
        onSave: (expense) async {
          try {
            final result = await ApiClient.post(
              'expenses',
              expense.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('支出添加成功')),
                );
                _loadRecentActivities();
                // 通知生活页刷新最新记账记录
                EventBus.instance.fire(EventType.expenseUpdated);
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

  /// 显示添加体重弹窗
  void _showAddWeightSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddWeightSheet(
        onSave: (record) async {
          try {
            final result = await ApiClient.post(
              'weight_records',
              record.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('体重记录添加成功')),
                );
                _loadRecentActivities();
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

  /// 显示添加笔记弹窗
  void _showAddNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddNoteSheet(
        onSave: (note) async {
          try {
            final result = await ApiClient.post(
              'notes',
              note.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('笔记添加成功')),
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

  /// 显示添加提醒弹窗
  void _showAddReminderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddReminderSheet(
        onSave: (reminder) async {
          try {
            final result = await ApiClient.post(
              'reminders',
              reminder.toJson(),
              returnRepresentation: false,
            );
            if (result.isSuccess) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('提醒添加成功')),
                );
                _loadPendingReminders();
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

  /// 构建欢迎卡片区块，展示用户欢迎语和用户名。
  Widget _buildWelcomeSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎回来',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.instance.currentUserName ?? '用户',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '今天想做些什么？',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 构建待办提醒横幅区块，展示即将到期或已过期的提醒事项。
  Widget _buildTodoReminderSection() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_pendingReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ..._pendingReminders.map((reminder) {
          final isOverdue = reminder.remindAt.isBefore(DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _goToReminderDetail(reminder),
              borderRadius: BorderRadius.circular(12),
              child: Card(
                color: isOverdue ? colorScheme.errorContainer : colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isOverdue ? Icons.notification_important : Icons.notifications_active,
                        color: isOverdue ? colorScheme.error : colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (reminder.description != null && reminder.description!.isNotEmpty)
                              Text(
                                reminder.description!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              DateTimeUtils.formatStandard(reminder.remindAt),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isOverdue ? colorScheme.error : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 构建习惯打卡区块，展示今日待打卡的习惯列表。
  Widget _buildHabitSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final habits = _pendingHabits;

    if (habits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今日打卡',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HabitsScreen()),
                ).then((_) => _loadHabitsForCheckin());
              },
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: habits.map((habit) {
            final habitColor = colorScheme.primary;
            final isChecking = _checkingHabitId == habit.id;

            return SizedBox(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
              height: 52,
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: isChecking ? null : () => _quickCheckIn(habit),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            habit.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isChecking)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          Icon(
                            Icons.check_circle_outline,
                            color: habitColor,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 构建快捷工具网格区块，展示用户配置的常用工具入口。
  Widget _buildQuickToolsSection(List<ToolItem> visibleTools) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '常用工具',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: _showToolConfigSheet,
              tooltip: '配置',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visibleTools.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '点击右上角配置按钮添加工具',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: visibleTools.length,
            itemBuilder: (context, index) {
              final tool = visibleTools[index];
              return ToolCard(
                icon: tool.icon,
                label: tool.label,
                color: tool.color,
                onTap: () => _onToolTap(tool),
              );
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 构建最近阅读区块，展示用户最近阅读的小说列表。
  Widget _buildRecentReadingSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近阅读',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: _isLoadingNovels
              ? SizedBox(
                  height: 180,
                  child: SkeletonLoading.grid(
                    itemCount: 3,
                    crossAxisCount: 3,
                    aspectRatio: 0.75,
                  ),
                )
              : _recentNovels.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无阅读记录',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(12),
                        itemCount: _recentNovels.length,
                        itemBuilder: (context, index) {
                          final item = _recentNovels[index];
                          final novel = item['novel'] as NovelModel;
                          final lastChapter = item['lastChapter'] as int;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => _continueReading(novel, lastChapter),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: novel.cover != null && novel.cover!.isNotEmpty
                                          ? Image.network(
                                              novel.cover!,
                                              height: 100,
                                              width: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 100,
                                                width: 120,
                                                color: colorScheme.surfaceContainerHighest,
                                                child: const Icon(Icons.book, size: 40),
                                              ),
                                            )
                                          : Container(
                                              height: 100,
                                              width: 120,
                                              color: colorScheme.surfaceContainerHighest,
                                              child: const Icon(Icons.book, size: 40),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      novel.title,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '第$lastChapter章',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 构建最近活动区块，展示用户最近的心情日记、支出记录和体重记录。
  Widget _buildRecentActivitySection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近活动',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: _isLoadingActivities
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(3, (i) => Padding(
                      padding: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 12, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
                                const SizedBox(height: 6),
                                Container(width: 120, height: 10, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ),
                )
              : _recentActivities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无最近活动',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: List.generate(_recentActivities.length, (index) {
                          final activity = _recentActivities[index];
                          return Column(
                            children: [
                              ActivityItem(
                                icon: activity['icon'] as IconData,
                                title: activity['title'] as String,
                                subtitle: activity['subtitle'] as String,
                                time: activity['time'] as String,
                              ),
                              if (index < _recentActivities.length - 1)
                                const Divider(),
                            ],
                          );
                        }),
                      ),
                    ),
        ),
      ],
    );
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
            _buildWelcomeSection(),
            _buildTodoReminderSection(),
            _buildHabitSection(),
            _buildQuickToolsSection(visibleTools),
            _buildRecentReadingSection(),
            _buildRecentActivitySection(),
          ],
        ),
      ),
    );
  }
}


