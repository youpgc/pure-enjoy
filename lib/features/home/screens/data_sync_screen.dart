import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  bool _isSyncing = false;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    // TODO: 从本地存储加载上次同步时间
  }

  Future<void> _syncData() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      // TODO: 实现数据同步逻辑
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同步完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_lastSyncTime != null)
              Text('上次同步: $_lastSyncTime')
            else
              const Text('尚未同步'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSyncing ? null : _syncData,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? '同步中...' : '立即同步'),
            ),
          ],
        ),
      ),
    );
  }
}
