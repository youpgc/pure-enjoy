import 'dart:async';
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

  /// 加载中的类型
  final Set<String> _loading = {};

  /// 通知 UI 刷新
  final ValueNotifier<bool> refreshNotifier = ValueNotifier<bool>(false);

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

  /// 初始化：预加载所有字典（分批加载，避免 API 限流）
  Future<void> initialize() async {
    if (_initialized) return;

    final allTypes = [
      userRole, memberLevel, userStatus,
      expenseCategory, moodType, habitFrequency, habitColor,
      novelCategory, novelStatus,
      feedbackCategory, feedbackStatus,
      notificationType, announcementType, priorityLevel,
      releaseType, versionStatus,
      sensitiveWordCategory, sensitiveWordLevel, matchMode,
      operationModule, operationAction,
      fileType,
    ];

    // 分批加载，每批 5 个，避免并发限流
    const batchSize = 5;
    for (var i = 0; i < allTypes.length; i += batchSize) {
      final batch = allTypes.sublist(i, i + batchSize > allTypes.length ? allTypes.length : i + batchSize);
      await Future.wait(batch.map((type) => getItems(type).catchError((_) => <DictItem>[])));
    }

    _initialized = true;
    debugPrint('✅ 字典服务初始化完成，缓存 ${_cache.length} 个类型');
  }

  /// 获取某类型的所有字典项（带重试）
  Future<List<DictItem>> getItems(String typeCode, {int retryCount = 2}) async {
    // 检查缓存（缓存存在且非空且在有效期内）
    if (_cache.containsKey(typeCode) && _cache[typeCode]!.isNotEmpty) {
      final cacheTime = _cacheTime[typeCode];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime).inHours < _cacheHours) {
        return _cache[typeCode]!;
      }
    }

    for (var attempt = 0; attempt <= retryCount; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 字典加载重试 [$typeCode]: 第 $attempt 次');
          await Future.delayed(const Duration(seconds: 1));
        }

        // Step 1: 先查 dict_types 获取 type_id
        final typeResponse = await http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/dict_types?code=eq.$typeCode&select=id',
          ),
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          },
        );

        if (typeResponse.statusCode != 200) {
          debugPrint('❌ 查询 dict_types 失败: ${typeResponse.statusCode}');
          continue;
        }

        final typeData = jsonDecode(typeResponse.body) as List;
        if (typeData.isEmpty) {
          debugPrint('❌ 字典类型不存在: $typeCode');
          break;
        }

        final typeId = typeData[0]['id'] as String;

        // Step 2: 通过 type_id 查 dict_items
        final response = await http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/dict_items?type_id=eq.$typeId&select=id,type_id,code,label,value,extra,sort_order,is_default,status&order=sort_order.asc',
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
          debugPrint('✅ 字典加载成功 [$typeCode]: ${items.length} 项');
          return items;
        } else {
          debugPrint('❌ 查询 dict_items 失败: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ 加载字典失败 [$typeCode]: $e (attempt $attempt/$retryCount)');
      }
    }

    // 返回缓存（可能过期）或空列表
    return _cache[typeCode] ?? [];
  }

  /// 同步获取（如果未加载，自动触发异步加载并返回空列表）
  List<DictItem> getItemsSync(String typeCode) {
    // 如果缓存中有数据，直接返回
    if (_cache.containsKey(typeCode) && _cache[typeCode]!.isNotEmpty) {
      return _cache[typeCode]!;
    }
    // 如果未加载且不在加载中，触发异步加载
    if (!_loading.contains(typeCode)) {
      _ensureLoaded(typeCode);
    }
    return _cache[typeCode] ?? [];
  }

  /// 确保某类型已加载（异步）
  Future<void> _ensureLoaded(String typeCode) async {
    if (_cache.containsKey(typeCode) && _cache[typeCode]!.isNotEmpty) return;
    if (_loading.contains(typeCode)) return;

    _loading.add(typeCode);
    try {
      final items = await getItems(typeCode);
      if (items.isNotEmpty) {
        refreshNotifier.value = !refreshNotifier.value;
      }
    } finally {
      _loading.remove(typeCode);
    }
  }

  /// 根据 code 查找字典项
  DictItem? findByCode(String typeCode, String itemCode) {
    final items = getItemsSync(typeCode);
    try {
      return items.firstWhere((item) => item.code == itemCode);
    } catch (e) {
      return null;
    }
  }

  /// 根据 code 获取 label
  String getLabel(String typeCode, String itemCode, {String? defaultValue}) {
    return findByCode(typeCode, itemCode)?.label ?? (defaultValue ?? itemCode);
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
