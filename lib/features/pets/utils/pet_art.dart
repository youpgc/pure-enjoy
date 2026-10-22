/// 随包 2D 素材清单——「包里到底有没有这张图」的唯一权威。
///
/// - 一期素材全随包内置（不做线上资源包；3D 资源包懒加载已下线）；
/// - 因此新增一只宠物的表现 = 投素材 + 重生成下方清单 + 发版，后台 `render2d`
///   只能在「包里真有」的范围内选定（校验见 [pet_art_resolver.dart]）；
/// - ⚠️ cat_ssr1（月萤）的整只底图 `cat_ssr1_0N.png`（AI 出的 2048² 不透明
///   带背景图）已弃用删除：形象与舞台不一致（用户 20261021 拍板），清单改为
///   指向弯曲树中性帧 `anim/ssr/cat_ssr1/sN/c1_neutral.png`（按阶 s0/s1/s2,
///   与舞台同源同款）；待机透明帧 `frames/*_idle_N.png` 仍保留供动作轮播；
/// - **本清单只管「底图 + 整图帧序列」两条路**。分层弯曲用的 6 档表情帧在另一棵树
///   `assets/pets/anim/<评级>/<种属 code>/<阶 sN>/c*.png`，其目录与几何常量登记在
///   `lib/constants/pet_bend.dart`（生成源 `pet_anim_demo`，校验见
///   `tool/pet_asset_check.mjs` 的 checkBendTree），不吃 `render2d.frames`；
/// - 未登记的种属一律查不到图，调用方回退占位图标，不抛异常（铁律 8）。
library;

/// 两张清单表（键 = 种属 code）：
/// - [kPetStageArt]：各形态阶位的整只底图路径，下标即 stage；
/// - [kPetActionFrames]：动作 code → 已随包帧数；帧文件名契约
///   `assets/pets/frames/<species_code>_<action>_N.png`（N 从 1 起），
///   动作 code 值域见 `PetAction`（铁律 12 三处对齐的 App 端）。
///
/// 两表由 `tool/pet_asset_check.mjs --fix` 依据 `assets/pets` 目录实际文件
/// 重生成——投完素材跑一次即可，勿手改生成区块。
// BEGIN generated:pet-art
// cat_ssr1 的整只底图（cat_ssr1_01/02/03.png）已弃用删除（20261021）:
// 形象与舞台不一致,清单改指向弯曲树中性帧（与舞台同源同款,按阶 s0/s1/s2）
const Map<String, List<String>> kPetStageArt = {
  'cat_ssr1': [
    'assets/pets/anim/ssr/cat_ssr1/s0/c1_neutral.png',
    'assets/pets/anim/ssr/cat_ssr1/s1/c1_neutral.png',
    'assets/pets/anim/ssr/cat_ssr1/s2/c1_neutral.png',
  ],
};

const Map<String, Map<String, int>> kPetActionFrames = {
  'cat_ssr1': {'idle': 4},
};
// END generated:pet-art

/// 某个底图素材码（不含目录与扩展名）是否随包
bool petBaseArtBundled(String code) {
  final path = 'assets/pets/$code.png';
  return kPetStageArt.values.any((list) => list.contains(path));
}

/// 某种属某动作已随包的帧数；未登记返回 0
int petBundledFrameCount(String speciesCode, String actionCode) =>
    kPetActionFrames[speciesCode]?[actionCode] ?? 0;

/// 下采样解码宽度：按显示边长 × 设备像素比推算（多留 25% 给压扁拉伸与旋转）。
///
/// 底图是 2048² 的不透明图，整幅解码一张就 16MB，而 Flutter 默认图片缓存只有
/// 100MB——弹窗按 190/210 的显示高度原图解码纯属白烧内存。
int petDecodeWidth(double displayLogicalSize, double devicePixelRatio) =>
    (displayLogicalSize * devicePixelRatio * 1.25).round().clamp(128, 2048);
