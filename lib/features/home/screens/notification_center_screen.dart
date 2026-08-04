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
}
