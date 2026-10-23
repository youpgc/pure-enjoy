/// 随包 2D 素材工具——分层弯曲唯一表现通道下的解码参数。
///
/// - 整只底图（`assets/pets/<code>.png`）与整图帧序列（`assets/pets/frames/`）
///   两条路已下线，素材与清单表全部移除；`pet_species.render2d` 的
///   `base`/`frames` 键不再被 App 消费（数据仍可在服务端保留）；
/// - 宠物表现唯一来源 = 分层弯曲树 `assets/pets/anim/<系>/<评级>/<code>/<阶>/`，
///   目录与几何常量登记在 `lib/constants/pet_bend.dart`（校验见
///   `tool/pet_asset_check.mjs` 的 checkBendTree）；
/// - 未登记的种属查不到图，调用方回退占位图标，不抛异常（铁律 8）。
library;

/// 下采样解码宽度：按显示边长 × 设备像素比推算（多留 25% 给压扁拉伸与旋转）。
///
/// 大图整幅解码一张就吃掉数十 MB，而 Flutter 默认图片缓存只有 100MB——
/// 弹窗按 190/210 的显示高度原图解码纯属白烧内存。
int petDecodeWidth(double displayLogicalSize, double devicePixelRatio) =>
    (displayLogicalSize * devicePixelRatio * 1.25).round().clamp(128, 2048);
