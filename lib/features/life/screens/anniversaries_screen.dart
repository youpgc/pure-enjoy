import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../utils/date_time_utils.dart';
import '../models/anniversary_model.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/anniversary_card.dart';
import 'anniversary_helpers.dart';
import 'anniversary_lunar_picker.dart';

/// 纪念日/生日列表页面 - Supabase 数据同步
class AnniversariesScreen extends StatefulWidget {
  /// 类型过滤：'anniversary' 或 'birthday'
  final String filterType;

  const AnniversariesScreen({super.key, this.filterType = 'anniversary'});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> with PaginatedListMixin {
  List<AnniversaryModel> _anniversaries = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;
  String? get _userNickname => AuthService.instance.currentUserName;

  String get _cacheKey => 'cached_anniversaries_${widget.filterType}';

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadAnniversaries(refresh: true);
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadAnniversaries();
  }

  Future<void> _loadAnniversaries({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _anniversaries = [];
        _isLoading = false;
      });
      return;
    }

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    // 1. 先加载本地缓存（仅 refresh 时）
    if (refresh) {
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
    }

    // 2. 静默从网络刷新
    try {
      final (limit, offset) = paginationParams;
      final result = await ApiClient.get(
        'user_anniversaries',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.${widget.filterType}',
        },
        order: 'date.asc',
        limit: limit,
        offset: offset,
      );

      if (!result.isSuccess) {
        throw Exception('HTTP ${result.statusCode}');
      }

      final data = result.data!;
      final items = data.map((e) => AnniversaryModel.fromJson(e)).toList();

      // 保存缓存（只保存当前用户、当前类型的数据，仅 refresh 时）
      if (refresh) {
        await _saveCachedList(data);
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _anniversaries = items;
          } else {
            _anniversaries.addAll(items);
          }
          _sortAnniversaries();
          _isLoading = false;
          onPaginationDataLoaded(items.length);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_anniversaries.isEmpty) {
          _showError('加载纪念日失败，请稍后重试');
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
      if (kDebugMode) {
        debugPrint('错误');
      }
      return [];
    }
  }

  /// 保存缓存列表
  Future<void> _saveCachedList(List<dynamic> data) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('错误');
      }
    }
  }

  /// 获取 SharedPreferences
  Future<SharedPreferences> _getPrefs() => SharedPreferences.getInstance();

  void _showError(String message) {
    showSnackBar(context, message, isError: true);
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
        final result = await ApiClient.batchDeleteByFilter(
          'user_anniversaries',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          _loadAnniversaries(refresh: true);
          if (mounted) {
            showSnackBar(context, '删除成功');
          }
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        _showError('删除失败，请稍后重试');
      }
    }
  }

  Future<void> _showEditDialog({AnniversaryModel? anniversary}) async {
    final isEditing = anniversary != null;
    final nameController = TextEditingController(text: anniversary?.title ?? '');
    final descController =
        TextEditingController(text: anniversary?.description ?? '');

    final String selectedType = anniversary?.type ?? widget.filterType;
    DateTime selectedDate = anniversary?.date ?? DateTime.now();
    bool repeatYearly = anniversary?.repeatYearly ?? true;
    bool remindEnabled = anniversary?.remindEnabled ?? false;
    int? remindDaysBefore = anniversary?.remindDaysBefore ?? 0;
    bool isLunar = anniversary?.isLunar ?? false;

    final isBirthday = widget.filterType == 'birthday';
    final typeLabel = isBirthday ? '生日' : '纪念日';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                    isLunar
                        ? '农历 ${getLunarDateStr(selectedDate)}'
                        : DateTimeUtils.formatDate(selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    if (isLunar) {
                      // 农历日期选择器
                      final picked = await showLunarDatePicker(
                        dialogContext,
                        initialDate: selectedDate,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    } else {
                      final picked = await AppDatePicker.show(
                        dialogContext,
                        type: DateTimeType.date,
                        initialDate: selectedDate,
                        minDate: DateTime(1900),
                        maxDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    }
                  },
                ),
                const SizedBox(height: 4),
                // 农历/公历切换
                SwitchListTile(
                  title: const Text('农历'),
                  subtitle: Text(isLunar ? '当前为农历日期' : '当前为公历日期'),
                  contentPadding: EdgeInsets.zero,
                  value: isLunar,
                  onChanged: (value) {
                    setDialogState(() => isLunar = value);
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
                    initialValue: remindDaysBefore,
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
              onPressed: () => Navigator.pop(dialogContext),
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
                    final result = await ApiClient.patchByFilter(
                      'user_anniversaries',
                      filters: {'id': 'eq.${anniversary.id}'},
                      body: {
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
                        'is_lunar': isLunar,
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}');
                    }
                  } else {
                    final anniversaryId = const Uuid().v4();
                    final result = await ApiClient.post(
                      'user_anniversaries',
                      {
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
                        'is_lunar': isLunar,
                      },
                    );
                    if (!result.isSuccess) {
                      throw Exception('HTTP ${result.statusCode}');
                    }
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadAnniversaries(refresh: true);
                } catch (e) {
                  _showError('保存失败，请稍后重试');
                }
              },
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isBirthday = widget.filterType == 'birthday';
    final title = isBirthday ? '生日' : '纪念日';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _anniversaries.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadAnniversaries(refresh: true),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyWidget(
                          icon: isBirthday ? Icons.cake_outlined : Icons.celebration_outlined,
                          message: '还没有$title',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAnniversaries(refresh: true),
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _anniversaries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _anniversaries.length) {
                        return buildLoadMoreIndicator();
                      }
                      final item = _anniversaries[index];
                      return AnniversaryCard(
                        item: item,
                        daysText: getAnniversaryDaysText(item),
                        formatDate: formatAnniversaryDate(item),
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

