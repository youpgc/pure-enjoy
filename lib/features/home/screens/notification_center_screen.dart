import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
part 'notification_center_parts.dart';

/// 通知中心页面 - 接入 Supabase notifications 表
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> with _NotificationCenterScreenUiMixin {
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
      // 合并「本人通知」与「系统广播通知（user_id 为 null）」：
      // 后台 Notifications.tsx 发全局通知时 user_id 留空，App 端此前仅查 user_id=eq.$userId，
      // 导致系统/公告类通知用户永远收不到，闭环断裂。用 or 过滤把两类一并拉取。
      final result = await ApiClient.get(
        'notifications',
        filters: {'or': '(user_id.eq.$userId,user_id.is.null)'},
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
      final result = await ApiClient.patchByFilter(
        'notifications',
        filters: {'id': 'eq.$id'},
        body: {'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (!result.isSuccess) {
        if (kDebugMode) debugPrint('标记已读失败: ${result.error}');
        return;
      }
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

      final result = await ApiClient.patchByFilter(
        'notifications',
        filters: {'user_id': 'eq.$userId', 'is_read': 'eq.false'},
        body: {'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (!result.isSuccess) {
        if (kDebugMode) debugPrint('批量标记已读失败: ${result.error}');
        return;
      }
      if (!mounted) return;
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      if (mounted) {
        showSnackBar(context, '已全部标为已读');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '操作失败，请稍后重试', isError: true);
      }
    }
  }

  int get _unreadCount => _notifications.where((n) => !n['is_read']).length;

}

