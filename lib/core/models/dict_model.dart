/// 字典类型模型
class DictType {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isSystem;
  final String status;
  final DateTime createdAt;

  DictType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.isSystem = false,
    this.status = 'active',
    required this.createdAt,
  });

  factory DictType.fromJson(Map<String, dynamic> json) {
    return DictType(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// 字典项模型
class DictItem {
  final String id;
  final String typeId;
  final String code;
  final String label;
  final String? value;
  final Map<String, dynamic>? extra;
  final int sortOrder;
  final bool isDefault;
  final String status;

  DictItem({
    required this.id,
    required this.typeId,
    required this.code,
    required this.label,
    this.value,
    this.extra,
    this.sortOrder = 0,
    this.isDefault = false,
    this.status = 'active',
  });

  factory DictItem.fromJson(Map<String, dynamic> json) {
    // 安全解析 extra 字段（可能是 null、dict 或空字符串）
    Map<String, dynamic>? parsedExtra;
    final rawExtra = json['extra'] ?? json['extra_data'];
    if (rawExtra is Map) {
      parsedExtra = Map<String, dynamic>.from(rawExtra);
    }

    return DictItem(
      id: json['id'] as String,
      typeId: json['type_id'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      value: json['value'] as String?,
      extra: parsedExtra,
      sortOrder: json['sort_order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// 获取扩展字段中的字符串值
  String? extraString(String key) {
    return extra?[key]?.toString();
  }

  /// 获取扩展字段中的整数值
  int? extraInt(String key) {
    final v = extra?[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 获取 emoji（如果有）
  String? get emoji => extraString('emoji');

  /// 获取颜色值（如果有）
  int? get color => extraInt('color');

  /// 获取图标名（如果有）
  String? get icon => extraString('icon');
}
