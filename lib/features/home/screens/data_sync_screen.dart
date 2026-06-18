import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// 单个表的同步结果
enum TableSyncStatus { pending, syncing, success, failed }

class TableSyncResult {
  final String tableName;
  final String displayName;
  final TableSyncStatus status;
  final int recordCount;
  final String? errorMessage;

  const TableSyncResult({
    required this.tableName,
    required this.displayName,
    this.status = TableSyncStatus.pending,
    this.recordCount = 0,
    this.errorMessage,
  });

  TableSyncResult copyWith({
    TableSyncStatus? status,
    int? recordCount,
    String? errorMessage,
  }) {
    return TableSyncResult(
      tableName: tableName,
      displayName: displayName,
      status: status ?? this.status,
      recordCount: recordCount ?? this.recordCount,
      errorMessage: errorMessage,
    );
  }
}

/// 数据同步页面
class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  bool _isSyncing = false;
  String _syncStatus = '';
  double _syncProgress = 0;
  String _lastSyncTime = '';

  /// 需要同步的表配置
  final List<TableSyncResult> _syncResults = const [
    TableSyncResult(tableName: 'expenses', displayName: '消费记录'),
    TableSyncResult(tableName: 'mood_diaries', displayName: '心情日记'),
    TableSyncResult(tableName: 'weight_records', displayName: '体重记录'),
    TableSyncResult(tableName: 'notes', displayName: '笔记'),
    TableSyncResult(tableName: 'user_favorites', displayName: '收藏'),
    TableSyncResult(tableName: 'reminders', displayName: '提醒事项'),
    TableSyncResult(tableName: 'habits', displayName: '习惯打卡'),
  ];

  String? get _userId => AuthService.instance.currentUserId;

  // ApiClient handles headers internally

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  /// 从 SharedPreferences 加载上次同步时间
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync_time');
    if (lastSync != null && mounted) {
      setState(() {
        _lastSyncTime = lastSync;
      });
    }
  }

  /// 保存同步时间到 SharedPreferences
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final timeStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await prefs.setString('last_sync_time', timeStr);
    if (mounted) {
      setState(() {
        _lastSyncTime = timeStr;
      });
    }
  }

  /// 同步单个表的数据
  /// 从 Supabase 下载用户数据并缓存到本地 SharedPreferences
  Future<TableSyncResult> _syncTable(
    TableSyncResult current,
    String userId,
  ) async {
    try {
      final result = await ApiClient.get(
        current.tableName,
        filters: {'user_id': 'eq.$userId'},
        order: 'created_at.desc',
        limit: 200,
      );

      if (result.isSuccess) {
        final data = result.data!;

        // 将数据缓存到 SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'sync_cache_${current.tableName}',
          jsonEncode(data),
        );

        return current.copyWith(
          status: TableSyncStatus.success,
          recordCount: data.length,
        );
      } else if (result.statusCode == 404) {
        // 表不存在，跳过
        debugPrint('同步跳过: ${current.tableName} (表不存在, HTTP 404)');
        return current.copyWith(
          status: TableSyncStatus.success,
          recordCount: 0,
          errorMessage: '表不存在，已跳过',
        );
      } else {
        final errorMsg =
            'HTTP ${result.statusCode}: ${result.errorMessage}';
        debugPrint('同步失败: ${current.tableName} - $errorMsg');
        return current.copyWith(
          status: TableSyncStatus.failed,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      debugPrint('同步异常: ${current.tableName} - $e');
      return current.copyWith(
        status: TableSyncStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 执行全部数据同步
  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = '正在同步数据...';
      _syncProgress = 0;
      // 重置所有表状态为 pending
      for (int i = 0; i < _syncResults.length; i++) {
        _syncResults[i] = _syncResults[i].copyWith(
          status: TableSyncStatus.pending,
          recordCount: 0,
          errorMessage: null,
        );
      }
    });

    final userId = _userId;
    if (userId == null) {
      setState(() {
        _syncStatus = '请先登录';
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后再同步数据')),
        );
      }
      return;
    }

    int successCount = 0;
    int failCount = 0;
    final totalTables = _syncResults.length;

    // 并行同步所有表
    final syncFutures = <Future<void>>[];
    for (int i = 0; i < totalTables; i++) {
      final table = _syncResults[i];

      setState(() {
        _syncResults[i] = table.copyWith(status: TableSyncStatus.syncing);
      });

      syncFutures.add(() async {
        final result = await _syncTable(table, userId);

        if (mounted) {
          setState(() {
            _syncResults[i] = result;
          });
        }
      }());
    }

    await Future.wait(syncFutures);

    for (int i = 0; i < totalTables; i++) {
      if (_syncResults[i].status == TableSyncStatus.success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    setState(() {
      _syncProgress = 1.0;
    });

    // 保存同步时间
    await _saveLastSyncTime();

    final totalRecords = _syncResults.fold<int>(
      0,
      (sum, r) => sum + r.recordCount,
    );

    setState(() {
      _isSyncing = false;
      if (failCount == 0) {
        _syncStatus = '同步完成！共同步 $totalRecords 条记录';
      } else {
        _syncStatus =
            '同步完成：$successCount 成功，$failCount 失败，共 $totalRecords 条记录';
      }
      _syncProgress = 1.0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? '数据同步成功，共 $totalRecords 条记录'
                : '同步完成：$successCount 成功，$failCount 失败',
          ),
          backgroundColor: failCount == 0 ? AppTheme.success : Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '数据同步',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '将您的消费记录、心情日记、体重记录、笔记、收藏、提醒事项和习惯打卡同步到本地，确保数据安全。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 上次同步时间
                    if (_lastSyncTime.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '上次同步: $_lastSyncTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isSyncing) ...[
                      LinearProgressIndicator(value: _syncProgress),
                      const SizedBox(height: 8),
                      Text(_syncStatus),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _syncData,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('立即同步'),
                        ),
                      ),
                      if (_syncStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _syncStatus,
                          style: TextStyle(
                            color: _syncStatus.contains('失败')
                                ? Theme.of(context).colorScheme.error
                                : AppTheme.success,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '同步内容',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _syncResults.length,
                itemBuilder: (context, index) {
                  return _buildSyncItem(_syncResults[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 同步项描述映射
  static const Map<String, String> _descriptions = {
    'expenses': '记录您的每一笔开销',
    'mood_diaries': '记录每日心情变化',
    'weight_records': '追踪体重变化趋势',
    'notes': '同步您的所有笔记',
    'user_favorites': '同步您的收藏内容',
    'reminders': '同步您的提醒事项',
    'habits': '同步您的习惯打卡记录',
  };

  /// 同步项图标映射
  static const Map<String, IconData> _icons = {
    'expenses': Icons.receipt_long,
    'mood_diaries': Icons.mood,
    'weight_records': Icons.monitor_weight,
    'notes': Icons.note,
    'user_favorites': Icons.bookmark,
    'reminders': Icons.notifications,
    'habits': Icons.checklist,
  };

  Widget _buildSyncItem(TableSyncResult result) {
    final icon = _icons[result.tableName] ?? Icons.data_usage;
    final description = _descriptions[result.tableName] ?? '';

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (result.status) {
      case TableSyncStatus.pending:
        statusIcon = Icons.circle_outlined;
        statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
        statusText = '等待同步';
        break;
      case TableSyncStatus.syncing:
        statusIcon = Icons.sync;
        statusColor = Theme.of(context).colorScheme.primary;
        statusText = '同步中...';
        break;
      case TableSyncStatus.success:
        statusIcon = Icons.check_circle;
        statusColor = AppTheme.success;
        statusText = '${result.recordCount} 条记录';
        break;
      case TableSyncStatus.failed:
        statusIcon = Icons.error;
        statusColor = Theme.of(context).colorScheme.error;
        statusText = '同步失败';
        break;
    }

    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(result.displayName),
      subtitle: Text(
        result.status == TableSyncStatus.failed && result.errorMessage != null
            ? '$description\n${result.errorMessage}'
            : description,
        style: TextStyle(
          fontSize: 12,
          color: result.status == TableSyncStatus.failed
              ? AppTheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          if (result.status == TableSyncStatus.syncing)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          else
            Icon(statusIcon, color: statusColor, size: 20),
        ],
      ),
    );
  }
}
