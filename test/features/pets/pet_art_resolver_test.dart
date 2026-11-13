import 'package:flutter_test/flutter_test.dart';

import 'package:pure_enjoy/features/pets/utils/pet_art_resolver.dart';

/// 主舞台展示几何回落：当前阶缺失回落基础阶，不靠骨架占位。
void main() {
  group('petStageArtGeo 进化阶资源回落', () {
    test('三阶齐全种属取真实当前阶', () {
      // cat_ssr1 登记了 0/1/2 三阶
      expect(petStageArtGeo('cat_ssr1', 2)?.dir,
          'assets/pets/anim/cat/ssr/cat_ssr1/s2');
      expect(petStageArtGeo('cat_ssr1', 1)?.dir,
          'assets/pets/anim/cat/ssr/cat_ssr1/s1');
    });

    test('进化阶未登记回落基础阶（不返回 null）', () {
      // cat_n1 仅登记基础阶 0；进化到 1/2 阶但资源未产出时应回落 s0
      final geo = petStageArtGeo('cat_n1', 1);
      expect(geo, isNotNull);
      expect(geo?.dir, 'assets/pets/anim/cat/n/cat_n1/s0');
      // 进一步到 2 阶同样回落基础阶
      expect(petStageArtGeo('cat_n1', 2)?.dir,
          'assets/pets/anim/cat/n/cat_n1/s0');
    });

    test('基础阶自身直接命中', () {
      expect(petStageArtGeo('cat_n1', 0)?.dir,
          'assets/pets/anim/cat/n/cat_n1/s0');
    });

    test('种属完全未登记仍返回 null（骨架兜底）', () {
      // 不存在的种属：当前阶与基础阶都为 null，回落链到底
      expect(petStageArtGeo('no_such_pet', 1), isNull);
      expect(petStageArtGeo('no_such_pet', 0), isNull);
    });

    test('变体 code 回落同系基础 code（如 cat_n2_s1 → cat_n2）', () {
      // 进化/变体产出的 `cat_n2_s1` 未在 kPetBendGeo 登记，应逐段去后缀
      // 回落到基础 code `cat_n2` 取基础阶几何，不返回 null、不骨架
      final geo = petStageArtGeo('cat_n2_s1', 1);
      expect(geo, isNotNull);
      expect(geo?.dir, 'assets/pets/anim/cat/n/cat_n2/s0');
      expect(geo, same(petBendGeo('cat_n2', 0)));
      // 更深的后缀层层回落（cat_n2_s1_x → cat_n2_s1 → cat_n2）
      expect(petStageArtGeo('cat_n2_s1_x', 1)?.dir,
          'assets/pets/anim/cat/n/cat_n2/s0');
    });
  });
}
