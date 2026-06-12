import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'reading_history',
        filters: {'user_id': 'eq.$_userId'},
        order: 'created_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _history = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final result = await ApiClient.delete(
        'reading_history',
        filters: {'user_id': 'eq.$userId'},
      );

      if (result.isSuccess) {
        _loadHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清空阅读历史')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读历史'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清空'),
                    content: const Text('确定要清空所有阅读历史吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('暂无阅读历史'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final createdAt = DateTime.parse(item['created_at']);
                    return ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(item['novel_title'] ?? '未知小说'),
                      subtitle: Text('第 ${item['chapter_num'] ?? 0} 章'),
                      trailing: Text(
                        DateFormat('MM-dd HH:mm').format(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
    );
  }
}
