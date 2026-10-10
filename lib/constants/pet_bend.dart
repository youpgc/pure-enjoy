/// 2D 分层弯曲的**渲染契约**（唯一数据源，勿手改、勿在别处再抄一份）
///
/// 生成源：`pet_anim_demo/idle_rig_action_defs.mjs`（8 动作编排表，用户已验收冻结）
///       ＋ `pet_anim_demo/batch/<种属>/<种属>.rig.json` 的 `rig` 块（每形态的 384 栅格几何常量）
/// 重新生成：`node pet_anim_demo/tools/export_app_render.mjs`
///
/// 口径来源（不看代码先看这两处）：
/// - 需求文档 §11.3 标准动作集 8 个；《3D 展现与交互实现方案》§2.1 触发矩阵（与渲染栈无关，2D 沿用）；
/// - 《宠物系统2D动画量产规范》§「形象修正四档」与门禁 G0~G9。
///
/// 三条硬约束（随编排表一起冻结，改任何数值都要回样片复跑门禁）：
/// 1. |θ| ≤ 1°（超过会撞上「旋转后整行竖向采样窗口 ≈ 局部角 × 384px」的共振，额头那条横向亮带会被捞成白线）；
/// 2. 表情档之间**一律硬切**，不做交叉溶解（AI 帧间 RGB 差异铺满 15~19% 画面，混合必全身重影）；
/// 3. 归零线 [PetBendGeo.yn] 以下真·不动（旋转场 [wR] 与低垂场 [wA] 都归零到那条线）。
///
/// 单位：px 与度都在 **side=384 的生产栅格**上定义，渲染前按实际显示边长等比换算；
/// dy 向下为正，sx/sy 是以脚底中心为原点的倍率，[a] 是头部竖向低垂量（px）。
library;

/// 一个形态的 384 栅格几何常量（装配期实测，逐只不同）
class PetBendGeo {
  const PetBendGeo({
    required this.dir,
    required this.side,
    required this.headTop,
    required this.foot,
    required this.pivotX,
    required this.yn,
    required this.eyeY,
    required this.eyeBox,
    required this.droopRamp,
    required this.droopRampMin,
  });

  /// 随包帧档目录（层级＝评级/种属/阶，由导出脚本按实际落盘位置写死，客户端不拼路径）
  final String dir;

  final int side;

  /// 头顶行（旋转渐变带的上端）
  final int headTop;

  /// 脚底行（缩放原点，装配期钉在这里）
  final int foot;

  /// 支点 x（横向居中的参照）
  final int pivotX;

  /// 归零线 y：线以下逐像素不动
  final int yn;

  final int eyeY;

  /// 眼区 bbox（x0,y0,x1,y1）：道具层与食物的扫掠区都不许进来
  final Rect4 eyeBox;

  /// 低垂斜坡占移动区的比例（上段平台、下段收到 0）
  final double droopRamp;

  /// 斜坡长度下限（归零线被调试值拖小时不能趋零，趋零=线上一个硬断口）
  final double droopRampMin;

  /// 旋转权重场：头顶 1 → 归零线 0，整段 smoothstep（头部不能是平台，否则额头局部角=θ 撞共振）
  double wR(double y) => _smoothstep((yn - (y + 0.5)) / (yn - headTop));

  /// 低垂权重场：平台 + 缓降（竖向场的行仍水平 ⇒ 不产生亮线，平台是安全的）
  double wA(double y) => _smoothstep(
      (yn - y) / (droopRamp * (yn - headTop) > droopRampMin
          ? droopRamp * (yn - headTop)
          : droopRampMin));
}

class Rect4 {
  const Rect4(this.x0, this.y0, this.x1, this.y1);
  final double x0;
  final double y0;
  final double x1;
  final double y1;
}

/// 呼吸叠加：幅度 %（脚底原点）与周期秒
class PetBreath {
  const PetBreath(this.amp, this.per);
  final double amp;
  final double per;
}

/// 一条通道的关键帧：`[[相位 0~1, 值], ...]`，段内 smoothstep，两端留平
typedef PetKeys = List<List<double>>?;

/// 一个动作的完整编排（关键帧逐字转录自冻结件，含未写通道 = null）
class PetActDef {
  const PetActDef({
    required this.key,
    required this.per,
    required this.loop,
    required this.reveal,
    required this.expr,
    required this.th,
    required this.a,
    required this.dx,
    required this.dy,
    required this.sx,
    required this.sy,
    required this.glow,
    required this.breath,
  });

  final String key;

  /// 一轮时长（秒）——由"这个动作要演几个拍子、每拍多长才读得清"倒推
  final double per;

  /// 环境态：整周期接缝每通道必须回到首值
  final bool loop;

  /// 末段切形态（进化演出）
  final bool reveal;

  final PetKeys expr;
  final PetKeys th;
  final PetKeys a;
  final PetKeys dx;
  final PetKeys dy;
  final PetKeys sx;
  final PetKeys sy;
  final PetKeys glow;
  final PetBreath? breath;
}

