part of './feedback_detail_content.dart';

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
