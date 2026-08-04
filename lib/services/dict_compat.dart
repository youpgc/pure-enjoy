import 'dart:convert';
import 'dict_service.dart';

/// 字典兼容旧代码方法（从 DictService 抽出，仅依赖其公开 API）
/// 与原类内实现逐字节一致。
extension DictServiceCompat on DictService {
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
    final items = getItemsSync(typeCode);
    try {
      return items.firstWhere((item) => item.isDefault).code;
    } catch (e) {
      return items.isNotEmpty ? items.first.code : '';
    }
  }

  /// 兼容旧代码：根据 code 查找 item
  DictItem? findByCode(String typeCode, String code) {
    final items = getItemsSync(typeCode);
    try {
      return items.firstWhere((item) => item.code == code);
    } catch (e) {
      return null;
    }
  }

  /// 兼容旧代码：getLabel 带 defaultValue 参数
  String getLabelOrDefault(String typeCode, String value, {String? defaultValue}) {
    final label = getLabel(typeCode, value);
    return label ?? defaultValue ?? value;
  }
}