const double kPetBendSide = 384;

/// 表情档文件名（下标 = 编排 expr 通道的取值）
///
/// 冻结件里还有第 7 档 `s2_reveal`（进化顶点换的派生帧），它**没进在架批次**：
/// 那是形象四档修正之前从缩前 c1 程序化画的（还带额前独角），不能上 App。
/// 进化末段的形态替换改由「切到目标阶的 c1_neutral」承担，故本表只登记 6 档。
const List<String> kPetBendFrameFiles = [
  'c1_neutral',
  'c2_ear',
  'c3_lid_half',
  'c4_lid_closed',
  'c5_look_down',
  'c6_wide',
];

/// 嘴与眼区的通用锚点（生产端实测值；逐只实测尚未进管线，缺 per-form 口径时沿用）
const Rect4 kPetBendEyeBox = Rect4(55, 134, 229, 208);
const List<double> kPetBendMouth = [136, 216];

/// 形态几何：外层键 = 种属 code，内层键 = 阶（与在架批次目录同名同序）
const Map<String, Map<int, PetBendGeo>> kPetBendGeo = {
  // 团子（N）
  'cat_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/n/cat_n1/s0',
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
      dir: 'assets/pets/anim/n/cat_n2/s0',
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
      dir: 'assets/pets/anim/n/cat_n3/s0',
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
      dir: 'assets/pets/anim/n/cat_n4/s0',
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
      dir: 'assets/pets/anim/r/cat_r1/s0',
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
      dir: 'assets/pets/anim/r/cat_r2/s0',
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
      dir: 'assets/pets/anim/r/cat_r3/s0',
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
      dir: 'assets/pets/anim/sr/cat_sr1/s0',
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
      dir: 'assets/pets/anim/sr/cat_sr2/s0',
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
      dir: 'assets/pets/anim/ssr/cat_ssr1/s0',
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
      dir: 'assets/pets/anim/ssr/cat_ssr1/s1',
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
      dir: 'assets/pets/anim/ssr/cat_ssr1/s2',
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
  // 豆豆（N）
  'dog_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/n/dog_n1/s0',
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
      dir: 'assets/pets/anim/n/dog_n2/s0',
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
      dir: 'assets/pets/anim/n/dog_n3/s0',
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
      dir: 'assets/pets/anim/n/dog_n4/s0',
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
      dir: 'assets/pets/anim/r/dog_r1/s0',
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
      dir: 'assets/pets/anim/r/dog_r2/s0',
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
      dir: 'assets/pets/anim/r/dog_r3/s0',
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
      dir: 'assets/pets/anim/sr/dog_sr1/s0',
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
      dir: 'assets/pets/anim/sr/dog_sr2/s0',
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
  // 布丁（N）
  'mouse_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/n/mouse_n1/s0',
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
  // 糯米（N）
  'rabbit_n1': {
    0: PetBendGeo(
      dir: 'assets/pets/anim/n/rabbit_n1/s0',
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
};

/// 8 标准动作编排
const Map<String, PetActDef> kPetBendActs = {
  'idle': PetActDef(
    key: 'idle',
    per: 3.4,
    loop: true,
    reveal: false,
    expr: [[0, 0], [0.63, 2], [0.65, 3], [0.68, 2], [0.7, 0]],
    th: [[0, 0], [0.28, 0], [0.33, 0.6], [0.37, 1], [0.44, -0.4], [0.52, 0], [1, 0]],
    a: null,
    dx: null,
    dy: null,
    sx: null,
    sy: null,
    glow: null,
    breath: PetBreath(0.6, 2.6),
  ),
  'eat': PetActDef(
    key: 'eat',
    per: 5,
    loop: false,
    reveal: false,
    expr: [[0, 0], [0.036, 7], [0.074, 8], [0.112, 9], [0.15, 10], [0.206, 9], [0.238, 8], [0.27, 7], [0.302, 0], [0.352, 7], [0.39, 8], [0.428, 9], [0.466, 10], [0.522, 9], [0.554, 8], [0.586, 7], [0.618, 0], [0.668, 7], [0.706, 8], [0.744, 9], [0.782, 10], [0.838, 9], [0.87, 8], [0.902, 7], [0.934, 0]],
    th: [[0, 0]],
    a: [[0, 0]],
    dx: null,
    dy: null,
    sx: null,
    sy: null,
    glow: null,
    breath: null,
  ),
  'petted': PetActDef(
    key: 'petted',
    per: 1.9,
    loop: false,
    reveal: false,
    expr: [[0, 2]],
    th: [[0, 0], [0.3, 0.55], [0.62, -0.4], [1, 0]],
    a: [[0, 0], [0.3, 11], [0.62, 8], [1, 0]],
    dx: null,
    dy: [[0, 0], [0.4, 1.5], [1, 0]],
    sx: null,
    sy: [[0, 1], [0.4, 0.99], [1, 1]],
    glow: null,
    breath: null,
  ),
  'happy': PetActDef(
    key: 'happy',
    per: 1.1,
    loop: false,
    reveal: false,
    expr: [[0, 0], [0.12, 5], [0.9, 0]],
    th: [[0, 0], [0.4, 0.4], [0.62, -0.3], [1, 0]],
    a: null,
    dx: null,
    dy: [[0, 0], [0.1, 0], [0.35, -24], [0.5, -26], [0.66, -14], [0.86, 0], [1, 0]],
    sx: [[0, 1], [0.06, 1.07], [0.16, 1], [0.74, 1], [0.86, 1.07], [0.96, 1], [1, 1]],
    sy: [[0, 1], [0.06, 0.93], [0.16, 1], [0.74, 1], [0.86, 0.93], [0.96, 1], [1, 1]],
    glow: null,
    breath: null,
  ),
  'sad': PetActDef(
    key: 'sad',
    per: 3.6,
    loop: false,
    reveal: false,
    expr: [[0, 4]],
    th: [[0, -0.3], [0.5, -0.5], [1, -0.3]],
    a: [[0, 0], [0.28, 13], [0.62, 11], [0.84, 12], [1, 0]],
    dx: null,
    dy: [[0, 0], [0.28, 5], [0.62, 4], [0.84, 5], [1, 0]],
    sx: null,
    sy: [[0, 0.978], [0.5, 0.972], [1, 0.978]],
    glow: null,
    breath: PetBreath(0.3, 3.2),
  ),
  'sleep': PetActDef(
    key: 'sleep',
    per: 6,
    loop: true,
    reveal: false,
    expr: [[0, 3]],
    th: [[0, 0.3], [0.5, -0.25], [1, 0.3]],
    a: [[0, 8], [0.5, 12], [1, 8]],
    dx: null,
    dy: [[0, 6], [0.5, 7.5], [1, 6]],
    sx: null,
    sy: null,
    glow: null,
    breath: PetBreath(1, 3),
  ),
  'walk': PetActDef(
    key: 'walk',
    per: 3.2,
    loop: true,
    reveal: false,
    expr: [[0, 0], [0.46, 1], [0.56, 0]],
    th: [[0, 0], [0.125, 0.7], [0.375, -0.7], [0.625, 0.7], [0.875, -0.7], [1, 0]],
    a: [[0, 3], [0.125, 0], [0.25, 3], [0.375, 0], [0.5, 3], [0.625, 0], [0.75, 3], [0.875, 0], [1, 3]],
    dx: [[0, -32], [0.5, 32], [1, -32]],
    dy: [[0, 0], [0.125, -3.5], [0.25, 0], [0.375, -3.5], [0.5, 0], [0.625, -3.5], [0.75, 0], [0.875, -3.5], [1, 0]],
    sx: null,
    sy: null,
    glow: null,
    breath: PetBreath(0.4, 1.6),
  ),
  'evolve': PetActDef(
    key: 'evolve',
    per: 6.8,
    loop: false,
    reveal: true,
    expr: [[0, 0], [0.3, 5], [0.588, 6]],
    th: [[0, 0], [0.132, 0.2], [0.2, -0.2], [0.279, 0.3], [0.346, -0.3], [0.426, 0.5], [0.48, -0.5], [0.5, 0.7], [0.55, -0.7], [0.588, 0.4], [0.7, -0.15], [0.85, 0.05], [1, 0]],
    a: [[0, 0], [0.118, 9], [0.191, 2], [0.346, 5], [0.5, -2], [0.588, -7], [0.75, -1], [1, 0]],
    dx: null,
    dy: [[0, 0], [0.118, 5], [0.16, 0], [0.191, -14], [0.279, -6], [0.346, -22], [0.426, -8], [0.5, -30], [0.588, -34], [0.669, -18], [0.72, 2], [0.779, -3], [0.868, 0], [1, 0]],
    sx: [[0, 1], [0.118, 1.03], [0.16, 1], [0.191, 1.03], [0.279, 1.005], [0.346, 1.045], [0.426, 1.01], [0.5, 1.06], [0.588, 1.06], [0.669, 1.02], [0.72, 1.03], [0.779, 0.99], [0.868, 1], [1, 1]],
    sy: [[0, 1], [0.118, 0.975], [0.16, 1], [0.191, 1.03], [0.279, 1.005], [0.346, 1.045], [0.426, 1.01], [0.5, 1.06], [0.588, 1.06], [0.669, 1.02], [0.72, 0.97], [0.779, 1.015], [0.868, 1], [1, 1]],
    glow: [[0, 0], [0.118, 0.12], [0.279, 0.22], [0.426, 0.34], [0.5, 0.7], [0.588, 1], [0.72, 0.42], [0.86, 0.1], [1, 0]],
    breath: null,
  ),
};

double _smoothstep(double u) =>
    u >= 1 ? 1 : u <= 0 ? 0 : u * u * (3 - 2 * u);
