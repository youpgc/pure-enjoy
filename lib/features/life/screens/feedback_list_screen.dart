import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import 'feedback_detail_screen.dart';

class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key});

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'feedbacks',
        filters: {'user_id': 'eq.$_userId'},
        order: 'created_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _feedbacks = result.data!;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的反馈'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedbacks.isEmpty
              ? const Center(child: Text('暂无反馈'))
              : ListView.builder(
                  itemCount: _feedbacks.length,
                  itemBuilder: (context, index) {
                    final feedback = _feedbacks[index];
                    final createdAt = DateTime.parse(feedback['created_at']);
                    return ListTile(
                      title: Text(feedback['title'] ?? '无标题'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                      ),
                      trailing: _buildStatusChip(feedback['status']),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedbackDetailScreen(
                              feedbackId: feedback['id'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'resolved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };

    final label = switch (status) {
      'pending' => '待处理',
      'resolved' => '已解决',
      'rejected' => '已拒绝',
      _ => '未知',
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color),
    );
  }
}
