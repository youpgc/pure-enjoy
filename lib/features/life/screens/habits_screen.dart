import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/habit_model.dart';
import '../../../services/database_service.dart';
import '../../../services/supabase_service.dart';

/// 习惯打卡页面
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final DatabaseService _db = DatabaseService.instance;
  List<HabitModel> _habits = [];
  Map<String, List<DateTime>> _checkinHistory = {};
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        setState(() {
          _habits = [];
          _checkinHistory = {};
          _isLoading = false;
        });
        return;
      }
      final items = await _db.getHabits(userId);
      final history = <String, List<DateTime>>{};
      
      for (final habit in items) {
        final checkins = await _db.getHabitCheckins(habit.id);
        history[habit.id] = checkins.map((c) => c.checkinAt).toList();
      }
      
      setState(() {
        _habits = items..sort((a, b) {
          if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
          return b.currentStreak.compareTo(a.currentStreak);
        });
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
      final todayDate = DateTime(today.year, today.month, today.day);
      
      // 检查今天是否已经打卡
      final todayCheckins = _checkinHistory[habit.id]?.where((d) {
        final checkinDate = DateTime(d.year, d.month, d.day);
        return checkinDate == todayDate;
      }).toList() ?? [];
      
      if (todayCheckins.isNotEmpty) {
        _showError('今天已经打卡了');
        return;
      }

      // 更新习惯数据
      final updatedHabit = habit.checkIn();
      await _db.updateHabit(updatedHabit);
      
      // 添加打卡记录
      final userId = AuthService.instance.currentUserId ?? 'local_user';
      final checkin = HabitCheckinModel(
        id: const Uuid().v4(),
        habitId: habit.id,
        userId: userId,
        checkinAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _db.insertHabitCheckin(checkin);
      
      _loadHabits();
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${habit.name} 打卡成功！连续 ${updatedHabit.currentStreak} 天'),
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
        await _db.deleteHabit(id);
        _loadHabits();
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
    String frequency = habit?.frequency ?? 'daily';
    String color = habit?.color ?? 'blue';

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
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: '频率'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('每天')),
                    DropdownMenuItem(value: 'weekly', child: Text('每周')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => frequency = value);
                    }
                  },
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
                const SizedBox(height: 12),
                const Text('选择颜色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: habitColors.entries.map((entry) {
                    final isSelected = color == entry.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => color = entry.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(entry.value),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
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
                final userId = AuthService.instance.currentUserId ?? 'local_user';

                final newHabit = HabitModel(
                  id: isEditing ? habit.id : const Uuid().v4(),
                  userId: isEditing ? habit.userId : userId,
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  frequency: frequency,
                  targetDays: targetDays,
                  currentStreak: habit?.currentStreak ?? 0,
                  maxStreak: habit?.maxStreak ?? 0,
                  totalCheckins: habit?.totalCheckins ?? 0,
                  color: color,
                  isActive: habit?.isActive ?? true,
                  createdAt: isEditing ? habit.createdAt : DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  if (isEditing) {
                    await _db.updateHabit(newHabit);
                  } else {
                    await _db.insertHabit(newHabit);
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
                    final checkin = checkins.reversed.toList()[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(DateFormat('yyyy-MM-dd HH:mm').format(checkin)),
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
    final todayDate = DateTime(today.year, today.month, today.day);
    
    final checkins = _checkinHistory[habitId] ?? [];
    return checkins.any((d) {
      final checkinDate = DateTime(d.year, d.month, d.day);
      return checkinDate == todayDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯打卡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '查看日历',
            onPressed: () => _showCalendarView(),
          ),
        ],
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
                    return _HabitCard(
                      habit: habit,
                      isCheckedIn: isCheckedIn,
                      checkinHistory: _checkinHistory[habit.id] ?? [],
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

  void _showCalendarView() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _CalendarView(
            habits: _habits,
            checkinHistory: _checkinHistory,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitModel habit;
  final bool isCheckedIn;
  final List<DateTime> checkinHistory;
  final VoidCallback onCheckIn;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewHistory;

  const _HabitCard({
    required this.habit,
    required this.isCheckedIn,
    required this.checkinHistory,
    required this.onCheckIn,
    required this.onEdit,
    required this.onDelete,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = Color(habitColors[habit.color] ?? habitColors['blue']!);
    final progress = habit.progress;

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
                  label: '当前连击',
                  value: '${habit.currentStreak}',
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                ),
                _StatItem(
                  label: '最高连击',
                  value: '${habit.maxStreak}',
                  icon: Icons.emoji_events,
                  color: Colors.amber,
                ),
                _StatItem(
                  label: '总打卡',
                  value: '${habit.totalCheckins}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '目标: ${habit.currentStreak}/${habit.targetDays} 天 (${(progress * 100).toInt()}%)',
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

class _CalendarView extends StatefulWidget {
  final List<HabitModel> habits;
  final Map<String, List<DateTime>> checkinHistory;
  final ScrollController scrollController;

  const _CalendarView({
    required this.habits,
    required this.checkinHistory,
    required this.scrollController,
  });

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];
    
    // 添加月初之前的空白日期
    final firstWeekday = firstDay.weekday % 7;
    for (int i = 0; i < firstWeekday; i++) {
      days.add(DateTime(month.year, month.month, 0 - i));
    }
    days.sort();
    
    // 添加当月日期
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    
    return days;
  }

  int _getCheckinCount(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    int count = 0;
    
    for (final habit in widget.habits) {
      final checkins = widget.checkinHistory[habit.id] ?? [];
      if (checkins.any((d) {
        final checkinDate = DateTime(d.year, d.month, d.day);
        return checkinDate == dateOnly;
      })) {
        count++;
      }
    }
    
    return count;
  }

  Color _getHeatmapColor(int count, int totalHabits) {
    if (count == 0) return Colors.grey.withOpacity(0.1);
    if (totalHabits == 0) return Colors.grey.withOpacity(0.1);
    
    final intensity = count / totalHabits;
    if (intensity >= 0.8) return Colors.green.shade700;
    if (intensity >= 0.6) return Colors.green.shade500;
    if (intensity >= 0.4) return Colors.green.shade300;
    return Colors.green.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_selectedMonth);
    final monthName = DateFormat('yyyy年M月').format(_selectedMonth);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  monthName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          // 星期标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => SizedBox(
                        width: 40,
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 日历网格
          Expanded(
            child: GridView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final isCurrentMonth = day.month == _selectedMonth.month;
                final checkinCount = _getCheckinCount(day);
                
                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isCurrentMonth
                        ? _getHeatmapColor(checkinCount, widget.habits.length)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isCurrentMonth
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: checkinCount > 0
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (checkinCount > 0)
                                Text(
                                  '$checkinCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          // 图例
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('打卡强度: ', style: TextStyle(fontSize: 12)),
                Container(width: 16, height: 16, color: Colors.green.shade100),
                Container(width: 16, height: 16, color: Colors.green.shade300),
                Container(width: 16, height: 16, color: Colors.green.shade500),
                Container(width: 16, height: 16, color: Colors.green.shade700),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
