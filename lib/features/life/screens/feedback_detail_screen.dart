import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class FeedbackDetailScreen extends StatefulWidget {
  final String feedbackId;

  const FeedbackDetailScreen({
    super.key,
    required this.feedbackId,
  });

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  Map<String, dynamic>? _feedback;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.getOne(
        'feedbacks',
        filters: {'id': 'eq.${widget.feedbackId}'},
      );

      if (result.isSuccess) {
        setState(() {
          _feedback = result.data;
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
        title: const Text('反馈详情'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedback == null
              ? const Center(child: Text('反馈不存在'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _feedback!['title'] ?? '无标题',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(_feedback!['status']),
                      const SizedBox(height: 16),
                      Text(
                        '提交时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(_feedback!['created_at']))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        _feedback!['content'] ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_feedback!['reply'] != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          '回复:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _feedback!['reply'],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
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
