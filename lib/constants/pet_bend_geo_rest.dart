// 2D 分层弯曲·形态几何数据（犬/鼠/兔系）：生成源与口径见 pet_bend.dart 文件头。
// 重新生成：node pet_anim_demo/tools/export_app_render.mjs

import 'pet_bend.dart';

const Map<String, Map<int, PetBendGeo>> kPetBendGeoRest = {
  // 豆豆（N）
  'dog_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/n/dog_n1/s0',
      side: 384,
      headTop: 84,
      foot: 383,
      pivotX: 121,
      yn: 287,
      eyeY: 189,
      eyeBox: Rect4(79, 183, 171, 223),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 汤圆（N）
  'dog_n2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/n/dog_n2/s0',
      side: 384,
      headTop: 120,
      foot: 383,
      pivotX: 159,
      yn: 299,
      eyeY: 219,
      eyeBox: Rect4(111, 213, 209, 254),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.6864
  },
  // 阿黄（N）
  'dog_n3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/n/dog_n3/s0',
      side: 384,
      headTop: 99,
      foot: 383,
      pivotX: 128,
      yn: 292,
      eyeY: 200,
      eyeBox: Rect4(84, 194, 181, 236),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.741
  },
  // 小灰（N）
  'dog_n4': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/n/dog_n4/s0',
      side: 384,
      headTop: 129,
      foot: 383,
      pivotX: 119,
      yn: 302,
      eyeY: 200,
      eyeBox: Rect4(77, 194, 177, 238),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.663
  },
  // 哈奇（R）
  'dog_r1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/r/dog_r1/s0',
      side: 384,
      headTop: 84,
      foot: 383,
      pivotX: 112,
      yn: 287,
      eyeY: 201,
      eyeBox: Rect4(66, 195, 166, 242),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 卷卷（R）
  'dog_r2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/r/dog_r2/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 142,
      yn: 297,
      eyeY: 192,
      eyeBox: Rect4(107, 186, 182, 219),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 柴柴（R）
  'dog_r3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/r/dog_r3/s0',
      side: 384,
      headTop: 108,
      foot: 383,
      pivotX: 130,
      yn: 295,
      eyeY: 212,
      eyeBox: Rect4(82, 206, 184, 246),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.7176
  },
  // 金金（SR）
  'dog_sr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/sr/dog_sr1/s0',
      side: 384,
      headTop: 84,
      foot: 383,
      pivotX: 125,
      yn: 287,
      eyeY: 168,
      eyeBox: Rect4(76, 162, 181, 201),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 墨墨（SR）
  'dog_sr2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/sr/dog_sr2/s0',
      side: 384,
      headTop: 96,
      foot: 383,
      pivotX: 127,
      yn: 291,
      eyeY: 170,
      eyeBox: Rect4(86, 164, 172, 202),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.7488
  },
  // 哮天（SSR）
  'dog_ssr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/dog/ssr/dog_ssr1/s0',
      side: 384,
      headTop: 84,
      foot: 383,
      pivotX: 130,
      yn: 287,
      eyeY: 165,
      eyeBox: Rect4(86, 159, 182, 196),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.78
  },
  // 布丁（N）
  'mouse_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/n/mouse_n1/s0',
      side: 384,
      headTop: 168,
      foot: 383,
      pivotX: 138,
      yn: 314,
      eyeY: 234,
      eyeBox: Rect4(101, 228, 185, 271),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5616
  },
  // 米粒（N）
  'mouse_n2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/n/mouse_n2/s0',
      side: 384,
      headTop: 168,
      foot: 383,
      pivotX: 159,
      yn: 314,
      eyeY: 246,
      eyeBox: Rect4(116, 240, 207, 279),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5616
  },
  // 雪球（N）
  'mouse_n3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/n/mouse_n3/s0',
      side: 384,
      headTop: 168,
      foot: 383,
      pivotX: 166,
      yn: 314,
      eyeY: 243,
      eyeBox: Rect4(127, 237, 208, 269),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5616
  },
  // 芝麻（N）
  'mouse_n4': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/n/mouse_n4/s0',
      side: 384,
      headTop: 168,
      foot: 383,
      pivotX: 156,
      yn: 314,
      eyeY: 236,
      eyeBox: Rect4(107, 230, 212, 275),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5616
  },
  // 金熊（R）
  'mouse_r1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/r/mouse_r1/s0',
      side: 384,
      headTop: 156,
      foot: 383,
      pivotX: 158,
      yn: 310,
      eyeY: 227,
      eyeBox: Rect4(111, 221, 210, 265),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5928
  },
  // 花枝（R）
  'mouse_r2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/r/mouse_r2/s0',
      side: 384,
      headTop: 144,
      foot: 383,
      pivotX: 145,
      yn: 307,
      eyeY: 222,
      eyeBox: Rect4(100, 216, 193, 258),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.624
  },
  // 栗子（R）
  'mouse_r3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/r/mouse_r3/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 139,
      yn: 297,
      eyeY: 176,
      eyeBox: Rect4(97, 170, 186, 216),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 奶茶（SR）
  'mouse_sr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/sr/mouse_sr1/s0',
      side: 384,
      headTop: 168,
      foot: 383,
      pivotX: 150,
      yn: 314,
      eyeY: 237,
      eyeBox: Rect4(112, 231, 193, 276),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.5616
  },
  // 翼翼（SR）
  'mouse_sr2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/sr/mouse_sr2/s0',
      side: 384,
      headTop: 144,
      foot: 383,
      pivotX: 144,
      yn: 307,
      eyeY: 201,
      eyeBox: Rect4(95, 195, 198, 239),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.624
  },
  // 松灵（SSR）
  'mouse_ssr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/mouse/ssr/mouse_ssr1/s0',
      side: 384,
      headTop: 144,
      foot: 383,
      pivotX: 137,
      yn: 307,
      eyeY: 199,
      eyeBox: Rect4(98, 193, 177, 230),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.624
  },
  // 糯米（N）
  'rabbit_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/n/rabbit_n1/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 136,
      yn: 297,
      eyeY: 242,
      eyeBox: Rect4(92, 236, 190, 280),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 灰豆（N）
  'rabbit_n2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/n/rabbit_n2/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 128,
      yn: 297,
      eyeY: 229,
      eyeBox: Rect4(77, 223, 188, 278),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 花卷（N）
  'rabbit_n3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/n/rabbit_n3/s0',
      side: 384,
      headTop: 138,
      foot: 383,
      pivotX: 152,
      yn: 305,
      eyeY: 212,
      eyeBox: Rect4(101, 206, 216, 256),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.6396
  },
  // 蹦蹦（N）
  'rabbit_n4': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/n/rabbit_n4/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 118,
      yn: 297,
      eyeY: 253,
      eyeBox: Rect4(75, 247, 169, 287),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 公主（R）
  'rabbit_r1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/r/rabbit_r1/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 165,
      yn: 297,
      eyeY: 213,
      eyeBox: Rect4(118, 207, 218, 245),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 豆丁（R）
  'rabbit_r2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/r/rabbit_r2/s0',
      side: 384,
      headTop: 138,
      foot: 383,
      pivotX: 163,
      yn: 305,
      eyeY: 234,
      eyeBox: Rect4(114, 228, 217, 271),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.6396
  },
  // 绒绒（R）
  'rabbit_r3': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/r/rabbit_r3/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 155,
      yn: 297,
      eyeY: 228,
      eyeBox: Rect4(104, 222, 210, 267),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 银狐（SR）
  'rabbit_sr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/sr/rabbit_sr1/s0',
      side: 384,
      headTop: 99,
      foot: 383,
      pivotX: 150,
      yn: 292,
      eyeY: 214,
      eyeBox: Rect4(101, 208, 202, 247),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.741
  },
  // 岚岚（SR）
  'rabbit_sr2': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/sr/rabbit_sr2/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 169,
      yn: 297,
      eyeY: 187,
      eyeBox: Rect4(116, 181, 230, 231),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
  // 玉兔（SSR）
  'rabbit_ssr1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/rabbit/ssr/rabbit_ssr1/s0',
      side: 384,
      headTop: 114,
      foot: 383,
      pivotX: 158,
      yn: 297,
      eyeY: 221,
      eyeBox: Rect4(117, 215, 205, 248),
      droopRamp: 0.25,
      droopRampMin: 40,
    ), // fill=0.702
  },
};
