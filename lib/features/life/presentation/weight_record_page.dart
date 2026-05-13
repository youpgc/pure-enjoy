import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../data/weight_record_model.dart';

/// 体重记录页面
class WeightRecordPage extends ConsumerStatefulWidget {
  const WeightRecordPage({super.key});

  @override
  ConsumerState<WeightRecordPage> createState() => _WeightRecordPageState();
}

class _WeightRecordPageState extends ConsumerState<WeightRecordPage> {
  List<WeightRecordModel> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    final box = StorageService().weightBox;
    setState(() {
      _records = box.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  double? get _latestWeight => _records.isNotEmpty ? _records.first.weight : null;
  double? get _firstWeight => _records.isNotEmpty ? _records.last.weight : null;
  double? get _weightChange {
    if (_latestWeight != null && _firstWeight != null) {
      return _latestWeight! - _firstWeight!;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体重记录'),
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          Expanded(
            child: _records.isEmpty
                ? _buildEmptyState()
                : _buildRecordList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentColor, Color(0xFF45B7AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('当前体重', _latestWeight?.toStringAsFixed(1) ?? '--', 'kg'),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildStatItem(
                '体重变化',
                _weightChange != null
                    ? '${_weightChange! > 0 ? '+' : ''}${_weightChange!.toStringAsFixed(1)}'
                    : '--',
                'kg',
                color: _weightChange == null
                    ? Colors.white
                    : _weightChange! > 0
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF00B894),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '共 ${_records.length} 条记录',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_weight_outlined,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有体重记录',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '记录体重变化，关注健康',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        final prevRecord = index < _records.length - 1 ? _records[index + 1] : null;
        final change = prevRecord != null
            ? record.weight - prevRecord.weight
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.monitor_weight,
                color: AppTheme.accentColor,
              ),
            ),
            title: Text(
              '${record.weight.toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              DateFormat('yyyy-MM-dd').format(record.date),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            trailing: change != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: change > 0
                          ? const Color(0xFFFF6B6B).withOpacity(0.1)
                          : const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: change > 0
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF00B894),
                      ),
                    ),
                  )
                : null,
            onLongPress: () => _deleteRecord(record),
          ),
        );
      },
    );
  }

  void _showAddDialog() {
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录体重'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '体重',
                suffixText: 'kg',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final weight = double.tryParse(weightController.text);
              if (weight != null && weight > 0) {
                final record = WeightRecordModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  weight: weight,
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                await StorageService().weightBox.put(record.id, record);
                SyncService().uploadWeightRecord(record); // 同步到云端
                Navigator.pop(context);
                _loadRecords();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteRecord(WeightRecordModel record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条体重记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await StorageService().weightBox.delete(record.id);
              SyncService().deleteRemote('weight_records', record.id); // 从云端删除
              Navigator.pop(context);
              _loadRecords();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
