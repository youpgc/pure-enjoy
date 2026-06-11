import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../core/models/dict_model.dart';

/// 数据字典服务
/// 带内存缓存，避免重复请求
class DictService {
  DictService._();
  static final DictService instance = DictService._();

  /// 缓存：typeCode -> List<DictItem>
  final Map<String, List<DictItem>> _cache = {};

  /// 缓存时间戳
  final Map<String, DateTime> _cacheTime = {};

  /// 缓存有效期（小时）
  static const int _cacheHours = 24;

  /// 是否已初始化
  bool _initialized = false;

  /// 字典类型编码常量
  // 用户相关
  static const String userRole = 'user_role';
  static const String memberLevel = 'member_level';
  static const String userStatus = 'user_status';
  // 业务数据
  static const String expenseCategory = 'expense_category';
  static const String moodType = 'mood_type';
  static const String habitFrequency = 'habit_frequency';
  static const String habitColor = 'habit_color';
  static const String novelCategory = 'novel_category';
  static const String novelStatus = 'novel_status';
  // 反馈相关
  static const String feedbackCategory = 'feedback_category';
  static const String feedbackStatus = 'feedback_status';
  // 通知公告
  static const String notificationType = 'notification_type';
  static const String announcementType = 'announcement_type';
  static const String priorityLevel = 'priority_level';
  // 版本发布
  static const String releaseType = 'release_type';
  static const String versionStatus = 'version_status';
  // 敏感词
  static const String sensitiveWordCategory = 'sensitive_word_category';
  static const String sensitiveWordLevel = 'sensitive_word_level';
  static const String matchMode = 'match_mode';
  // 操作日志
  static const String operationModule = 'operation_module';
  static const String operationAction = 'operation_action';
  // 文件类型
  static const String fileType = 'file_type';

  /// 初始化：预加载所有字典
  Future<void> initialize() async {
    if (_initialized) return;
    await Future.wait([
      // 用户相关
      getItems(userRole),
      getItems(memberLevel),
      getItems(userStatus),
      // 业务数据
      getItems(expenseCategory),
      getItems(moodType),
      getItems(habitFrequency),
      getItems(habitColor),
      getItems(novelCategory),
      getItems(novelStatus),
      // 反馈相关
      getItems(feedbackCategory),
      getItems(feedbackStatus),
      // 通知公告
      getItems(notificationType),
      getItems(announcementType),
      getItems(priorityLevel),
      // 版本发布
      getItems(releaseType),
      getItems(versionStatus),
      // 敏感词
      getItems(sensitiveWordCategory),
      getItems(sensitiveWordLevel),
      getItems(matchMode),
      // 操作日志
      getItems(operationModule),
      getItems(operationAction),
      // 文件类型
      getItems(fileType),
    ]);
    _initialized = true;
    debugPrint('✅ 字典服务初始化完成，缓存 ${_cache.length} 个类型');
  }

  /// 获取某类型的所有字典项
  Future<List<DictItem>> getItems(String typeCode) async {
    // 检查缓存
    if (_cache.containsKey(typeCode)) {
      final cacheTime = _cacheTime[typeCode];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime).inHours < _cacheHours) {
        return _cache[typeCode]!;
      }
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/dict_items?dict_types!inner(code)=eq.$typeCode&select=id,type_id,code,label,value,extra,sort_order,is_default,status&order=sort_order.asc',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final items = data
            .map((json) => DictItem.fromJson(json as Map<String, dynamic>))
            .where((item) => item.status == 'active')
            .toList();

        _cache[typeCode] = items;
        _cacheTime[typeCode] = DateTime.now();
        return items;
      }
    } catch (e) {
      debugPrint('❌ 加载字典失败 [$typeCode]: $e');
    }

    // 返回缓存（可能过期）或空列表
    return _cache[typeCode] ?? [];
  }

  /// 同步获取（需先调用 initialize）
  List<DictItem> getItemsSync(String typeCode) {
    return _cache[typeCode] ?? [];
  }

  /// 根据 code 查找字典项
  DictItem? findByCode(String typeCode, String itemCode) {
    final items = getItemsSync(typeCode);
    try {
      return items.firstWhere((item) => item.code == itemCode);
    } catch (e) {
      debugPrint('根据code查找字典项失败: $e');
      return null;
    }
  }

  /// 根据 code 获取 label
  String getLabel(String typeCode, String itemCode, {String defaultValue = ''}) {
    return findByCode(typeCode, itemCode)?.label ?? defaultValue;
  }

  /// 根据 code 获取 emoji
  String getEmoji(String typeCode, String itemCode) {
    return findByCode(typeCode, itemCode)?.emoji ?? '';
  }

  /// 获取所有 label 列表（用于下拉）
  List<String> getLabels(String typeCode) {
    return getItemsSync(typeCode).map((item) => item.label).toList();
  }

  /// 获取默认项
  DictItem? getDefault(String typeCode) {
    final items = getItemsSync(typeCode);
    try {
      return items.firstWhere((item) => item.isDefault);
    } catch (e) {
      debugPrint('获取默认字典项失败: $e');
      return items.isNotEmpty ? items.first : null;
    }
  }

  /// 获取默认项的 code
  String getDefaultCode(String typeCode) {
    return getDefault(typeCode)?.code ?? '';
  }

  /// 清除缓存
  void clearCache({String? typeCode}) {
    if (typeCode != null) {
      _cache.remove(typeCode);
      _cacheTime.remove(typeCode);
    } else {
      _cache.clear();
      _cacheTime.clear();
      _initialized = false;
    }
  }
}
