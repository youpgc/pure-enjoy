import 'package:flutter_test/flutter_test.dart';
import 'package:pure_enjoy/features/pets/widgets/pet_home_adventure.dart';

void main() {
  group('buildClaimItems 掉落明细', () {
    test('同一笔掉落同时出现在 items 与 long_drops 时只计一次', () {
      final items = buildClaimItems({
        'items': [
          {'code': 'star_compass', 'name': '星辰罗盘', 'qty': 1},
        ],
        'long_drops': [
          {'code': 'star_compass', 'name': '星辰罗盘', 'forced': true},
        ],
      });
      expect(items.length, 1);
      expect(items.first.qty, 1);
      expect(items.first.name, '星辰罗盘');
    });

    test('items 缺码时 long_drops 仍可补入', () {
      final items = buildClaimItems({
        'items': <Map<String, dynamic>>[],
        'long_drops': [
          {'code': 'star_compass', 'name': '星辰罗盘', 'forced': false},
        ],
      });
      expect(items.length, 1);
      expect(items.first.qty, 1);
    });

    test('items 同码多笔照常累加，且不被 long_drops 重复叠加', () {
      final items = buildClaimItems({
        'items': [
          {'code': 'snack_fish', 'name': '小鱼干', 'qty': 2},
          {'code': 'snack_fish', 'name': '小鱼干', 'qty': 3},
        ],
        'long_drops': [
          {'code': 'snack_fish', 'name': '小鱼干', 'forced': false},
        ],
      });
      expect(items.length, 1);
      expect(items.first.qty, 5);
    });

    test('不同码掉落互不干扰', () {
      final items = buildClaimItems({
        'items': [
          {'code': 'star_compass', 'name': '星辰罗盘', 'qty': 1},
        ],
        'long_drops': [
          {'code': 'evo_stone_n', 'name': '凡品石', 'forced': true},
        ],
      });
      expect(items.length, 2);
      expect(items.map((e) => e.qty), containsAll(<int>[1, 1]));
    });
  });
}
