import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../config.dart';
import '../../life/screens/life_screen.dart';
import '../../life/screens/reminders_screen.dart';
import '../../life/screens/favorites_screen.dart';
import '../../novel/screens/book_shelf_screen.dart';
import '../../novel/screens/novel_reader_screen.dart';
import '../../../services/supabase_service.dart';
import '../../../services/data_export_service.dart';
import '../../../services/version_check_service.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import 'reading_history_screen.dart';
import 'notification_center_screen.dart';
import 'settings_screen.dart';
import '../../life/models/mood_diary_model.dart';
import '../../life/models/expense_model.dart';
import '../../life/models/weight_record_model.dart';
import '../../life/models/note_model.dart';
import '../../life/models/reminder_model.dart';
import '../../life/models/habit_model.dart';
import '../../novel/models/novel_model.dart';
import '../../../utils/date_time_utils.dart';
import '../profile/screens/point_records_screen.dart';

/// 首页 - 主导航页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    LifeScreen(),
    BookShelfScreen(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 应用启动时检查更新
    _checkForUpdate();
  }

  /// 检查应用更新
  void _checkForUpdate() async {
    final versionInfo = await VersionCheckService.instance.checkUpdate();
    if (versionInfo != null && mounted) {
      VersionCheckService.instance.showUpdateDialog(context, versionInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '生活',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 工具项定义
class _ToolItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _ToolItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_ToolItem> _allTools = [
  _ToolItem(id: 'diary', label: '写日记', icon: Icons.note_add_outlined, color: Color(0xFFFFB300)),
  _ToolItem(id: 'expense', label: '记一笔', icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50)),
  _ToolItem(id: 'weight', label: '记体重', icon: Icons.monitor_weight_outlined, color: Color(0xFFF26522)),
  _ToolItem(id: 'note', label: '记笔记', icon: Icons.sticky_note_2_outlined, color: Color(0xFFF26522)),
  _ToolItem(id: 'reminder', label: '添加提醒', icon: Icons.alarm_add_outlined, color: Color(0xFFFFB300)),
  _ToolItem(id: 'habit', label: '添加习惯', icon: Icons.track_changes_outlined, color: Color(0xFFFF9800)),
];

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

  bool _isLoadingReminders = true;
  List<ReminderModel> _pendingReminders = [];

  bool _isLoadingNovels = true;
  List<Map<String, dynamic>> _recentNovels = [];

  List<String> _visibleToolIds = [];

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
    _loadPendingReminders();
    _loadRecentNovels();
    _loadToolConfig();
  }

  /// 加载工具配置
  Future<void> _loadToolConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKeyTools);
    if (saved != null && saved.isNotEmpty) {
      if (mounted) setState(() => _visibleToolIds = saved);
    } else {
      // 默认全部显示
      if (mounted) setState(() => _visibleToolIds = _allTools.map((t) => t.id).toList());
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

      final headers = {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
      };

      // 并行查询 expenses、mood_diaries、weight_records 各最新一条
      final futures = [
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/expenses?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/mood_diaries?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/weight_records?user_id=eq.$userId&select=*,created_at&order=created_at.desc&limit=1',
          ),
          headers: headers,
        ),
      ];

      final responses = await Future.wait(futures);

      final activities = <Map<String, dynamic>>[];

      // 解析心情日记
      final diaryResponse = responses[1];
      if (diaryResponse.statusCode == 200) {
        final list = jsonDecode(diaryResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.edit_note,
            'title': '心情日记',
            'subtitle': item['content'] ?? item['mood']?.toString() ?? '记录了一条心情',
            'time': _formatTime(item['created_at']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      // 解析支出记录
      final expenseResponse = responses[0];
      if (expenseResponse.statusCode == 200) {
        final list = jsonDecode(expenseResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.attach_money,
            'title': '支出记录',
            'subtitle': '${item['category'] ?? '其他'} ¥${item['amount'] ?? 0}',
            'time': _formatTime(item['created_at']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      // 解析体重记录
      final weightResponse = responses[2];
      if (weightResponse.statusCode == 200) {
        final list = jsonDecode(weightResponse.body) as List;
        if (list.isNotEmpty) {
          final item = list[0] as Map<String, dynamic>;
          activities.add({
            'icon': Icons.monitor_weight,
            'title': '体重记录',
            'subtitle': '${item['weight'] ?? 0} kg',
            'time': _formatTime(item['created_at']),
            'created_at_raw': item['created_at'] as String? ?? '',
          });
        }
      }

      // 按时间排序
      activities.sort((a, b) => (b['created_at_raw'] as String).compareTo(a['created_at_raw'] as String));

      if (mounted) {
        setState(() {
          _recentActivities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      print('加载最近活动失败: $e');
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
        if (mounted) setState(() => _isLoadingReminders = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/user_reminders?user_id=eq.$userId&is_completed=eq.false&select=*&order=remind_at.asc&limit=3',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final reminders = data.map((e) => ReminderModel.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _pendingReminders = reminders;
            _isLoadingReminders = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('加载提醒失败: $e');
      if (mounted) setState(() => _isLoadingReminders = false);
    }
  }

  /// 加载最近阅读的小说
  Future<void> _loadRecentNovels() async {
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoadingNovels = false);
        return;
      }

      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/user_novels?user_id=eq.$userId&select=*,novels:novel_id(*)&order=last_read_at.desc&limit=5',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final novels = <Map<String, dynamic>>[];
        for (final item in data) {
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
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('加载最近阅读失败: $e');
      if (mounted) setState(() => _isLoadingNovels = false);
    }
  }

  /// 格式化时间显示
  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final dateTime = DateTime.tryParse(createdAt)?.toLocal();
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dateTime.month}/${dateTime.day}';
  }

  /// 显示添加心情日记弹窗
  void _showAddMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMoodSheet(
        onSave: (diary) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/mood_diaries'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(diary.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日记添加成功')),
                );
                _loadRecentActivities();
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
      builder: (context) => _AddExpenseSheet(
        onSave: (expense) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/expenses'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(expense.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('支出添加成功')),
                );
                _loadRecentActivities();
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
      builder: (context) => _AddWeightSheet(
        onSave: (record) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/weight_records'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(record.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('体重记录添加成功')),
                );
                _loadRecentActivities();
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
      builder: (context) => _AddNoteSheet(
        onSave: (note) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/notes'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(note.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('笔记添加成功')),
                );
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
      builder: (context) => _AddReminderSheet(
        onSave: (reminder) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_reminders'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(reminder.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('提醒添加成功')),
                );
                _loadPendingReminders();
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
      builder: (context) => _AddHabitSheet(
        onSave: (habit) async {
          try {
            final response = await http.post(
              Uri.parse('${AppConfig.supabaseUrl}/rest/v1/user_habits'),
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal',
              },
              body: jsonEncode(habit.toJson()),
            );
            if (response.statusCode == 201 || response.statusCode == 200) {
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('习惯添加成功')),
                );
              }
            } else {
              throw Exception('HTTP ${response.statusCode}');
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
  void _onToolTap(_ToolItem tool) {
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
      builder: (context) => _ToolConfigSheet(
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
    );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final visibleTools = _allTools.where((t) => _visibleToolIds.contains(t.id)).toList();

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
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRecentActivities();
          await _loadPendingReminders();
          await _loadRecentNovels();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 欢迎卡片
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

            // 横幅通知区域 - 待办提醒
            if (_pendingReminders.isNotEmpty) ...[
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

            // 常用工具
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
                  return _ToolCard(
                    icon: tool.icon,
                    label: tool.label,
                    color: tool.color,
                    onTap: () => _onToolTap(tool),
                  );
                },
              ),
            const SizedBox(height: 24),

            // 最近阅读
            Text(
              '最近阅读',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: _isLoadingNovels
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
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

            // 最近活动
            Text(
              '最近活动',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: _isLoadingActivities
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
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
                                  _ActivityItem(
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
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// 工具配置弹窗
class _ToolConfigSheet extends StatefulWidget {
  final List<String> visibleIds;
  final ValueChanged<List<String>> onSave;

  const _ToolConfigSheet({
    required this.visibleIds,
    required this.onSave,
  });

  @override
  State<_ToolConfigSheet> createState() => _ToolConfigSheetState();
}

class _ToolConfigSheetState extends State<_ToolConfigSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.visibleIds);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '配置常用工具',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '选择要在首页显示的工具',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _allTools.map((tool) {
              final isSelected = _selectedIds.contains(tool.id);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tool.icon, size: 16, color: isSelected ? Colors.white : tool.color),
                    const SizedBox(width: 6),
                    Text(tool.label),
                  ],
                ),
                selected: isSelected,
                selectedColor: tool.color,
                checkmarkColor: Colors.white,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedIds.add(tool.id);
                    } else {
                      _selectedIds.remove(tool.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.onSave(_selectedIds);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// 添加心情日记底部弹窗
class _AddMoodSheet extends StatefulWidget {
  final Function(MoodDiaryModel) onSave;

  const _AddMoodSheet({required this.onSave});

  @override
  State<_AddMoodSheet> createState() => _AddMoodSheetState();
}

class _AddMoodSheetState extends State<_AddMoodSheet> {
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  MoodType _selectedMood = MoodType.calm;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final diary = MoodDiaryModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      mood: _selectedMood.name,
      moodScore: _selectedMood.score,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      tags: tags.isEmpty ? null : tags,
      entryDate: _selectedDate,
    );

    widget.onSave(diary);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('写日记', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('今天心情如何？', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MoodType.values.map((mood) => ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mood.emoji),
                  const SizedBox(width: 4),
                  Text(mood.label),
                ],
              ),
              selected: _selectedMood == mood,
              selectedColor: mood.color.withOpacity(0.3),
              onSelected: (selected) {
                if (selected) setState(() => _selectedMood = mood);
              },
            )).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '写点什么...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: '标签（可选，逗号分隔）',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

/// 添加支出底部弹窗
class _AddExpenseSheet extends StatefulWidget {
  final Function(ExpenseModel) onSave;

  const _AddExpenseSheet({required this.onSave});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final expense = ExpenseModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      amount: double.parse(_amountController.text),
      category: _selectedCategory.name,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: _selectedDate,
    );

    widget.onSave(expense);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('记一笔', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入金额';
                if (double.tryParse(value) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text('分类', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ExpenseCategory.values.map((cat) => ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 16),
                    const SizedBox(width: 4),
                    Text(cat.label),
                  ],
                ),
                selected: _selectedCategory == cat,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              )).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

/// 添加体重底部弹窗
class _AddWeightSheet extends StatefulWidget {
  final Function(WeightRecordModel) onSave;

  const _AddWeightSheet({required this.onSave});

  @override
  State<_AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<_AddWeightSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _bmiController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _bmiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final record = WeightRecordModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      weight: double.parse(_weightController.text),
      bmi: _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
      bodyFat: _bodyFatController.text.isNotEmpty ? double.tryParse(_bodyFatController.text) : null,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      date: _selectedDate,
    );

    widget.onSave(record);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('记体重', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '体重 (kg)',
                suffixText: 'kg',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入体重';
                if (double.tryParse(value) == null) return '请输入有效数字';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '体脂率（可选）',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bmiController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'BMI（可选）'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注（可选）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              trailing: Text(DateTimeUtils.formatDate(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

/// 添加笔记底部弹窗
class _AddNoteSheet extends StatefulWidget {
  final Function(NoteModel) onSave;

  const _AddNoteSheet({required this.onSave});

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final note = NoteModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      title: _titleController.text,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      tags: tags.isEmpty ? null : tags,
    );

    widget.onSave(note);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('记笔记', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '输入笔记标题',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '内容',
              hintText: '写点什么...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: '标签（可选，逗号分隔）',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

/// 添加提醒底部弹窗
class _AddReminderSheet extends StatefulWidget {
  final Function(ReminderModel) onSave;

  const _AddReminderSheet({required this.onSave});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _remindAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final reminder = ReminderModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      title: _titleController.text,
      description: _descController.text.isEmpty ? null : _descController.text,
      remindAt: _remindAt,
    );

    widget.onSave(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('添加提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题'),
              validator: (v) => v?.isEmpty == true ? '请输入标题' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒时间'),
              trailing: Text(DateTimeUtils.formatStandard(_remindAt)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _remindAt,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_remindAt),
                  );
                  if (time != null) {
                    setState(() {
                      _remindAt = DateTime(
                        date.year, date.month, date.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}

/// 添加习惯底部弹窗
class _AddHabitSheet extends StatefulWidget {
  final Function(HabitModel) onSave;

  const _AddHabitSheet({required this.onSave});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _targetDaysController = TextEditingController(text: '21');

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _targetDaysController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入习惯名称')),
      );
      return;
    }

    final targetDays = int.tryParse(_targetDaysController.text) ?? 21;

    final habit = HabitModel(
      id: const Uuid().v4(),
      userId: AuthService.instance.currentUserId ?? 'local_user',
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      targetDays: targetDays,
      frequency: 'daily',
      isActive: true,
    );

    widget.onSave(habit);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加习惯', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '习惯名称 *',
              hintText: '例如：早起、阅读、运动',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '描述（可选）',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetDaysController,
            decoration: const InputDecoration(
              labelText: '目标天数',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

/// 我的页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _currentVersion = '1.0.0';
  String _latestVersion = '';
  bool _hasUpdate = false;
  bool _isForceUpdate = false;
  String? _apkUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _checkVersion();
    _loadUserData();
  }

  /// 从 Supabase 重新加载用户数据
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    await SupabaseService.instance.reloadCurrentUser();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 加载当前版本
  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      print('获取版本信息失败: $e');
    }
  }

  /// 检查最新版本
  Future<void> _checkVersion() async {
    try {
      final versionInfo = await VersionCheckService.instance.checkUpdate();
      if (versionInfo != null && mounted) {
        setState(() {
          _latestVersion = versionInfo['version'] ?? '';
          _hasUpdate = true;
          _isForceUpdate = versionInfo['is_force_update'] == true;
          _apkUrl = versionInfo['apk_url'];
        });
      }
    } catch (e) {
      print('检查版本失败: $e');
    }
  }

  /// 显示版本信息对话框
  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('版本信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: $_currentVersion'),
            if (_hasUpdate) ...[
              const SizedBox(height: 8),
              Text('最新版本: $_latestVersion'),
              if (_isForceUpdate)
                Text(
                  '【强制更新】',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                ),
            ],
          ],
        ),
        actions: [
          if (_hasUpdate && _apkUrl != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadAndInstall();
              },
              child: const Text('立即更新'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 下载并安装APK（内部下载）
  Future<void> _downloadAndInstall() async {
    if (_apkUrl == null) return;

    // 显示下载进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(apkUrl: _apkUrl!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService.instance;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // 用户信息卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildAvatar(colorScheme, supabaseService),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supabaseService.currentUserName ?? '用户',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supabaseService.currentUserEmail ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        // 重新从 Supabase 加载用户数据
                        _loadUserData();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // 用户信息展示列
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatItem(Icons.stars_outlined, '角色', _getRoleLabel(supabaseService.currentRole), onTap: () {}),
                _buildStatItem(Icons.workspace_premium_outlined, '会员', _getMemberLevelLabel(supabaseService.currentMemberLevel), onTap: () {}),
                _buildStatItem(Icons.monetization_on_outlined, '积分', '${supabaseService.currentPoints ?? 0}', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PointRecordsScreen()));
                }),
              ],
            ),
          ),

          // 功能列表 - 个人中心
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '个人中心',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('我的收藏'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('阅读历史'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
              );
            },
          ),
          
          // 版本信息 - 带更新提示（保留在我的页面，方便查看）
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('版本信息'),
            subtitle: Text('当前: $_currentVersion${_hasUpdate ? ' · 有新版本' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasUpdate)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showVersionDialog,
          ),
          
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: colorScheme.error,
            ),
            title: Text(
              '退出登录',
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认退出'),
                  content: const Text('确定要退出登录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await supabaseService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('退出登录失败: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ExportBottomSheet(),
    );
  }

  void _showThemeDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ThemeSettingsScreen()),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(IconData icon, String label, String value, {required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取角色标签
  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'super_admin':
        return '超级管理员';
      default:
        return '普通用户';
    }
  }

  /// 获取会员等级标签
  String _getMemberLevelLabel(String? level) {
    switch (level) {
      case 'member':
        return '高级会员';
      case 'super_member':
        return '超级会员';
      default:
        return '普通会员';
    }
  }

  /// 构建用户头像
  Widget _buildAvatar(ColorScheme colorScheme, SupabaseService supabaseService) {
    final avatarUrl = supabaseService.currentUserAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: colorScheme.primaryContainer,
      );
    }
    return CircleAvatar(
      radius: 32,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: 32,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }

}

