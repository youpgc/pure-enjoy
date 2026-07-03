import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../services/offline_sync_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../widgets/common_widgets.dart';
import '../models/weight_record_model.dart';
import 'weight_statistics_screen.dart';

/// 体重记录页面 - Supabase 数据同步
class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> with PaginatedListMixin {
  List<WeightRecordModel> _records = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    _initLoad();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void _onLoadMore() {
    _loadRecords();
  }

  /// 初始化加载：先读缓存，再静默刷新
  Future<void> _initLoad() async {
    try {
      await _loadCache();
      await _loadRecords();
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ WeightRecordScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyWeightRecords);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _records = cached.map((e) => WeightRecordModel.fromJson(e)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecords({bool refresh = false}) async {
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

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'weight_records',
        filters: filters,
        order: 'date.desc',
        limit: limit, offset: offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final newRecords = data.map((e) => WeightRecordModel.fromJson(e)).toList();

        // date 排序优先，相同 date 时 created_at 优先
        newRecords.sort((a, b) {
          final dateCmp = b.date.compareTo(a.date);
          if (dateCmp != 0) return dateCmp;
          final aTime = a.createdAt ?? a.date;
          final bTime = b.createdAt ?? b.date;
          return bTime.compareTo(aTime);
        });

        setState(() {
          if (refresh) {
            _records = newRecords;
          } else {
            // 追加后重新全局排序
            _records.addAll(newRecords);
            _records.sort((a, b) {
              final dateCmp = b.date.compareTo(a.date);
              if (dateCmp != 0) return dateCmp;
              final aTime = a.createdAt ?? a.date;
              final bTime = b.createdAt ?? b.date;
              return bTime.compareTo(aTime);
            });
          }
          _isLoading = false;
        });
        onPaginationDataLoaded(records.length);

        // 只在刷新时写入缓存
        if (refresh) {
          await CacheHelper.instance.saveList(
            CacheHelper.keyWeightRecords,
            records.map((r) => r.toJson()).toList(),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
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

  Future<void> _createWeightRecord(WeightRecordModel record) async {
    try {
      final result = await ApiClient.post(
        'weight_records',
        record.toJson(),
      );

      if (result.isSuccess) {
        await _loadRecords(refresh: true);
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'weight_records',
          data: record.toJson(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'weight_records',
        data: record.toJson(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
        );
      }
    }
  }

  Future<void> _deleteWeightRecord(String id) async {
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这条记录吗？');

    if (confirm == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'weight_records',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          await _loadRecords(refresh: true);
          OfflineSyncService.instance.syncPending();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
          }
        } else {
          await OfflineSyncService.instance.enqueue(
            action: OfflineAction.delete,
            table: 'weight_records',
            filters: {'id': 'eq.$id'},
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
            );
          }
        }
      } catch (e) {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'weight_records',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    }
  }

  Future<void> _updateWeightRecord(WeightRecordModel record) async {
    try {
      final body = {
        'weight': record.weight,
        'bmi': record.bmi,
        'body_fat': record.bodyFat,
        'note': record.note,
        'date': record.date.toIso8601String().split('T').first,
      };
      final result = await ApiClient.patchByFilter(
        'weight_records',
        filters: {'id': 'eq.${record.id}'},
        body: body,
      );

      if (result.isSuccess) {
        await _loadRecords(refresh: true);
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'weight_records',
          data: body,
          filters: {'id': 'eq.${record.id}'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
          );
        }
      }
    } catch (e) {
      final body = {
        'weight': record.weight,
        'bmi': record.bmi,
        'body_fat': record.bodyFat,
        'note': record.note,
        'date': record.date.toIso8601String().split('T').first,
      };
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.update,
        table: 'weight_records',
        data: body,
        filters: {'id': 'eq.${record.id}'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('网络异常，已加入离线队列，恢复后自动同步')),
        );
      }
    }
  }

  void _showEditRecordForm(WeightRecordModel record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordForm(
        userId: _userId ?? 'local_user',
        record: record,
        onSave: (updatedRecord) {
          Navigator.pop(context);
          _updateWeightRecord(updatedRecord);
        },
      ),
    );
  }

  void _showRecordForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RecordForm(
        userId: _userId ?? 'local_user',
        onSave: (newRecord) {
          Navigator.pop(context);
          _createWeightRecord(newRecord);
        },
      ),
    );
  }

  double? get _latestWeight => _records.isNotEmpty ? _records.first.weight : null;
  double? get _previousWeight => _records.length > 1 ? _records[1].weight : null;
  double? get _weightChange {
    if (_latestWeight == null || _previousWeight == null) return null;
    return _latestWeight! - _previousWeight!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('体重记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '体重统计',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeightStatisticsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前体重卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前体重',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _latestWeight != null
                      ? '${_latestWeight!.toStringAsFixed(2)} kg'
                      : '-- kg',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (_weightChange != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _weightChange! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: _weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_weightChange!.abs().toStringAsFixed(2)} kg',
                        style: TextStyle(
                          color: _weightChange! > 0 ? colorScheme.error : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 记录列表
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _records.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _loadRecords(refresh: true),
                        child: CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: EmptyWidget(icon: Icons.monitor_weight_outlined, message: '暂无记录'),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadRecords(refresh: true),
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _records.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _records.length) {
                              return buildLoadMoreIndicator();
                            }

                            final record = _records[index];
                            // date 与 created_at 日期相同时展示 created_at（含时间），不同时展示 date
                            final isSameDate = record.createdAt != null &&
                                record.date.year == record.createdAt!.year &&
                                record.date.month == record.createdAt!.month &&
                                record.date.day == record.createdAt!.day;
                            final displayDate = (isSameDate && record.createdAt != null)
                                ? record.createdAt!
                                : record.date;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.monitor_weight),
                                title: Row(
                                  children: [
                                    Text(
                                      '${record.weight.toStringAsFixed(2)} kg',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (record.bodyFat != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        '体脂 ${record.bodyFat!.toStringAsFixed(1)}%',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (record.bmi != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        'BMI ${record.bmi!.toStringAsFixed(1)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateTimeUtils.formatStandard(displayDate)),
                                    if (record.note != null && record.note!.isNotEmpty)
                                      Text(
                                        record.note!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: EditDeletePopupMenu(
                                  onEdit: () => _showEditRecordForm(record),
                                  onDelete: () => _deleteWeightRecord(record.id),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordForm extends StatefulWidget {
  final String userId;
  final WeightRecordModel? record;
  final Function(WeightRecordModel) onSave;

  const _RecordForm({required this.userId, this.record, required this.onSave});

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _bmiController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _weightController = TextEditingController(
      text: record != null ? record.weight.toString() : '',
    );
    _bodyFatController = TextEditingController(
      text: record?.bodyFat?.toString() ?? '',
    );
    _bmiController = TextEditingController(
      text: record?.bmi?.toString() ?? '',
    );
    _noteController = TextEditingController(
      text: record?.note ?? '',
    );
    _selectedDate = record?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _bmiController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final newRecord = WeightRecordModel(
        id: _isEditing ? widget.record!.id : const Uuid().v4(),
        userId: _isEditing ? widget.record!.userId : widget.userId,
        weight: double.parse(_weightController.text),
        bmi: _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
        bodyFat: _bodyFatController.text.isNotEmpty
            ? double.tryParse(_bodyFatController.text)
            : null,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        date: _selectedDate,
      );

      widget.onSave(newRecord);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
              '添加记录',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            const SizedBox(height: 16),

            TextFormField(
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '体脂率（可选）',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bmiController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'BMI（可选）',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '添加备注信息',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

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
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
