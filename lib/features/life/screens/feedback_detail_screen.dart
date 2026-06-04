import 'package:flutter/material.dart';
import '../models/feedback_model.dart';

/// 问题反馈详情页面
class FeedbackDetailScreen extends StatelessWidget {
  final FeedbackModel feedback;

  const FeedbackDetailScreen({super.key, required this.feedback});

  /// 获取分类标签信息
  _CategoryInfo _getCategoryInfo(String category) {
    switch (category) {
      case 'bug':
        return _CategoryInfo(label: 'Bug', color: Colors.red);
      case 'feature':
        return _CategoryInfo(label: '功能建议', color: Colors.blue);
      case 'improvement':
        return _CategoryInfo(label: '体验优化', color: Colors.purple);
      case 'other':
        return _CategoryInfo(label: '其他', color: Colors.grey);
      default:
        return _CategoryInfo(label: category, color: Colors.grey);
    }
  }

  /// 获取状态标签信息
  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusInfo(label: '待确认', color: Colors.grey);
      case 'confirmed':
        return _StatusInfo(label: '已确认', color: Colors.blue);
      case 'in_progress':
        return _StatusInfo(label: '进行中', color: Colors.orange);
      case 'resolved':
        return _StatusInfo(label: '已完结', color: Colors.green);
      default:
        return _StatusInfo(label: status, color: Colors.grey);
    }
  }

  /// 格式化时间
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '未知';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final categoryInfo = _getCategoryInfo(feedback.category);
    final statusInfo = _getStatusInfo(feedback.status);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              feedback.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // 标签行：分类 + 状态
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryInfo.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryInfo.label,
                    style: TextStyle(
                      color: categoryInfo.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      color: statusInfo.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // 创建时间
                Text(
                  _formatDate(feedback.createdAt),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 分割线
            const Divider(),
            const SizedBox(height: 16),

            // 问题描述
            Text(
              '问题描述',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              feedback.description ?? '无描述',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.6,
              ),
            ),

            // 管理员答复区域
            if (feedback.adminReply != null &&
                feedback.adminReply!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                '管理员回复',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    feedback.adminReply!,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
