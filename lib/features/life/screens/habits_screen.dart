import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/cache_helper.dart';
import '../models/habit_model.dart';

/// 习惯页面 - Supabase 数据同步
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<HabitModel> _habits = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    await _loadCache();
    await _loadHabits();
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyHabits);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _habits = cached.map((e) => HabitModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHabits() async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/habits?user_id=eq.$userId&select=*&order=created_at.desc',
        ),
        headers: SupabaseConfig.headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final habits = data.map((e) => HabitModel.fromJson(e)).toList();

        setState(() {
          _habits = habits;
          _isLoading = false;
        });

        // 写入缓存
        await CacheHelper.instance.saveList(
          CacheHelper.keyHabits,
          habits.map((h) => h.toJson()).toList(),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _addHabit(HabitModel habit) async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/habits'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode(habit.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await _loadHabits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _updateHabit(HabitModel habit) async {
    try {
      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/habits?id=eq.${habit.id}'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'title': habit.title,
          'frequency': habit.frequency,
          'goal': habit.goal,
          'color': habit.color,
          'note': habit.note,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadHabits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteHabit(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个习惯吗？相关记录也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('${SupabaseConfig.url}/rest/v1/habits?id=eq.$id'),
          headers: SupabaseConfig.writeHeaders,
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          await _loadHabits();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleHabit(HabitModel habit) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 检查今天是否已完成
      final isCompleted = habit.completedDates.contains(dateStr);

      final newCompletedDates = isCompleted
          ? habit.completedDates.where((d) => d != dateStr).toList()
          : [...habit.completedDates, dateStr];

      final response = await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/habits?id=eq.${habit.id}'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'completed_dates': newCompletedDates,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _loadHabits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isCompleted ? '已取消打卡' : '打卡成功')),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _showHabitForm([HabitModel? habit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HabitForm(
        userId: _userId ?? 'local_user',
        habit: habit,
        onSave: (newHabit) {
          Navigator.pop(context);
          if (habit != null) {
            _updateHabit(newHabit);
          } else {
            _addHabit(newHabit);
          }
        },
      ),
    );
  }

  bool _isHabitCompletedToday(HabitModel habit) {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return habit.completedDates.contains(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无习惯',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '添加一个新习惯开始追踪吧',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHabits,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _habits.length,
                    itemBuilder: (context, index) {
                      final habit = _habits[index];
                      final isCompletedToday = _isHabitCompletedToday(habit);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getColor(habit.color).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.check,
                              color: _getColor(habit.color),
                            ),
                          ),
                          title: Text(habit.title),
                          subtitle: Text(
                            '${habit.frequency} · 已坚持 ${habit.completedDates.length} 天',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: () => _toggleHabit(habit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isCompletedToday
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  foregroundColor: isCompletedToday
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                                child: Text(isCompletedToday ? '已打卡' : '打卡'),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _showHabitForm(habit);
                                      break;
                                    case 'delete':
                                      _deleteHabit(habit.id);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
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
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHabitForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getColor(String? colorName) {
    switch (colorName) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}

class _HabitForm extends StatefulWidget {
  final String userId;
  final HabitModel? habit;
  final Function(HabitModel) onSave;

  const _HabitForm({required this.userId, this.habit, required this.onSave});

  @override
  State<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<_HabitForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  late String _selectedFrequency;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _titleController.text = habit?.title ?? '';
    _noteController.text = habit?.note ?? '';
    _selectedFrequency = habit?.frequency ?? 'daily';
    _selectedColor = habit?.color ?? 'blue';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newHabit = HabitModel(
      id: widget.habit?.id ?? const Uuid().v4(),
      userId: widget.userId,
      title: _titleController.text,
      frequency: _selectedFrequency,
      goal: widget.habit?.goal ?? 1,
      color: _selectedColor,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      completedDates: widget.habit?.completedDates ?? [],
    );

    widget.onSave(newHabit);
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
            Text(
              '添加习惯',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '习惯名称',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入习惯名称';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text('频率', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['daily', 'weekly', 'monthly'].map((freq) => ChoiceChip(
                label: Text(_getFrequencyLabel(freq)),
                selected: _selectedFrequency == freq,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFrequency = freq);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),

            Text('颜色', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['blue', 'red', 'green', 'orange', 'purple'].map((color) => ChoiceChip(
                label: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _getColor(color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                selected: _selectedColor == color,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedColor = color);
                },
              )).toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFrequencyLabel(String freq) {
    switch (freq) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '每天';
    }
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
