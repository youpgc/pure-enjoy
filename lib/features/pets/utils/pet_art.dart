/// 本地 2D 立绘注册表（随包资产，按 speciesCode + stage 解析）
///
/// - 分层定版：2D 立绘随包内置（<5MB），3D 模型线上资源包按系懒加载；
/// - 未登记的种属返回 null，调用方回退占位图标，不抛异常；
/// - cat_ssr1（月萤）三阶素材对应：_01=基础形(stage0) / _02=一阶(stage1) /
///   _03=二阶(stage2)，与进阶图 yueying.png 左→右顺序一致；
/// - AI 生成的 3D 底模未经重拓扑/绑定/动画，不投入正式渲染（红线 18），
///   仅 POC 工作台使用。
const Map<String, List<String>> _kPetStageArt = {
  'cat_ssr1': [
    'assets/pets/cat_ssr1_01.png',
    'assets/pets/cat_ssr1_02.png',
    'assets/pets/cat_ssr1_03.png',
  ],
};

/// 解析种属在某形态阶位的 2D 立绘资产路径；未登记或阶位越界返回 null
String? petStageArtAsset(String speciesCode, int stage) {
  final arts = _kPetStageArt[speciesCode];
  if (arts == null || stage < 0 || stage >= arts.length) return null;
  return arts[stage];
}

/// gif 式帧动画帧序列注册表（同形态多帧轮播，按基础形 speciesCode 登记）
///
/// - 帧源：assets/pets/frames/<code>_idle_N.png（程序合成：眨眼 + 尾摆，
///   白底融为柔光月晕边缘，与浅色/深色页面背景均可融合）；
/// - 未登记种属返回空列表，调用方回退单帧立绘（petStageArtAsset）；
/// - 目前仅月萤基础形登记；一阶/二阶沿用单帧静态展示。
const Map<String, List<String>> _kPetIdleFrames = {
  'cat_ssr1': [
    'assets/pets/frames/cat_ssr1_idle_1.png',
    'assets/pets/frames/cat_ssr1_idle_2.png',
    'assets/pets/frames/cat_ssr1_idle_3.png',
    'assets/pets/frames/cat_ssr1_idle_4.png',
  ],
};

/// 解析种属的 idle 帧序列；未登记返回空列表（回退单帧静态）
List<String> petIdleFrames(String speciesCode) =>
    _kPetIdleFrames[speciesCode] ?? const <String>[];

/// 诞生/进化弹窗配图：优先帧序列首帧，未登记回退静态立绘，两者皆无返回 null
String? petBirthArt(String speciesCode) {
  final frames = petIdleFrames(speciesCode);
  if (frames.isNotEmpty) return frames.first;
  return petStageArtAsset(speciesCode, 0);
}
