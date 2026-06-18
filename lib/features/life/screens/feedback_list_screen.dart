import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
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
      final result = await ApiClient.get(
        'user_feedback',
        filters: {'user_id': 'eq.$userId'},
        order: 'created_at.desc',
      );

      if (result.isSuccess) {
        final feedbacks = result.data!.map((e) => FeedbackModel.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _feedbacks = feedbacks;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(result.errorMessage ?? '请求失败');
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
    final label = DictService.instance.getLabel(DictService.feedbackCategory, category, defaultValue: category);
    final Color color;
    switch (category) {
      case 'bug':
        color = Theme.of(context).colorScheme.error;
      case 'feature':
        color = Theme.of(context).colorScheme.primary;
      case 'improvement':
        color = Theme.of(context).colorScheme.primary;
      case 'other':
        color = Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return _CategoryInfo(label: label, color: color);
  }

  /// 获取状态标签信息
  _StatusInfo _getStatusInfo(String status) {
    final label = DictService.instance.getLabel(DictService.feedbackStatus, status, defaultValue: status);
    final Color color;
    switch (status) {
      case 'pending':
        color = Theme.of(context).colorScheme.onSurfaceVariant;
      case 'confirmed':
        color = Theme.of(context).colorScheme.primary;
      case 'in_progress':
        color = Theme.of(context).colorScheme.secondary;
      case 'resolved':
        color = AppTheme.success;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return _StatusInfo(label: label, color: color);
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
