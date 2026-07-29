import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/event_bus.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/api_client.dart';
import '../../../../services/dict_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/request_cache.dart';
import '../../../life/models/habit_model.dart';
import '../../../life/models/reminder_model.dart';
import '../../../life/screens/reminders_screen.dart';
import '../../../novel/models/novel_model.dart';
import '../../../novel/services/novel_launch_service.dart';
import '../notification_center_screen.dart';
import '../sheets/sheets.dart';
import './dashboard_helpers.dart';
import './dashboard_widgets.dart';
import './dashboard_activity_helpers.dart';
import './dashboard_tool_handlers.dart';
import '../../services/announcement_service.dart';
import '../../widgets/announcement_banner.dart';
part 'dashboard_logic_mixin.dart';
part 'dashboard_page_parts.dart';

/// 首页仪表板页面
///
/// 包含 DashboardPage 及其相关组件，展示用户欢迎信息、快捷工具、
/// 待办提醒、习惯打卡、最近阅读和最近活动等内容。
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
