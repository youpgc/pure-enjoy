import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/supabase_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/anniversary_model.dart';

/// 纪念日/生日列表页面 - Supabase 数据同步
class AnniversariesScreen extends StatefulWidget {
  /// 类型过滤：'anniversary' 或 'birthday'
  final String filterType;

  const AnniversariesScreen({super.key, this.filterType = 'anniversary'});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> {
  List<AnniversaryModel> _anniversaries = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;
  String? get _userNickname => AuthService.instance.currentUserName;

  String get _cacheKey => 'cached_anniversaries_${widget.filterType}';

  @override
  void initState() {
    super.initState();
    _loadAnniversaries();
  }

  Future<void> _loadAnniversaries() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _anniversaries = [];
        _isLoading = false;
      });
      return;
    }

    // 1. 先加载本地缓存
    final cachedData = await _loadCachedList();
    if (cachedData.isNotEmpty && mounted) {
      setState(() {
        _anniversaries =
            cachedData.map((e) => AnniversaryModel.fromJson(e)).toList();
        _sortAnniversaries();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = true);
    }

    // 2. 静默从网络刷新
    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/user_anniversaries?user_id=eq.$userId&type=eq.${widget.filterType}&select=*&order=date.asc&limit=500',
        ),
        headers: AuthService.instance.authHeaders,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List data = jsonDecode(response.body);
      final items = data.map((e) => AnniversaryModel.fromJson(e)).toList();

      // 保存缓存（只保存当前用户、当前类型的数据）
      await _saveCachedList(data);

      if (mounted) {
        setState(() {
          _anniversaries = items;
          _sortAnniversaries();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_anniversaries.isEmpty) {
          _showError('加载纪念日失败: $e');
        }
      }
    }
  }

  /// 按距离下一个纪念日的天数排序（最近的排在前面）
  void _sortAnniversaries() {
    _anniversaries.sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));
  }

  /// 加载缓存列表
  Future<List<dynamic>> _loadCachedList() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded;
      return [];
    } catch (e) {
      debugPrint('错误: $e');
      return [];
    }
  }

  /// 保存缓存列表
  Future<void> _saveCachedList(List<dynamic> data) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      debugPrint('错误: $e');
    }
  }

  /// 获取 SharedPreferences
  Future<SharedPreferences> _getPrefs() => SharedPreferences.getInstance();

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _deleteAnniversary(String id) async {
    final userId = _userId;
    if (userId == null) {
      _showError('请先登录后再删除');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '确定要删除这个纪念日吗？',
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse(
            '${SupabaseConfig.url}/rest/v1/user_anniversaries?id=eq.$id',
          ),
          headers: {
            ...SupabaseConfig.writeHeaders,
            'x-user-id': userId,
          },
        );

        if (response.statusCode == 204 || response.statusCode == 200) {
          _loadAnniversaries();
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  Future<void> _showEditDialog({AnniversaryModel? anniversary}) async {
    final isEditing = anniversary != null;
    final nameController = TextEditingController(text: anniversary?.title ?? '');
    final descController =
        TextEditingController(text: anniversary?.description ?? '');

    String selectedType = anniversary?.type ?? widget.filterType;
    DateTime selectedDate = anniversary?.date ?? DateTime.now();
    bool repeatYearly = anniversary?.repeatYearly ?? true;
    bool remindEnabled = anniversary?.remindEnabled ?? false;
    int? remindDaysBefore = anniversary?.remindDaysBefore ?? 0;

    final isBirthday = widget.filterType == 'birthday';
    final typeLabel = isBirthday ? '生日' : '纪念日';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑$typeLabel' : '添加$typeLabel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称输入
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '名称 *',
                    hintText: isBirthday ? '例如：妈妈生日、爸爸生日' : '例如：结婚纪念日、入职纪念日',
                  ),
                ),
                const SizedBox(height: 12),

                // 日期选择
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('日期 *'),
                  subtitle: Text(
                    DateTimeUtils.formatDate(selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const Divider(),
                const SizedBox(height: 4),

                // 描述输入
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '输入描述（可选）',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 是否每年重复
                SwitchListTile(
                  title: const Text('每年重复'),
                  subtitle: Text(repeatYearly ? '每年都会提醒' : '仅一次'),
                  contentPadding: EdgeInsets.zero,
                  value: repeatYearly,
                  onChanged: (value) {
                    setDialogState(() => repeatYearly = value);
                  },
                ),
                const Divider(),

                // 是否开启提醒
                SwitchListTile(
                  title: const Text('开启提醒'),
                  subtitle: Text(remindEnabled ? '已开启' : '关闭'),
                  contentPadding: EdgeInsets.zero,
                  value: remindEnabled,
                  onChanged: (value) {
                    setDialogState(() => remindEnabled = value);
                  },
                ),

                // 提前提醒天数
                if (remindEnabled) ...[
                  const SizedBox(height: 8),
                  const Text('提前提醒', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: remindDaysBefore,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('当天')),
                      DropdownMenuItem(value: 1, child: Text('提前1天')),
                      DropdownMenuItem(value: 3, child: Text('提前3天')),
                      DropdownMenuItem(value: 7, child: Text('提前7天')),
                      DropdownMenuItem(value: 14, child: Text('提前14天')),
                      DropdownMenuItem(value: 30, child: Text('提前30天')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => remindDaysBefore = value);
                    },
                  ),
                ],
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
                  _showError('请输入名称');
                  return;
                }

                final userId = _userId;
                if (userId == null) {
                  _showError('请先登录后再保存');
                  return;
                }
                final nickname = _userNickname;

                try {
                  if (isEditing) {
                    final response = await http.patch(
                      Uri.parse(
                        '${SupabaseConfig.url}/rest/v1/user_anniversaries?id=eq.${anniversary.id}',
                      ),
                      headers: {
                        ...SupabaseConfig.writeHeaders,
                        'x-user-id': userId,
                      },
                      body: jsonEncode({
                        'user_nickname': nickname,
                        'title': nameController.text.trim(),
                        'date': DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12).toIso8601String(),
                        'type': selectedType,
                        'description':
                            descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                        'repeat_yearly': repeatYearly,
                        'remind_enabled': remindEnabled,
                        'remind_days_before':
                            remindEnabled ? remindDaysBefore : null,
                      }),
                    );
                    if (response.statusCode != 200 &&
                        response.statusCode != 204) {
                      throw Exception('HTTP ${response.statusCode}');
                    }
                  } else {
                    final anniversaryId = const Uuid().v4();
                    final response = await http.post(
                      Uri.parse(
                        '${SupabaseConfig.url}/rest/v1/user_anniversaries',
                      ),
                      headers: {
                        ...SupabaseConfig.writeHeaders,
                        'x-user-id': userId,
                      },
                      body: jsonEncode({
                        'id': anniversaryId,
                        'user_id': userId,
                        'user_nickname': nickname,
                        'title': nameController.text.trim(),
                        'date': DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 12).toIso8601String(),
                        'type': selectedType,
                        'description':
                            descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                        'repeat_yearly': repeatYearly,
                        'remind_enabled': remindEnabled,
                        'remind_days_before':
                            remindEnabled ? remindDaysBefore : null,
                      }),
                    );
                    if (response.statusCode != 201 &&
                        response.statusCode != 200) {
                      throw Exception('HTTP ${response.statusCode}');
                    }
                  }
                  Navigator.pop(context);
                  _loadAnniversaries();
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

  /// 格式化日期显示
  String _formatDate(DateTime date) {
    return DateTimeUtils.formatStandard(date);
  }

  /// 获取距离天数的描述文本
  String _getDaysText(AnniversaryModel item) {
    final days = item.daysUntilNext;
    if (days == 0) {
      return '就是今天！';
    } else if (days == 1) {
      return '明天';
    } else if (days < 0) {
      return '已过${-days}天';
    } else {
      return '还有${days}天';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBirthday = widget.filterType == 'birthday';
    final title = isBirthday ? '生日' : '纪念日';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _anniversaries.isEmpty
              ? EmptyWidget(
                  icon: isBirthday ? Icons.cake_outlined : Icons.celebration_outlined,
                  message: '还没有$title',
                )
              : RefreshIndicator(
                  onRefresh: _loadAnniversaries,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _anniversaries.length,
                    itemBuilder: (context, index) {
                      final item = _anniversaries[index];
                      return _AnniversaryCard(
                        item: item,
                        daysText: _getDaysText(item),
                        formatDate: _formatDate(item.date),
                        onEdit: () => _showEditDialog(anniversary: item),
                        onDelete: () => _deleteAnniversary(item.id),
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

/// 纪念日卡片组件
class _AnniversaryCard extends StatelessWidget {
  final AnniversaryModel item;
  final String daysText;
  final String formatDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnniversaryCard({
    required this.item,
    required this.daysText,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBirthday = item.type == 'birthday';
    final isToday = item.daysUntilNext == 0;

    // 根据类型选择颜色
    final cardColor = isBirthday
        ? colorScheme.primaryContainer.withOpacity(0.5)
        : colorScheme.tertiaryContainer.withOpacity(0.5);

    final iconColor = isBirthday
        ? colorScheme.primary
        : colorScheme.tertiary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isToday ? colorScheme.primaryContainer : null,
      elevation: isToday ? 4 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBirthday ? Icons.cake : Icons.celebration,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),

                // 标题和类型标签
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 类型标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isBirthday ? '生日' : '纪念日',
                              style: TextStyle(
                                fontSize: 11,
                                color: iconColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 提醒图标
                          if (item.remindEnabled)
                            Icon(
                              Icons.notifications_active,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 日期
                      Text(
                        formatDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // 更多操作
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
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
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 底部信息行：距离天数 / 年龄 / 重复信息
            Row(
              children: [
                // 距离天数
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 年龄（仅生日显示）
                if (item.age != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.age}岁',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),

                const Spacer(),

                // 重复信息
                if (item.repeatYearly)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '每年',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '仅一次',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outline,
                    ),
                  ),
              ],
            ),

            // 描述（如有）
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
