part of './notification_center_screen.dart';

/// 通知中心 UI 构建逻辑抽为 mixin (膨胀修复), 避免 [_NotificationCenterScreenState] 超 400 行。
mixin _NotificationCenterScreenUiMixin on State<NotificationCenterScreen> {
  IconData _getIcon(String? icon) {
    switch (icon) {
      case 'info_outline': return Icons.info_outline;
      case 'system_update': return Icons.system_update_outlined;
      case 'scale': return Icons.scale_outlined;
      case 'check_circle': return Icons.check_circle_outline;
      case 'book': return Icons.book_outlined;
      case 'receipt': return Icons.receipt_long_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getColor(String? color) {
    if (color == null) return Theme.of(context).colorScheme.primary;
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'system': return '系统';
      case 'update': return '更新';
      case 'reminder': return '提醒';
      case 'habit': return '习惯';
      case 'novel': return '小说';
      case 'expense': return '消费';
      default: return '通知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('通知中心${_unreadCount > 0 ? ' ($_unreadCount条未读)' : ''}'),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_outlined),
              onPressed: _unreadCount > 0 ? _markAllRead : null,
              tooltip: '全部已读',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadNotifications,
              tooltip: '刷新',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: LoadingWidget());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadNotifications,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_notifications.isEmpty && !_isLoadingMore) {
      return RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('暂无通知', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _buildNotificationList();
  }

  Widget _buildNotificationList() {
    return RefreshIndicator(
      onRefresh: () => _loadNotifications(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, index) {
          if (index >= _notifications.length) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index >= _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: LoadingWidget()),
            );
          }
          final item = _notifications[index];
          final isRead = item['is_read'] as bool? ?? false;
          final icon = _getIcon(item['icon'] as String?);
          final color = _getColor(item['color'] as String?);
          final type = _getTypeLabel(item['type'] as String?);
          final createdAt = item['created_at'] as String?;

          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Row(
              children: [
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  item['body'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isRead ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(type, style: TextStyle(fontSize: 10, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            onTap: isRead ? null : () => _markAsRead(item['id']),
          );
        },
      ),
    );
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final time = DateTime.parse(timeStr);
      final now = DateTime.now().toUtc();
      final diff = now.difference(time);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateFormat('MM-dd HH:mm').format(time.add(const Duration(hours: 8)));
    } catch (_) {
      return '';
    }
  }
}
