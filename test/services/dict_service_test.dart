import 'package:flutter_test/flutter_test.dart';
import 'package:pure_enjoy/services/dict_service.dart';

void main() {
  group('DictItem', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'item-001',
        'type_id': 'type-001',
        'code': 'happy',
        'label': '开心',
        'value': '1',
        'extra': '{"emoji":"😊"}',
        'sort_order': 1,
        'is_default': false,
        'is_active': true,
        'updated_at': '2026-01-15T10:30:00.000Z',
      };

      final item = DictItem.fromJson(json);

      expect(item.id, 'item-001');
      expect(item.typeId, 'type-001');
      expect(item.code, 'happy');
      expect(item.label, '开心');
      expect(item.value, '1');
      expect(item.extra, '{"emoji":"😊"}');
      expect(item.sortOrder, 1);
      expect(item.isDefault, false);
      expect(item.isActive, true);
      expect(item.updatedAt, isNotNull);
      expect(item.updatedAt!.year, 2026);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'item-002',
        'type_id': 'type-001',
        'code': 'sad',
        'label': '难过',
        'value': '2',
        'sort_order': 2,
        'is_default': true,
        'is_active': true,
      };

      final item = DictItem.fromJson(json);

      expect(item.id, 'item-002');
      expect(item.extra, isNull);
      expect(item.updatedAt, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final item = DictItem.fromJson(json);

      expect(item.id, '');
      expect(item.typeId, '');
      expect(item.code, '');
      expect(item.label, '');
      expect(item.value, '');
      expect(item.sortOrder, 0);
      expect(item.isDefault, false);
      expect(item.isActive, true);
    });

    test('fromJson converts Map extra to JSON string', () {
      final json = {
        'id': 'item-003',
        'type_id': 'type-001',
        'code': 'test',
        'label': '测试',
        'value': '3',
        'extra': {'key': 'value'},
        'sort_order': 0,
        'is_default': false,
        'is_active': true,
      };

      final item = DictItem.fromJson(json);

      expect(item.extra, isNotNull);
      expect(item.extra, contains('key'));
      expect(item.extra, contains('value'));
    });

    test('toJson produces correct map', () {
      final item = DictItem(
        id: 'item-001',
        typeId: 'type-001',
        code: 'happy',
        label: '开心',
        value: '1',
        extra: 'extra_data',
        sortOrder: 1,
        isDefault: false,
        isActive: true,
        updatedAt: DateTime.utc(2026, 1, 15),
      );

      final json = item.toJson();

      expect(json['id'], 'item-001');
      expect(json['type_id'], 'type-001');
      expect(json['code'], 'happy');
      expect(json['label'], '开心');
      expect(json['value'], '1');
      expect(json['extra'], 'extra_data');
      expect(json['sort_order'], 1);
      expect(json['is_default'], false);
      expect(json['is_active'], true);
      expect(json['updated_at'], isNotNull);
    });

    test('toJson omits updated_at when null', () {
      final item = DictItem(
        id: 'item-001',
        typeId: 'type-001',
        code: 'test',
        label: '测试',
        value: '1',
        sortOrder: 0,
        isDefault: false,
        isActive: true,
      );

      final json = item.toJson();

      expect(json.containsKey('updated_at'), false);
    });

    test('fromJson and toJson roundtrip preserves data', () {
      final original = DictItem(
        id: 'round-trip',
        typeId: 'type-rt',
        code: 'rt_code',
        label: '往返测试',
        value: '42',
        extra: 'some_extra',
        sortOrder: 5,
        isDefault: true,
        isActive: true,
        updatedAt: DateTime.utc(2026, 6, 1),
      );

      final json = original.toJson();
      final restored = DictItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.typeId, original.typeId);
      expect(restored.code, original.code);
      expect(restored.label, original.label);
      expect(restored.value, original.value);
      expect(restored.extra, original.extra);
      expect(restored.sortOrder, original.sortOrder);
      expect(restored.isDefault, original.isDefault);
      expect(restored.isActive, original.isActive);
    });
  });

  group('DictType', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'type-001',
        'code': 'mood_type',
        'name': '心情类型',
        'description': '用户心情分类',
        'sort_order': 1,
        'is_system': true,
        'is_active': true,
        'updated_at': '2026-03-20T08:00:00.000Z',
      };

      final type = DictType.fromJson(json);

      expect(type.id, 'type-001');
      expect(type.code, 'mood_type');
      expect(type.name, '心情类型');
      expect(type.description, '用户心情分类');
      expect(type.sortOrder, 1);
      expect(type.isSystem, true);
      expect(type.isActive, true);
      expect(type.updatedAt, isNotNull);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'type-002',
        'code': 'test_type',
        'name': '测试类型',
        'sort_order': 0,
        'is_system': false,
        'is_active': true,
      };

      final type = DictType.fromJson(json);

      expect(type.description, isNull);
      expect(type.updatedAt, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final type = DictType.fromJson(json);

      expect(type.id, '');
      expect(type.code, '');
      expect(type.name, '');
      expect(type.description, isNull);
      expect(type.sortOrder, 0);
      expect(type.isSystem, false);
      expect(type.isActive, true);
    });
  });

  group('DictService - 内存操作', () {
    late DictService service;

    setUp(() {
      service = DictService.instance;
      service.clearCache();
    });

    test('singleton instance is consistent', () {
      final a = DictService.instance;
      final b = DictService.instance;

      expect(identical(a, b), true);
    });

    test('getItemsSync returns empty list for unknown type', () {
      final items = service.getItemsSync('nonexistent_type');

      expect(items, isEmpty);
    });

    test('getLabel returns null for unknown type', () {
      final label = service.getLabel('nonexistent_type', 'some_value');

      expect(label, isNull);
    });

    test('getLabelOrDefault returns default for unknown type', () {
      final label = service.getLabelOrDefault(
        'nonexistent_type',
        'some_value',
        defaultValue: '默认值',
      );

      expect(label, '默认值');
    });

    test('getLabelOrDefault returns value when no default', () {
      final label = service.getLabelOrDefault(
        'nonexistent_type',
        'some_value',
      );

      expect(label, 'some_value');
    });

    test('getOptions returns empty list for unknown type', () {
      final options = service.getOptions('nonexistent_type');

      expect(options, isEmpty);
    });

    test('getValues returns empty list for unknown type', () {
      final values = service.getValues('nonexistent_type');

      expect(values, isEmpty);
    });

    test('hasItem returns false for unknown type', () {
      final exists = service.hasItem('nonexistent_type', 'value');

      expect(exists, false);
    });

    test('getEmoji returns empty string for unknown type', () {
      final emoji = service.getEmoji('nonexistent_type', 'value');

      expect(emoji, '');
    });

    test('getDefaultCode returns empty string for unknown type', () {
      final code = service.getDefaultCode('nonexistent_type');

      expect(code, '');
    });

    test('findByCode returns null for unknown type', () {
      final item = service.findByCode('nonexistent_type', 'code');

      expect(item, isNull);
    });

    test('clearCache does not throw on empty cache', () {
      expect(() => service.clearCache(), returnsNormally);
    });

    test('getCacheStatus returns correct structure', () {
      final status = service.getCacheStatus();

      expect(status.containsKey('initialized'), true);
      expect(status.containsKey('typeCount'), true);
      expect(status.containsKey('totalItemCount'), true);
      expect(status.containsKey('cachedTypes'), true);
      expect(status['typeCount'], 0);
      expect(status['totalItemCount'], 0);
    });

    test('static getters return empty lists before initialization', () {
      expect(DictService.moodType, isEmpty);
      expect(DictService.expenseCategory, isEmpty);
      expect(DictService.userRole, isEmpty);
      expect(DictService.memberLevel, isEmpty);
      expect(DictService.novelCategory, isEmpty);
      expect(DictService.novelStatus, isEmpty);
      expect(DictService.feedbackCategory, isEmpty);
      expect(DictService.feedbackStatus, isEmpty);
    });
  });
}
