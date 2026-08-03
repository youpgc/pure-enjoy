import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/dict_service.dart';
import '../../../../utils/date_time_utils.dart';
import '../../models/feedback_model.dart';

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

/// 操作标签信息
class _ActionInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _ActionInfo({required this.label, required this.icon, required this.color});
}

/// 获取分类标签信息
_CategoryInfo _getCategoryInfo(String category, BuildContext context) {
  final label = DictService.instance.getLabelOrDefault('feedback_category', category, defaultValue: category);
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
_StatusInfo _getStatusInfo(String status, BuildContext context) {
  final label = DictService.instance.getLabelOrDefault('feedback_status', status, defaultValue: status);
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
    case 'rejected':
      color = Theme.of(context).colorScheme.error;
    case 'delayed':
      color = Colors.orange;
    default:
      color = Theme.of(context).colorScheme.onSurfaceVariant;
  }
  return _StatusInfo(label: label, color: color);
}

/// 获取操作标签信息
_ActionInfo _getActionInfo(String action, BuildContext context) {
  final label = DictService.instance.getLabelOrDefault('feedback_status', action, defaultValue: action);
  final IconData icon;
  final Color color;
  switch (action) {
    case 'confirmed':
      icon = Icons.check_circle;
      color = Colors.blue;
    case 'in_progress':
      icon = Icons.sync;
      color = Colors.orange;
    case 'resolved':
      icon = Icons.check_circle_outline;
      color = AppTheme.success;
    case 'rejected':
      icon = Icons.cancel;
      color = Theme.of(context).colorScheme.error;
    case 'delayed':
      icon = Icons.schedule;
      color = Colors.orange;
    case 'deleted':
      icon = Icons.delete_outline;
      color = Colors.grey;
    default:
      icon = Icons.circle;
      color = Colors.grey;
  }
  return _ActionInfo(label: label, icon: icon, color: color);
}

/// 格式化时间
String _formatDate(String? dateStr) {
  if (dateStr == null) return '未知';
  try {
    final dt = DateTime.parse(dateStr);
    return DateTimeUtils.formatStandard(dt);
  } catch (_) {
    return dateStr;
  }
}

/// 标签
Widget _buildTag(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// 区块标题
Widget _buildSectionTitle(String title, BuildContext context) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
  );
}

/// {@template feedback_detail_content}
/// [FeedbackDetailScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段，不持有状态。
/// {@endtemplate}
class FeedbackDetailContent extends StatelessWidget {
  /// {@macro feedback_detail_content}
  const FeedbackDetailContent({
    super.key,
    required this.feedback,
    required this.flowRecords,
    required this.loadingFlow,
  });

  final FeedbackModel feedback;
  final List<Map<String, dynamic>> flowRecords;
  final bool loadingFlow;

  @override
  Widget build(BuildContext context) {
    final categoryInfo = _getCategoryInfo(feedback.category, context);
    final statusInfo = _getStatusInfo(feedback.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackTitleSection(
            feedback: feedback,
            categoryInfo: categoryInfo,
            statusInfo: statusInfo,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 24),
          _FeedbackFlowSection(
            flowRecords: flowRecords,
            loadingFlow: loadingFlow,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

/// 标题 + 标签行 + 问题描述 + 管理员回复。
class _FeedbackTitleSection extends StatelessWidget {
  const _FeedbackTitleSection({
    required this.feedback,
    required this.categoryInfo,
    required this.statusInfo,
    required this.colorScheme,
  });

  final FeedbackModel feedback;
  final _CategoryInfo categoryInfo;
  final _StatusInfo statusInfo;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          feedback.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTag(categoryInfo.label, categoryInfo.color),
            const SizedBox(width: 10),
            _buildTag(statusInfo.label, statusInfo.color),
            const Spacer(),
            Text(
              _formatDate(feedback.createdAt?.toIso8601String()),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('问题描述', context),
        const SizedBox(height: 8),
        Text(
          feedback.description ?? '无描述',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        if (feedback.adminReply != null && feedback.adminReply!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('管理员回复', context),
          const SizedBox(height: 8),
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
              ),
              side: AppTheme.cardBorderSide(
                context,
                colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
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
    );
  }
}

/// 流转记录区块（标题 + 加载/空/列表三态）。
class _FeedbackFlowSection extends StatelessWidget {
  const _FeedbackFlowSection({
    required this.flowRecords,
    required this.loadingFlow,
    required this.colorScheme,
  });

  final List<Map<String, dynamic>> flowRecords;
  final bool loadingFlow;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('流转记录', context),
        const SizedBox(height: 12),
        if (loadingFlow)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: LoadingWidget(),
            ),
          )
        else if (flowRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(
                UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
              ),
            ),
            child: Center(
              child: Text(
                '暂无流转记录',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...flowRecords.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final actionInfo = _getActionInfo(record['action'] ?? '', context);
            final isLast = index == flowRecords.length - 1;
            return _FeedbackTimelineItem(
              actionInfo: actionInfo,
              record: record,
              isLast: isLast,
              colorScheme: colorScheme,
            );
          }),
      ],
    );
  }
}

/// 流转记录时间线单项。
class _FeedbackTimelineItem extends StatelessWidget {
  const _FeedbackTimelineItem({
    required this.actionInfo,
    required this.record,
    required this.isLast,
    required this.colorScheme,
  });

  final _ActionInfo actionInfo;
  final Map<String, dynamic> record;
  final bool isLast;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Icon(actionInfo.icon, size: 20, color: actionInfo.color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 操作标签 + 时间 + 操作人
                  Row(
                    children: [
                      _buildTag(actionInfo.label, actionInfo.color),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(record['created_at']),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (record['operator_name'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          record['operator_name'],
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 备注
                  if (record['remark'] != null && record['remark'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(
                          UiStyleToken.of(AppTheme.uiStyleOf(context)).cardRadius,
                        ),
                      ),
                      child: Text(
                        record['remark'],
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
