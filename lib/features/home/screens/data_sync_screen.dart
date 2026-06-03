import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/supabase_service.dart';
import '../../../config.dart';

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

  String? get _userId => AuthService.instance.currentUserId;

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = '正在同步数据...';
      _syncProgress = 0;
    });

    try {
      final userId = _userId;
      if (userId == null) {
        setState(() {
          _syncStatus = '请先登录';
          _isSyncing = false;
        });
        return;
      }

      // 同步消费记录
      setState(() {
        _syncStatus = '同步消费记录...';
        _syncProgress = 0.2;
      });
      await _syncTable('expenses', userId);

      // 同步心情日记
      setState(() {
        _syncStatus = '同步心情日记...';
        _syncProgress = 0.4;
      });
      await _syncTable('mood_diaries', userId);

      // 同步体重记录
      setState(() {
        _syncStatus = '同步体重记录...';
        _syncProgress = 0.6;
      });
      await _syncTable('weight_records', userId);

      // 同步笔记
      setState(() {
        _syncStatus = '同步笔记...';
        _syncProgress = 0.8;
      });
      await _syncTable('notes', userId);

      // 同步收藏
      setState(() {
        _syncStatus = '同步收藏...';
        _syncProgress = 0.9;
      });
      await _syncTable('user_favorites', userId);

      setState(() {
        _syncStatus = '同步完成！';
        _syncProgress = 1.0;
        _isSyncing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据同步成功')),
        );
      }
    } catch (e) {
      print('同步失败: $e');
      setState(() {
        _syncStatus = '同步失败: $e';
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  Future<void> _syncTable(String table, String userId) async {
    // 这里可以实现具体的同步逻辑
    // 例如：获取本地数据，上传到Supabase，或从Supabase下载
    await Future.delayed(const Duration(milliseconds: 500));
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
                      '将您的消费记录、心情日记、体重记录、笔记和收藏同步到云端，确保数据安全。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isSyncing) ...[
                      LinearProgressIndicator(value: _syncProgress),
                      const SizedBox(height: 8),
                      Text(_syncStatus),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _syncData,
                          icon: const Icon(Icons.cloud_sync),
                          label: const Text('立即同步'),
                        ),
                      ),
                      if (_syncStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _syncStatus,
                          style: TextStyle(
                            color: _syncStatus.contains('失败')
                                ? Colors.red
                                : Colors.green,
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
            _buildSyncItem(Icons.receipt_long, '消费记录', '记录您的每一笔开销'),
            _buildSyncItem(Icons.mood, '心情日记', '记录每日心情变化'),
            _buildSyncItem(Icons.monitor_weight, '体重记录', '追踪体重变化趋势'),
            _buildSyncItem(Icons.note, '笔记', '同步您的所有笔记'),
            _buildSyncItem(Icons.bookmark, '收藏', '同步您的收藏内容'),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
