import 'dict_service.dart';

/// 字典查询方法（从 DictService 抽出，仅读取 cacheMap 公开只读缓存）
/// 与原类内实现逐字节一致。
extension DictServiceQueries on DictService {
  /// 获取指定类型的字典项（同步，内存缓存）
  List<DictItem> getItemsSync(String typeCode) {
    return cacheMap[typeCode] ?? [];
  }

  /// 获取指定类型的字典项（异步，确保已初始化）
  Future<List<DictItem>> getItems(String typeCode) async {
    await ensureInitialized();
    return cacheMap[typeCode] ?? [];
  }

  /// 获取字典项的标签
  /// 优先按 value 匹配，找不到时按 code 匹配（兼容业务表存储 code 的情况）
  String? getLabel(String typeCode, String value) {
    final items = cacheMap[typeCode] ?? [];
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
    final items = cacheMap[typeCode] ?? [];
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
    final items = cacheMap[typeCode] ?? [];
    return items.map((item) => {
          'value': item.value,
          'label': item.label,
          'extra': item.extra ?? '',
        }).toList();
  }

  /// 获取指定类型的字典项值列表
  List<String> getValues(String typeCode) {
    final items = cacheMap[typeCode] ?? [];
    return items.map((item) => item.value).toList();
  }

  /// 检查字典项是否存在
  bool hasItem(String typeCode, String value) {
    final items = cacheMap[typeCode] ?? [];
    return items.any((item) => item.value == value);
  }
}
