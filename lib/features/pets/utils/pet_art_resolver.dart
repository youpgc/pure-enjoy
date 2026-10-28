/// 2D 素材解析器：宠物表现的唯一取图出口。
///
/// 所有立绘消费点（主页舞台、诞生弹窗、进化弹窗、孵蛋页、图鉴）一律走这里，
/// 不再各自拼路径——目录结构调整时只改本文件。
///
/// ## 现行契约：分层弯曲唯一
///
/// 整只底图与整图帧序列两条路已下线（素材随包移除），`pet_species.render2d`
/// 的 `base`/`frames` 键不再被 App 消费——服务端仍可携带该块，解析时整体忽略。
/// 要不要弯曲由 `kPetBendGeo` 是否登记决定，配置无权凭空造资源。
///
/// ## 回退链（铁律 8：配置缺码 / 素材未随包一律不崩溃）
///
/// 弯曲树登记 → 中性帧路径 → null（调用方画占位图标）。
library;

import '../../../constants/pet_bend.dart';

// 消费方只 import 本文件：解码宽度算法在此统一，避免各处各写一份 1.25 倍余量
export 'pet_art.dart' show petDecodeWidth;
export '../../../constants/pet_bend.dart' show PetBendGeo;

/// 分层弯曲的形态几何；查不到 = 该形态没有弯曲素材，调用方走占位。
///
/// 弯曲用的 6 档表情帧是**结构性**素材（编排 `expr` 通道按下标点名，缺任一档
/// 就会在切档瞬间闪透明），目录与几何由 `lib/constants/pet_bend.dart` 统一登记。
PetBendGeo? petBendGeo(String speciesCode, int stage) =>
    kPetBendGeo[speciesCode]?[stage];

/// 进化末段切到的目标阶目录；无下一阶返回 null（播放器停在当前帧档不越界）
String? petBendRevealDir(String speciesCode, int stage) =>
    kPetBendGeo[speciesCode]?[stage + 1]?.dir;

/// 种属骨架占位图（assets/pets/placeholders/<系>_s<阶>.png，20261028）：
/// 系 = species_code 首段（cat/dog/rabbit/mouse）；阶 0~2 钳位；
/// 资源缺失由调用方 errorBuilder 回退图标。
String petPlaceholderArt(String speciesCode, int stage) {
  final family = speciesCode.split('_').isEmpty
      ? 'cat'
      : speciesCode.split('_').first;
  final st = stage.clamp(0, 2);
  return 'assets/pets/placeholders/${family}_s$st.png';
}

/// 单帧立绘（弹窗/列表缩略）：弯曲树中性帧 `c1_neutral`，与舞台形象同源同款；
/// 未登记形态返回系骨架占位图（20261028，四系三阶轮廓）。
String? petBaseArt(String speciesCode, int stage) {
  final dir = petBendGeo(speciesCode, stage)?.dir;
  if (dir != null) return '$dir/c1_neutral.png';
  return petPlaceholderArt(speciesCode, stage);
}

/// 弹窗/列表通用形象：基础阶中性帧（[petBaseArt] 的 stage=0 简写）
String? petPortraitArt(String speciesCode) => petBaseArt(speciesCode, 0);
