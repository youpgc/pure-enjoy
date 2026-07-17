import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../constants/app_constants.dart';
import 'dict_models.dart';

/// 兼容导出：DictItem/DictType 已抽到 dict_models.dart，
/// 原仅 import dict_service.dart 的调用方（含 test）无需改动即可访问。
export 'dict_models.dart';

/// 字典服务
/// 首页获取全部字典数据，本地缓存，后台静默更新
class DictService {
  DictService._();
  static final DictService _instance = DictService._();
  static DictService get instance => _instance;

  // 内存缓存
  Map<String, List<DictItem>> _cache = {};
  Map<String, String> _typeIdMap = {}; // code -> type_id
  bool _initialized = false;

  // 本地缓存 key
  static const String _cacheKey = 'dict_service_cache_v2';
  static const String _cacheTimestampKey = 'dict_service_cache_timestamp';
  static const String _cacheVersionKey = 'dict_service_cache_version';
  static const String _lastSyncTimeKey = 'dict_service_last_sync_time';
  static const int _cacheVersion = 1; // 缓存结构版本，变更时强制刷新

  /// 客户端需要的字典类型编码列表
  static const List<String> _neededCodes = dictCodes;

  /// 初始化（从本地缓存读取）
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getInt(_cacheVersionKey) ?? 0;