/// 个性化设置页面
class _ThemeSettingsScreen extends StatelessWidget {
  const _ThemeSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个性化设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== 主题模式 ======
          _SectionTitle(title: '主题模式'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Column(
                children: [
                  _ThemeModeTile(
                    icon: Icons.brightness_auto,
                    title: '跟随系统',
                    selected: tp.themeMode == ThemeMode.system,
                    onTap: () => tp.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(height: 1),
                  _ThemeModeTile(
                    icon: Icons.light_mode,
                    title: '浅色模式',
                    selected: tp.themeMode == ThemeMode.light,
                    onTap: () => tp.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(height: 1),
                  _ThemeModeTile(
                    icon: Icons.dark_mode,
                    title: '深色模式',
                    selected: tp.themeMode == ThemeMode.dark,
                    onTap: () => tp.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 配色方案 ======
          _SectionTitle(title: '配色方案'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppColorScheme.values.map((scheme) {
                  final isSelected = tp.colorScheme == scheme;
                  return GestureDetector(
                    onTap: () => tp.setColorScheme(scheme),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.seedColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: scheme.seedColor, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: scheme.seedColor.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scheme.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? scheme.seedColor
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 字体大小 ======
          _SectionTitle(title: '字体大小'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('小'),
                        Text(
                          '${(tp.fontScale * 100).toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Text('大'),
                      ],
                    ),
                    Slider(
                      value: tp.fontScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: '${(tp.fontScale * 100).toInt()}%',
                      onChanged: (value) => tp.setFontScale(value),
                    ),
                    // 预览文本
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '预览文本：纯享，记录生活每一天',
                        style: TextStyle(fontSize: 14 * tp.fontScale),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ====== 阅读背景 ======
          _SectionTitle(title: '阅读背景'),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, tp, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ReaderBackgroundTheme.values.map((bg) {
                  final isSelected = tp.readerBg == bg;
                  return GestureDetector(
                    onTap: () => tp.setReaderBackground(bg),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bg.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Aa',
                              style: TextStyle(
                                color: bg.textColor,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bg.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// 分区标题
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// 主题模式选项
class _ThemeModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// 数据导出底部弹窗
class _ExportBottomSheet extends StatefulWidget {
  const _ExportBottomSheet();

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  bool _isLoading = true;
  Map<String, int> _counts = {};
  bool _isExporting = false;

  static const _typeLabels = {
    DataExportService.typeExpenses: '消费记录',
    DataExportService.typeWeight: '体重记录',
    DataExportService.typeMood: '心情日记',
  };

  static const _typeIcons = {
    DataExportService.typeExpenses: Icons.receipt_long,
    DataExportService.typeWeight: Icons.monitor_weight,
    DataExportService.typeMood: Icons.mood,
  };

  static const _typeColors = {
    DataExportService.typeExpenses: Color(0xFFFFB300),
    DataExportService.typeWeight: Color(0xFFF26522),
    DataExportService.typeMood: Color(0xFFF26522),
  };

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final counts = await DataExportService.getDataCounts();
    if (mounted) {
      setState(() {
        _counts = counts;
        _isLoading = false;
      });
    }
  }

  Future<void> _export(String type) async {
    setState(() => _isExporting = true);

    final result = await DataExportService.exportAndShare(type: type);

    if (mounted) {
      setState(() => _isExporting = false);

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功！共 ${result.count} 条数据'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败：${result.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Text(
            '数据导出',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '选择要导出的数据类型',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 20),

          // 数据类型列表
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            ..._typeLabels.keys.map((type) {
                    final count = _counts[type] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (_typeColors[type] ?? Theme.of(context).colorScheme.onSurfaceVariant).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _typeIcons[type] ?? Icons.data_usage,
                              color: _typeColors[type],
                            ),
                          ),
                          title: Text(_typeLabels[type] ?? type),
                          subtitle: Text('$count 条记录'),
                          trailing: const Icon(Icons.share, size: 20),
                          onTap: _isExporting ? null : () => _export(type),
                        ),
                      ),
                    );
                  }),

          // 导出全部按钮
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isExporting ? null : () => _export(DataExportService.typeAll),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isExporting ? '导出中...' : '导出全部数据'),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;

  const _DownloadProgressDialog({required this.apkUrl});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String _status = '准备下载...';
  bool _isComplete = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final versionService = VersionCheckService.instance;

      // 监听进度
      versionService.downloadProgress.addListener(() {
        if (mounted) {
          setState(() {
            _progress = versionService.downloadProgress.value;
          });
        }
      });

      // 监听状态
      versionService.downloadStatus.addListener(() {
        if (mounted) {
          setState(() {
            _status = versionService.downloadStatus.value;
          });
        }
      });

      // 开始下载和安装
      await versionService.downloadAndInstall(context, widget.apkUrl);

      if (mounted) {
        setState(() {
          _isComplete = true;
        });

        // 延迟关闭对话框
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = '更新失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('应用更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete && !_hasError) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 16),
          ],
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _hasError ? Theme.of(context).colorScheme.error : null,
              fontWeight: _isComplete || _hasError ? FontWeight.bold : null,
            ),
          ),
          if (_isComplete) ...[
            const SizedBox(height: 8),
            Icon(Icons.check_circle, color: AppTheme.success, size: 48),
          ],
        ],
      ),
      actions: [
        if (_hasError || _isComplete)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
