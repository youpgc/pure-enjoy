import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/feedback_model.dart';
import 'feedback_submit_screen.dart';
import 'feedback_detail_screen.dart';

/// 问题反馈列表页面
class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key});

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> {
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  /// 加载反馈列表
  Future<void> _loadFeedbacks() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _feedbacks = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/user_feedback?user_id=eq.$userId&select=*&order=created_at.desc&limit=200',
        ),
        headers: {
          ...SupabaseConfig.headers,
          'x-user-id': userId,
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final feedbacks =
            data.map((e) => FeedbackModel.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _feedbacks = feedbacks;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_feedbacks.isEmpty) {
          showSnackBar(context, '加载失败: $e', isError: true);
        }
      }
    }
  }

  /// 获取分类标签信息
  _CategoryInfo _getCategoryInfo(String category) {
    switch (category) {
      case 'bug':
        return _CategoryInfo(label: 'Bug', color: Theme.of(context).colorScheme.error);
      case 'feature':
        return _CategoryInfo(label: '功能建议', color: Theme.of(context).colorScheme.primary);
      case 'improvement':
        return _CategoryInfo(label: '体验优化', color: Theme.of(context).colorScheme.primary);
      case 'other':
        return _CategoryInfo(label: '其他', color: Theme.of(context).colorScheme.onSurfaceVariant);
      default:
        return _CategoryInfo(label: category, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }

  /// 获取状态标签信息
  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusInfo(label: '待确认', color: Theme.of(context).colorScheme.onSurfaceVariant);
      case 'confirmed':
        return _StatusInfo(label: '已确认', color: Theme.of(context).colorScheme.primary);
      case 'in_progress':
        return _StatusInfo(label: '进行中', color: Theme.of(context).colorScheme.secondary);
      case 'resolved':
        return _StatusInfo(label: '已完结', color: AppTheme.success);
      default:
        return _StatusInfo(label: status, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }

  /// 格式化时间
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime).inDays;
    if (diff == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff == 1) {
      return '昨天';
    } else if (diff < 7) {
      return '$diff天前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('问题反馈'),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _feedbacks.isEmpty
              ? const EmptyWidget(
                  icon: Icons.feedback_outlined,
                  message: '暂无反馈记录',
                )
              : ListView.builder(
                  itemCount: _feedbacks.length,
                  itemBuilder: (context, index) {
                    final feedback = _feedbacks[index];
                    final categoryInfo = _getCategoryInfo(feedback.category);
                    final statusInfo = _getStatusInfo(feedback.status);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(feedback.title),
                        subtitle: Row(
                          children: [
                            // 分类标签
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryInfo.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                categoryInfo.label,
                                style: TextStyle(
                                  color: categoryInfo.color,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 状态标签
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusInfo.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusInfo.label,
                                style: TextStyle(
                                  color: statusInfo.color,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // 创建时间
                            Text(
                              _formatDate(feedback.createdAt),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FeedbackDetailScreen(
                                feedback: feedback,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FeedbackSubmitScreen(),
            ),
          );
          _loadFeedbacks(); // 返回后刷新列表
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 分类标签信息
class _CategoryInfo {
  final String label;
  final Color color;

  const _CategoryInfo({required this.label, required this.color});
}

/// 状态标签信息
class _StatusInfo {
  final String label;
  final Color color;

  const _StatusInfo({required this.label, required this.color});
}
