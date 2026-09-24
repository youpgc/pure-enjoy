/// 随包 2D 素材清单——「包里到底有没有这张图」的唯一权威。
///
/// - 一期素材全随包内置（<5MB，不做线上资源包；3D 资源包懒加载已下线）；
/// - 因此新增一只宠物的表现 = 投素材 + 重生成下方清单 + 发版，后台 `render2d`
///   只能在「包里真有」的范围内选定（校验见 [pet_art_resolver.dart]）；
/// - cat_ssr1（月萤）三阶：`_01`=基础形(stage0) / `_02`=一阶(stage1) /
///   `_03`=二阶(stage2)，与进阶图 yueying.png 左→右顺序一致；
/// - 底图 `cat_ssr1_0N.png` 是 AI 出的 2048² 不透明图（带背景），
///   `frames/*_idle_N.png` 才是抠好底的透明帧——舞台优先用后者当身体，
///   别直接拿底图做动作，否则动作期间会闪出方框背景；
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
const Map<String, List<String>> kPetStageArt = {
  'cat_ssr1': [
    'assets/pets/cat_ssr1_01.png',
    'assets/pets/cat_ssr1_02.png',
    'assets/pets/cat_ssr1_03.png',
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