      // 缓存版本不匹配时清空
      if (cachedVersion != _cacheVersion) {
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheTimestampKey);
        await prefs.setInt(_cacheVersionKey, _cacheVersion);
      }

      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _cache = {};
        _typeIdMap = {};
        decoded.forEach((key, value) {
          if (key == '_typeIdMap') {
            _typeIdMap = (value as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v.toString()),
            );
          } else if (value is List) {
            _cache[key] = value
                .map((item) => DictItem.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        });
        if (kDebugMode) debugPrint('✅ 字典服务从本地缓存加载完成');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 字典服务加载本地缓存失败');
    }

    _initialized = true;
  }

  /// 从网络加载全部字典数据（首页调用）
  /// 一次性获取所有 dict_types 和 dict_items，只需 2 次请求
  Future<void> loadFromNetwork() async {
    try {
      if (kDebugMode) debugPrint('🔄 字典服务开始从网络加载...');

      // 第1次请求：获取所有 dict_types
      final typesResult = await ApiClient.get(
        'dict_types',
        select: 'id,code,name,description,sort_order,is_system,is_active,updated_at',
        limit: null, // 取消限制，获取全部
      );

      if (!typesResult.isSuccess || typesResult.data == null) {
        if (kDebugMode) debugPrint('❌ 字典类型加载失败');
        return;
      }

      final allTypes = typesResult.data!
          .map((json) => DictType.fromJson(json))
          .where((t) => t.isActive)
          .toList();

      // 建立 code -> id 映射（只缓存客户端需要的类型）
      _typeIdMap = {};
      for (final type in allTypes) {
        if (_neededCodes.contains(type.code)) {
          _typeIdMap[type.code] = type.id;
        }
      }

      // 第2次请求：一次性获取所有需要的 dict_items
      final neededIds = _typeIdMap.values.toList();
      if (neededIds.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ 没有需要加载的字典类型');
        return;
      }

      final idList = neededIds.map((id) => '"$id"').join(',');
      final itemsResult = await ApiClient.get(
        'dict_items',
        filters: {'type_id': 'in.($idList)', 'is_active': 'eq.true'},
        select: 'id,type_id,code,label,value,extra,sort_order,is_default,is_active,updated_at',
        order: 'sort_order.asc',
        limit: null, // 取消限制，获取全部
      );

      if (!itemsResult.isSuccess || itemsResult.data == null) {
        if (kDebugMode) debugPrint('❌ 字典项加载失败');
        return;
      }

      // 按 type_id 分组
      final newCache = <String, List<DictItem>>{};
      for (final json in itemsResult.data!) {
        final item = DictItem.fromJson(json);
        final typeCode = _typeIdMap.entries
            .firstWhere((entry) => entry.value == item.typeId,
                orElse: () => const MapEntry('', ''))
            .key;
        if (typeCode.isNotEmpty) {
          newCache.putIfAbsent(typeCode, () => []);
          newCache[typeCode]!.add(item);
        }
      }

      // 更新内存缓存
      _cache = newCache;

      // 保存到本地缓存
      await _saveToLocalCache();

      // 记录同步时间（用于增量更新）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) debugPrint('✅ 字典服务网络加载完成');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 字典服务网络加载失败');
    }
  }

  /// 后台静默更新（已有缓存时尝试增量更新）
  Future<void> silentRefresh() async {
    if (_cache.isEmpty) {
      // 没有缓存时直接全量网络加载
      await loadFromNetwork();
      return;
    }

    try {
      if (kDebugMode) debugPrint('🔄 字典服务后台静默更新...');

      // 尝试增量更新
      final success = await _incrementalRefresh();
      if (!success) {
        // 增量失败，回退到全量更新
        if (kDebugMode) debugPrint('⚠️ 增量更新失败，回退到全量更新');
        await loadFromNetwork();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 字典服务静默更新失败（使用缓存）');
    }
  }

  /// 增量更新：仅获取上次同步后变更的字典项
  /// 返回 true 表示增量更新成功，false 表示需要全量更新
  Future<bool> _incrementalRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_lastSyncTimeKey);
      if (lastSyncMs == null) {
        // 没有同步时间记录，无法增量更新
        return false;
      }

      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      final syncTimestamp = lastSync.toUtc().toIso8601String();

      if (kDebugMode) debugPrint('🔄 增量更新，起始时间: $syncTimestamp');

      // 第1次请求：检查 dict_types 是否有变更（新增/删除类型）
      final typesResult = await ApiClient.get(
        'dict_types',
        select: 'id,code,name,description,sort_order,is_system,is_active,updated_at',
        filters: {'updated_at': 'gt.$syncTimestamp'},
        limit: null,
      );

      if (!typesResult.isSuccess) return false;

      // 如果有类型变更，需要全量更新（类型增删影响整体结构）
      if (typesResult.data != null && typesResult.data!.isNotEmpty) {
        if (kDebugMode) debugPrint('🔄 检测到字典类型变更，需要全量更新');
        return false;
      }

      // 第2次请求：获取变更的 dict_items
      final neededIds = _typeIdMap.values.toList();
      if (neededIds.isEmpty) return false;

      final idList = neededIds.map((id) => '"$id"').join(',');
      final itemsResult = await ApiClient.get(
        'dict_items',
        filters: {
          'type_id': 'in.($idList)',
          'updated_at': 'gt.$syncTimestamp',
        },
        select: 'id,type_id,code,label,value,extra,sort_order,is_default,is_active,updated_at',
        order: 'sort_order.asc',
        limit: null,
      );

      if (!itemsResult.isSuccess) return false;

      final changedItems = itemsResult.data ?? [];

      if (changedItems.isEmpty) {
        // 没有变更，只更新同步时间
        await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode) debugPrint('✅ 字典无变更');
        return true;
      }

      if (kDebugMode) debugPrint('🔄 增量更新 ${changedItems.length} 条变更项');

      // 合并变更项到现有缓存
      for (final json in changedItems) {
        final item = DictItem.fromJson(json);
        final typeCode = _typeIdMap.entries
            .firstWhere((entry) => entry.value == item.typeId,
                orElse: () => const MapEntry('', ''))
            .key;

        if (typeCode.isNotEmpty) {
          final typeItems = _cache[typeCode] ?? [];
          final existingIndex = typeItems.indexWhere((i) => i.id == item.id);

          if (!item.isActive) {
            // 已停用的项从缓存中移除
            if (existingIndex >= 0) {
              typeItems.removeAt(existingIndex);
            }
          } else if (existingIndex >= 0) {
            // 更新已有项
            typeItems[existingIndex] = item;
          } else {
            // 新增项
            typeItems.add(item);
          }
        }
      }

      // 更新同步时间并保存缓存
      await _saveToLocalCache();
      await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) debugPrint('✅ 字典增量更新完成');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 增量更新异常: $e');
      return false;
    }
  }

  /// 保存到本地缓存
  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = <String, dynamic>{};

      _cache.forEach((key, items) {
        cacheData[key] = items.map((item) => item.toJson()).toList();
      });

      cacheData['_typeIdMap'] = _typeIdMap;

      await prefs.setString(_cacheKey, jsonEncode(cacheData));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_cacheVersionKey, _cacheVersion);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 字典服务保存本地缓存失败');
    }
  }

  /// 确保已初始化
  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// 获取指定类型的字典项（同步，内存缓存）
  List<DictItem> getItemsSync(String typeCode) {
    return _cache[typeCode] ?? [];
  }

  /// 获取指定类型的字典项（异步，确保已初始化）
  Future<List<DictItem>> getItems(String typeCode) async {
    await ensureInitialized();
    return _cache[typeCode] ?? [];
  }

  /// 获取字典项的标签
  /// 优先按 value 匹配，找不到时按 code 匹配（兼容业务表存储 code 的情况）
  String? getLabel(String typeCode, String value) {
    final items = _cache[typeCode] ?? [];
    try {
      return items.firstWhere((item) => item.value == value).label;
    } catch (e) {
      // value 未匹配到，尝试按 code 匹配
      try {
        return items.firstWhere((item) => item.code == value).label;
      } catch (e) {
        return null;
      }
    }
  }

  /// 获取字典项的额外信息
  /// 优先按 value 匹配，找不到时按 code 匹配
  String? getExtra(String typeCode, String value) {
    final items = _cache[typeCode] ?? [];
    try {
      return items.firstWhere((item) => item.value == value).extra;
    } catch (e) {
      try {
        return items.firstWhere((item) => item.code == value).extra;
      } catch (e) {
        return null;
      }
    }
  }

  /// 获取指定类型的字典项选项（用于下拉选择）
  List<Map<String, String>> getOptions(String typeCode) {
    final items = _cache[typeCode] ?? [];
    return items.map((item) => {
      'value': item.value,
      'label': item.label,
      'extra': item.extra ?? '',
    }).toList();
  }

  /// 获取指定类型的字典项值列表
  List<String> getValues(String typeCode) {
    final items = _cache[typeCode] ?? [];
    return items.map((item) => item.value).toList();
  }

  /// 检查字典项是否存在
  bool hasItem(String typeCode, String value) {
    final items = _cache[typeCode] ?? [];
    return items.any((item) => item.value == value);
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
    _typeIdMap.clear();
    if (kDebugMode) debugPrint('🗑️ 字典缓存已清空');
  }

  /// 获取缓存状态
  Map<String, dynamic> getCacheStatus() {
    return {
      'initialized': _initialized,
      'typeCount': _cache.length,
      'totalItemCount': _cache.values.fold(0, (sum, items) => sum + items.length),
      'cachedTypes': _cache.keys.toList(),
    };
  }

  // ==================== 兼容旧代码方法 ====================

  /// 兼容旧代码：获取 emoji（从 extra 字段解析 JSON）
  String getEmoji(String typeCode, String value) {
    final extra = getExtra(typeCode, value);
    if (extra == null || extra.isEmpty) return '';
    try {
      final Map<String, dynamic> parsed = jsonDecode(extra);
      return parsed['emoji'] as String? ?? extra;
    } catch (_) {
      return extra;
    }
  }

  /// 兼容旧代码：获取默认 code
  String getDefaultCode(String typeCode) {
    final items = _cache[typeCode] ?? [];
    try {
      return items.firstWhere((item) => item.isDefault).code;
    } catch (e) {
      return items.isNotEmpty ? items.first.code : '';
    }
  }

  /// 兼容旧代码：根据 code 查找 item
  DictItem? findByCode(String typeCode, String code) {
    final items = _cache[typeCode] ?? [];
    try {
      return items.firstWhere((item) => item.code == code);
    } catch (e) {
      return null;
    }
  }

  /// 兼容旧代码：refreshNotifier（空实现，旧代码用它触发刷新）
  ValueNotifier<int> get refreshNotifier => ValueNotifier<int>(0);

  /// 兼容旧代码：通过属性访问 moodType
  static List<DictItem> get moodType => _instance._cache['mood_type'] ?? [];
  static List<DictItem> get expenseCategory => _instance._cache['expense_category'] ?? [];
  static List<DictItem> get userRole => _instance._cache['user_role'] ?? [];
  static List<DictItem> get memberLevel => _instance._cache['member_level'] ?? [];
  static List<DictItem> get habitFrequency => _instance._cache['habit_frequency'] ?? [];
  static List<DictItem> get habitColor => _instance._cache['habit_color'] ?? [];
  static List<DictItem> get novelCategory => _instance._cache['novel_category'] ?? [];
  static List<DictItem> get novelStatus => _instance._cache['novel_status'] ?? [];
  static List<DictItem> get feedbackCategory => _instance._cache['feedback_category'] ?? [];
  static List<DictItem> get feedbackStatus => _instance._cache['feedback_status'] ?? [];
  static List<DictItem> get notificationType => _instance._cache['notification_type'] ?? [];
  static List<DictItem> get announcementType => _instance._cache['announcement_type'] ?? [];
  static List<DictItem> get priorityLevel => _instance._cache['priority_level'] ?? [];
  static List<DictItem> get favoriteCategory => _instance._cache['favorite_category'] ?? [];
  static List<DictItem> get noteCategory => _instance._cache['note_category'] ?? [];

  /// 兼容旧代码：getLabel 带 defaultValue 参数
  String getLabelOrDefault(String typeCode, String value, {String? defaultValue}) {
    final label = getLabel(typeCode, value);
    return label ?? defaultValue ?? value;
  }
}
