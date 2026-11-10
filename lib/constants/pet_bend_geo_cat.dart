// 2D 分层弯曲·形态几何数据（猫系 10 只）：生成源与口径见 pet_bend.dart 文件头。
// 重新生成：node pet_anim_demo/tools/export_app_render.mjs

import 'pet_bend.dart';

/// 形态几何：外层键 = 种属 code，内层键 = 阶（与在架批次目录同名同序）
const Map<String, Map<int, PetBendGeo>> kPetBendGeoCat = {
  'cat_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/n/cat_n1/s0',
      side: 384,
      headTop: 87,
      foot: 383,
      pivotX: 169,
      yn: 288,
      eyeY: 189,
      eyeBox: Rect4(74, 183, 222, 240),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 煤球（N）
  'cat_n2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/n/cat_n2/s0',
      side: 384,
      headTop: 87,
      foot: 383,
      pivotX: 202,
      yn: 288,
      eyeY: 192,
      eyeBox: Rect4(108, 186, 233, 240),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 奶酪（N）
  'cat_n3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/n/cat_n3/s0',
      side: 384,
      headTop: 85,
      foot: 383,
      pivotX: 163,
      yn: 288,
      eyeY: 183,
      eyeBox: Rect4(78, 177, 209, 231),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 雾雾（N）
  'cat_n4': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/n/cat_n4/s0',
      side: 384,
      headTop: 85,
      foot: 383,
      pivotX: 169,
      yn: 288,
      eyeY: 189,
      eyeBox: Rect4(73, 183, 215, 239),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 虎斑仔（R）
  'cat_r1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/r/cat_r1/s0',
      side: 384,
      headTop: 91,
      foot: 383,
      pivotX: 166,
      yn: 290,
      eyeY: 199,
      eyeBox: Rect4(53, 193, 208, 241),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 三花（R）
  'cat_r2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/r/cat_r2/s0',
      side: 384,
      headTop: 84,
      foot: 383,
      pivotX: 187,
      yn: 287,
      eyeY: 193,
      eyeBox: Rect4(92, 187, 235, 239),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 蓝宝（R）
  'cat_r3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/r/cat_r3/s0',
      side: 384,
      headTop: 85,
      foot: 383,
      pivotX: 181,
      yn: 288,
      eyeY: 194,
      eyeBox: Rect4(90, 188, 225, 235),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 暹罗（SR）
  'cat_sr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/sr/cat_sr1/s0',
      side: 384,
      headTop: 85,
      foot: 383,
      pivotX: 178,
      yn: 288,
      eyeY: 207,
      eyeBox: Rect4(96, 201, 208, 239),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 狸花（SR）
  'cat_sr2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/sr/cat_sr2/s0',
      side: 384,
      headTop: 85,
      foot: 383,
      pivotX: 165,
      yn: 288,
      eyeY: 184,
      eyeBox: Rect4(73, 178, 202, 221),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 月萤（SSR）
  'cat_ssr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/cat/ssr/cat_ssr1/s0',
      side: 384,
      headTop: 86,
      foot: 383,
      pivotX: 128,
      yn: 288,
      eyeY: 176,
      eyeBox: Rect4(90, 170, 177, 200),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
    1: PetBendGeo(
      dir: 'assets/pets/anim/cat/ssr/cat_ssr1/s1',
      side: 384,
      headTop: 61,
      foot: 383,
      pivotX: 105,
      yn: 280,
      eyeY: 154,
      eyeBox: Rect4(60, 148, 157, 184),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.84
    2: PetBendGeo(
      dir: 'assets/pets/anim/cat/ssr/cat_ssr1/s2',
      side: 384,
      headTop: 0,
      foot: 383,
      pivotX: 103,
      yn: 260,
      eyeY: 63,
      eyeBox: Rect4(64, 57, 153, 98),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=1
  },
};
