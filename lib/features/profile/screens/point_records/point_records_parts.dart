part of './point_records_screen_content.dart';

/// 积分类型映射（与数据库 point_records.type 和后台 POINT_TYPE_MAP 一致）
/// 标准类型：checkin / earn / spend / adjust / admin_adjust
/// 兼容历史类型：admin_recharge（后台 POINT_TYPE_MAP 未单列，仅本端兼容映射到 admin_adjust）
PointTypeInfo _getTypeInfo(String type) {
  switch (type) {
    case 'checkin':
      return PointTypeInfo(
        icon: Icons.check_circle_outline,
        label: '签到',
        color: Colors.green,
      );
    case 'earn':
      return PointTypeInfo(
        icon: Icons.add_circle_outline,
        label: '获得',
        color: Colors.green,
      );
    case 'spend':
      return PointTypeInfo(
        icon: Icons.remove_circle_outline,
        label: '消费',
        color: AppTheme.error,
      );
    case 'adjust':
      return PointTypeInfo(
        icon: Icons.swap_horiz,
        label: '调整',
        color: AppTheme.info,
      );
    case 'admin_adjust':
    case 'admin_recharge': // 兼容历史数据
      return PointTypeInfo(
        icon: Icons.admin_panel_settings_outlined,
        label: '管理员调整',
        color: AppTheme.info,
      );
    default:
      return PointTypeInfo(
        icon: Icons.help_outline,
        label: type,
        color: AppTheme.neutral500,
      );
  }
}

/// 获取过期状态标签信息
ExpiryInfo _getExpiryInfo(PointRecord record) {
  if (record.status == 'expired') {
    return ExpiryInfo(
      label: '已过期',
      color: Colors.grey,
    );
  }
  if (record.expiresAt != null) {
    final now = DateTimeUtils.nowBeijing();
    final diff = record.expiresAt!.difference(now);
    if (diff.inDays <= 30 && diff.inDays >= 0) {
      return ExpiryInfo(
        label: '即将过期',
        color: AppTheme.warning,
      );
    }
  }
  return ExpiryInfo(
    label: '有效',
    color: Colors.green,
  );
}

/// 单条积分记录
class PointRecordListItem extends StatelessWidget {
  const PointRecordListItem({
    super.key,
    required this.record,
    required this.typeInfo,
    required this.isPositive,
    required this.expiryInfo,
  });

  final PointRecord record;
  final PointTypeInfo typeInfo;
  final bool isPositive;
  final ExpiryInfo expiryInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: typeInfo.color.withValues(alpha: 0.1),
        child: Icon(
          typeInfo.icon,
          color: typeInfo.color,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(typeInfo.label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: expiryInfo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              expiryInfo.label,
              style: TextStyle(
                fontSize: 11,
                color: expiryInfo.color,
              ),
            ),
          ),
          const Spacer(),
          Text(
            isPositive ? '+${record.amount}' : '${record.amount}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPositive ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.remark != null && record.remark!.isNotEmpty)
            Text(
              record.remark!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            DateTimeUtils.formatStandard(record.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
