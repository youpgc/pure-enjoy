import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'notifications',
        filters: {'user_id': 'eq.$_userId'},
        order: 'created_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _notifications = result.data!;
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

  Future<void> _markAsRead(String id) async {
    try {
      final result = await ApiClient.patch(
        'notifications',
        filters: {'id': 'eq.$id'},
        body: {'is_read': true},
      );

      if (result.isSuccess) {
        _loadNotifications();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('标记失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('标记失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      final result = await ApiClient.delete(
        'notifications',
        filters: {'id': 'eq.$id'},
      );

      if (result.isSuccess) {
        _loadNotifications();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                // 标记所有为已读
                for (final notification in _notifications.where((n) => !(n['is_read'] ?? false))) {
                  await _markAsRead(notification['id']);
                }
              },
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('暂无通知'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final createdAt = DateTime.parse(notification['created_at']);
                    final isRead = notification['is_read'] ?? false;

                    return Dismissible(
                      key: Key(notification['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNotification(notification['id']),
                      child: ListTile(
                        leading: Icon(
                          isRead ? Icons.notifications_none : Icons.notifications,
                          color: isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          notification['title'] ?? '无标题',
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(notification['content'] ?? ''),
                        trailing: Text(
                          DateFormat('MM-dd HH:mm').format(createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(notification['id']);
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
