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
  static const String expenseCategory = 'expense_category';
  static const String moodType = 'mood_type';
  static const String novelCategory = 'novel_category';
  static const String habitFrequency = 'habit_frequency';
  static const String habitColor = 'habit_color';

  /// 初始化：预加载所有字典
  Future<void> initialize() async {
    if (_initialized) return;
    await Future.wait([
      getItems(expenseCategory),
      getItems(moodType),
      getItems(novelCategory),
      getItems(habitFrequency),
      getItems(habitColor),
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
          '${AppConfig.supabaseUrl}/rest/v1/dict_items?dict_types!inner(code)=eq.$typeCode&select=id,type_id,code,label,value,extra_data,sort_order,is_default,status&order=sort_order.asc',
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
    } catch (_) {
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
    } catch (_) {
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
