import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/habit_model.dart';

/// 习惯打卡页面 - Supabase 数据同步
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<HabitModel> _habits = [];
  Map<String, List<HabitCheckinModel>> _checkinHistory = {};
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) {
        setState(() {
          _habits = [];
          _checkinHistory = {};
          _isLoading = false;
        });
        return;
      }

      // 加载习惯列表
      final habitsResponse = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/user_habits?user_id=eq.$userId&select=*&order=is_active.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (habitsResponse.statusCode != 200) {
        throw Exception('HTTP ${habitsResponse.statusCode}');
      }

      final List habitsData = jsonDecode(habitsResponse.body);
      final items = habitsData.map((e) => HabitModel.fromJson(e)).toList();

      // 加载所有打卡记录
      final history = <String, List<HabitCheckinModel>>{};
      for (final habit in items) {
        final checkinsResponse = await http.get(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/habit_checkins?habit_id=eq.${habit.id}&select=*&order=checkin_at.desc',
          ),
          headers: SupabaseConfig.headers,
        );

        if (checkinsResponse.statusCode == 200) {
          final List checkinsData = jsonDecode(checkinsResponse.body);
          history[habit.id] = checkinsData.map((e) => HabitCheckinModel.fromJson(e)).toList();
        } else {
          history[habit.id] = [];
        }
      }

      setState(() {
        _habits = items;
        _checkinHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('加载习惯失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _checkIn(HabitModel habit) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 检查今天是否已经打卡
      final checkins = _checkinHistory[habit.id] ?? [];
      final alreadyChecked = checkins.any((c) {
        final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
        return dateStr == todayStr;
      });

      if (alreadyChecked) {
        _showError('今天已经打卡了');
        return;
      }

      // 添加打卡记录
      final checkinId = const Uuid().v4();
      final checkinResponse = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/habit_checkins'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'id': checkinId,
          'habit_id': habit.id,
          'checkin_at': today.toUtc().toIso8601String(),
        }),
      );

      if (checkinResponse.statusCode != 201 && checkinResponse.statusCode != 200) {
        throw Exception('添加打卡记录失败: HTTP ${checkinResponse.statusCode}');
      }

      _loadHabits();

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 打卡成功！'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('打卡失败: $e');
    }
  }

  Future<void> _deleteHabit(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个习惯吗？相关打卡记录也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 先删除打卡记录
        await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/habit_checkins?habit_id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        // 再删除习惯
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/user_habits?id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          _loadHabits();
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({HabitModel? habit}) async {
    final isEditing = habit != null;
    final nameController = TextEditingController(text: habit?.name ?? '');
    final descController = TextEditingController(text: habit?.description ?? '');
    final targetDaysController = TextEditingController(
      text: (habit?.targetDays ?? 21).toString(),
    );
    bool enableReminder = habit?.reminderEnabled ?? false;
    int reminderHour = habit?.reminderHour ?? 9;
    int reminderMinute = habit?.reminderMinute ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑习惯' : '添加习惯'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '习惯名称 *',
                    hintText: '例如：早起、阅读、运动',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '输入习惯描述（可选）',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetDaysController,
                  decoration: const InputDecoration(
                    labelText: '目标天数',
                    hintText: '例如：21',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                // 提醒设置
                SwitchListTile(
                  title: const Text('每日打卡提醒'),
                  subtitle: Text(enableReminder
                      ? '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')} 提醒'
                      : '关闭'),
                  contentPadding: EdgeInsets.zero,
                  value: enableReminder,
                  onChanged: (value) {
                    setDialogState(() => enableReminder = value);
                  },
                ),
                if (enableReminder)
                  Row(
                    children: [
                      const Text('提醒时间: '),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: reminderHour,
                        items: List.generate(24, (h) => DropdownMenuItem(
                          value: h,
                          child: Text('$h 时', style: const TextStyle(fontSize: 14)),
                        )),
                        onChanged: (v) => setDialogState(() => reminderHour = v ?? 9),
                        underline: const SizedBox(),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: reminderMinute,
                        items: [0, 15, 30, 45].map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m 分', style: const TextStyle(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => reminderMinute = v ?? 0),
                        underline: const SizedBox(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showError('请输入习惯名称');
                  return;
                }

                final targetDays = int.tryParse(targetDaysController.text) ?? 21;
                final userId = _userId ?? 'local_user';

                try {
                  if (isEditing) {
                    final response = await http.patch(
                      Uri.parse('${SupabaseConfig.url}/rest/v1/user_habits?id=eq.${habit.id}'),
                      headers: SupabaseConfig.writeHeaders,
                      body: jsonEncode({
                        'name': nameController.text.trim(),
                        'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                        'target_days': targetDays,
                        'reminder_enabled': enableReminder,
                        'reminder_hour': enableReminder ? reminderHour : null,
                        'reminder_minute': enableReminder ? reminderMinute : null,
                      }),
                    );
                    if (response.statusCode != 200 && response.statusCode != 204) {
                      throw Exception('HTTP ${response.statusCode}');
                    }
                    // 设置/取消通知
                    if (enableReminder) {
                      await NotificationService.instance.setHabitReminder(
                        habitId: habit.id,
                        habitName: nameController.text.trim(),
                        hour: reminderHour,
                        minute: reminderMinute,
                      );
                    } else {
                      await NotificationService.instance.cancelHabitReminder(habit.id);
                    }
                  } else {
                    final habitId = const Uuid().v4();
                    final response = await http.post(
                      Uri.parse('${SupabaseConfig.url}/rest/v1/user_habits'),
                      headers: SupabaseConfig.writeHeaders,
                      body: jsonEncode({
                        'id': habitId,
                        'user_id': userId,
                        'name': nameController.text.trim(),
                        'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                        'target_days': targetDays,
                        'frequency': 'daily',
                        'is_active': true,
                        'reminder_enabled': enableReminder,
                        'reminder_hour': enableReminder ? reminderHour : null,
                        'reminder_minute': enableReminder ? reminderMinute : null,
                      }),
                    );
                    if (response.statusCode != 201 && response.statusCode != 200) {
                      throw Exception('HTTP ${response.statusCode}');
                    }
                    // 设置通知
                    if (enableReminder) {
                      await NotificationService.instance.setHabitReminder(
                        habitId: habitId,
                        habitName: nameController.text.trim(),
                        hour: reminderHour,
                        minute: reminderMinute,
                      );
                    }
                  }
                  Navigator.pop(context);
                  _loadHabits();
                } catch (e) {
                  _showError('保存失败: $e');
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoryDialog(HabitModel habit) async {
    final checkins = _checkinHistory[habit.id] ?? [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${habit.name} 打卡记录'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: checkins.isEmpty
              ? const Center(child: Text('暂无打卡记录'))
              : ListView.builder(
                  itemCount: checkins.length,
                  itemBuilder: (context, index) {
                    final checkin = checkins[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(DateTimeUtils.formatStandard(checkin.checkinAt)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  bool _isCheckedInToday(String habitId) {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final checkins = _checkinHistory[habitId] ?? [];
    return checkins.any((c) {
      final dateStr = '${c.checkinAt.year}-${c.checkinAt.month.toString().padLeft(2, '0')}-${c.checkinAt.day.toString().padLeft(2, '0')}';
      return dateStr == todayStr;
    });
  }

  int _getTotalCheckins(String habitId) {
    return _checkinHistory[habitId]?.length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯打卡'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.track_changes_outlined,
                        size: 64,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有习惯',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击右下角添加新习惯',
                        style: TextStyle(
                          color: colorScheme.outline.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _habits.length,
                  itemBuilder: (context, index) {
                    final habit = _habits[index];
                    final isCheckedIn = _isCheckedInToday(habit.id);
                    final totalCheckins = _getTotalCheckins(habit.id);
                    return _HabitCard(
                      habit: habit,
                      isCheckedIn: isCheckedIn,
                      totalCheckins: totalCheckins,
                      onCheckIn: () => _checkIn(habit),
                      onEdit: () => _showEditDialog(habit: habit),
                      onDelete: () => _deleteHabit(habit.id),
                      onViewHistory: () => _showHistoryDialog(habit),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCheckedIn;
  final int totalCheckins;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  const _HabitCard({
    required this.habit,
    required this.isCheckedIn,
    required this.totalCheckins,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = Color(habitColors['blue']!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: habitColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.track_changes,
                    color: habitColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              habit.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (!habit.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '已暂停',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (habit.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          habit.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'history':
                        onViewHistory();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'history',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text('打卡记录'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: '目标天数',
                  value: '${habit.targetDays}',
                  icon: Icons.flag,
                  color: Colors.blue,
                ),
                _StatItem(
                  label: '总打卡',
                  value: '$totalCheckins',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _StatItem(
                  label: '频率',
                  value: habit.frequency == 'daily' ? '每天' : habit.frequency,
                  icon: Icons.calendar_today,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: habit.targetDays > 0 ? totalCheckins / habit.targetDays : 0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '进度: $totalCheckins/${habit.targetDays} 天 (${habit.targetDays > 0 ? ((totalCheckins / habit.targetDays) * 100).toInt() : 0}%)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isCheckedIn ? null : onCheckIn,
                icon: Icon(isCheckedIn ? Icons.check : Icons.add),
                label: Text(isCheckedIn ? '今日已打卡' : '立即打卡'),
                style: FilledButton.styleFrom(
                  backgroundColor: isCheckedIn ? Colors.green : habitColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
