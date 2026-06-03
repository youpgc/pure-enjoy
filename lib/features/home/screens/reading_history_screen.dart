import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/supabase_service.dart';
import '../../../config.dart';
import '../../novel/screens/novel_reader_screen.dart';

/// 阅读历史页面
class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final resp = await http.get(
        Uri.parse(
          '$SUPABASE_URL/rest/v1/user_novels?user_id=eq.$userId&select=novel_id,last_read_chapter,last_read_at,novels:novel_id(title,cover_url,author)&order=last_read_at.desc&limit=50',
        ),
        headers: {
          'apikey': SUPABASE_KEY,
          'Authorization': 'Bearer $SUPABASE_KEY',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        setState(() {
          _history = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('加载阅读历史失败: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有阅读历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userId = _userId;
        if (userId == null) return;

        final resp = await http.delete(
          Uri.parse('$SUPABASE_URL/rest/v1/user_novels?user_id=eq.$userId'),
          headers: {
            'apikey': SUPABASE_KEY,
            'Authorization': 'Bearer $SUPABASE_KEY',
          },
        );

        if (resp.statusCode == 200 || resp.statusCode == 204) {
          setState(() => _history = []);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('阅读历史已清空')),
            );
          }
        }
      } catch (e) {
        print('清空阅读历史失败: $e');
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
              onPressed: _clearHistory,
              tooltip: '清空历史',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyView()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无阅读历史',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始阅读小说，记录将显示在这里',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final novel = item['novels'] as Map<String, dynamic>? ?? {};
        final title = novel['title'] ?? '未知小说';
        final coverUrl = novel['cover_url'];
        final author = novel['author'] ?? '';
        final lastChapter = item['last_read_chapter'] ?? 0;
        final lastReadAt = item['last_read_at'];

        return ListTile(
          leading: coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    coverUrl,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 70,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, color: Colors.grey),
                    ),
                  ),
                )
              : Container(
                  width: 50,
                  height: 70,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, color: Colors.grey),
                ),
          title: Text(title),
          subtitle: Text(
            '$author · 读到第$lastChapter章',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // 跳转到阅读页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NovelReaderScreen(
                  novelId: item['novel_id'],
                  novelTitle: title,
                  initialChapterNum: lastChapter,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
