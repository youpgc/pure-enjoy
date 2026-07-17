import 'dart:convert';

/// 字典项
class DictItem {
  final String id;
  final String typeId;
  final String code;
  final String label;
  final String value;
  final String? extra;
  final int sortOrder;
  final bool isDefault;
  final bool isActive;
  final DateTime? updatedAt;

  DictItem({
    required this.id,
    required this.typeId,
    required this.code,
    required this.label,
    required this.value,
    this.extra,
    required this.sortOrder,
    required this.isDefault,
    required this.isActive,
    this.updatedAt,
  });

  factory DictItem.fromJson(Map<String, dynamic> json) {
    // extra 可能是 JSON 对象或字符串，统一转为字符串存储
    String? extraStr;
    final extra = json['extra'];
    if (extra is String) {
      extraStr = extra;
    } else if (extra is Map) {
      extraStr = jsonEncode(extra);
    }

    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      updatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    return DictItem(
      id: json['id']?.toString() ?? '',
      typeId: json['type_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      extra: extraStr,
      sortOrder: json['sort_order'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type_id': typeId,
        'code': code,
        'label': label,
        'value': value,
        'extra': extra,
        'sort_order': sortOrder,
        'is_default': isDefault,
        'is_active': isActive,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

/// 字典类型
class DictType {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isSystem;
  final bool isActive;
  final DateTime? updatedAt;

  DictType({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.sortOrder,
    required this.isSystem,
    required this.isActive,
    this.updatedAt,
  });

  factory DictType.fromJson(Map<String, dynamic> json) {
    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      updatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    return DictType(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      sortOrder: json['sort_order'] as int? ?? 0,
      isSystem: json['is_system'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: updatedAt,
    );
  }
}
