import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';

/// 通知中心页面 - 接入 Supabase notifications 表
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadNotifications();
      }
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _notifications = [];
        _isLoading = true;
        _error = null;
      });
    } else if (_offset == 0) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final userId = _userId;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _notifications = [];
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
        return;
      }
      // 查询当前用户的通知 + 系统通知（user_id 为 null）
      final result = await ApiClient.get(
        'notifications',
        filters: {'user_id': 'eq.$userId'},
        order: 'created_at.desc',
        limit: _limit,
        offset: _offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final newItems = data.cast<Map<String, dynamic>>();
        if (!mounted) return;
        setState(() {
          if (refresh) {
            _notifications = newItems;
          } else {
            _notifications.addAll(newItems);
          }
          _offset += _limit;
          _hasMore = newItems.length >= _limit;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _error = '加载通知失败 (${result.statusCode})';
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '网络异常，请稍后重试';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await ApiClient.patchByFilter(
        'notifications',
        filters: {'id': 'eq.$id'},
        body: {'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx >= 0) {
          _notifications[idx]['is_read'] = true;
          _notifications[idx]['read_at'] = DateTime.now().toUtc().toIso8601String();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('标记已读失败');
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final userId = _userId;
      if (userId == null) return;

      final unreadIds = _notifications
          .where((n) => !n['is_read'])
          .map((n) => n['id'])
          .toList();
      
      if (unreadIds.isEmpty) return;

      await ApiClient.patchByFilter(
        'notifications',
        filters: {'user_id': 'eq.$userId', 'is_read': 'eq.false'},
        body: {'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (!mounted) return;
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标为已读')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  int get _unreadCount => _notifications.where((n) => !n['is_read']).length;

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
      return const Center(child: CircularProgressIndicator());
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
              child: Center(child: CircularProgressIndicator()),
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
