part of './point_records_screen_content.dart';

/// 积分类型映射（与数据库 point_records.type 和后台 POINT_TYPE_MAP 一致）
/// 标准类型：checkin / earn / spend / adjust / admin_adjust / game_earn / game_spend
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
    case 'game_earn':
      return PointTypeInfo(
        icon: Icons.sports_esports_outlined,
        label: '游戏奖励',
        color: Colors.green,
      );
    case 'game_spend':
      return PointTypeInfo(
        icon: Icons.sports_esports_outlined,
        label: '游戏消费',
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
    case 'expire':
      // 过期镜像流水（服务端每日过期任务生成，负数、status=expired）
      return PointTypeInfo(
        icon: Icons.hourglass_bottom,
        label: '积分过期',
        color: AppTheme.warning,
      );
    default:
      return PointTypeInfo(
        icon: Icons.help_outline,
        label: type,
        color: AppTheme.neutral500,
      );
  }
}

/// 单条积分记录
class PointRecordListItem extends StatelessWidget {
  const PointRecordListItem({
    super.key,
    required this.record,
    required this.typeInfo,
    required this.isPositive,
  });

  final PointRecord record;
  final PointTypeInfo typeInfo;
  final bool isPositive;

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
      // 右侧：增减积分在上、余额在下，垂直居中与左侧内容水平对齐
      title: Text(typeInfo.label),
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
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            isPositive ? '+${record.amount}' : '${record.amount}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppTheme.success : AppTheme.error,
            ),
          ),
          if (record.balanceAfter != null) ...[
            const SizedBox(height: 4),
            Text(
              '余额 ${record.balanceAfter}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
