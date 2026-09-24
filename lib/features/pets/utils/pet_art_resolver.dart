/// 2D 素材解析器：后台 `pet_species.render2d` 叠在随包清单之上的唯一取图出口。
///
/// 所有立绘消费点（主页舞台、诞生弹窗、进化弹窗、孵蛋页）一律走这里，
/// 不再各自拼路径——目录结构调整时只改本文件。
///
/// ## `pet_species.render2d` 契约（v1）
///
/// jsonb，**只存素材码与帧数，不存路径**（路径规则归本文件所有）：
///
/// ```jsonc
/// {
///   "base": "cat_ssr1_02",     // 整只底图素材码 -> assets/pets/<code>.png
///   "frames": { "idle": 4 }    // 动作 code -> 帧数
///                              // -> assets/pets/frames/<species_code>_<action>_N.png，N 从 1 起
/// }
/// ```
///
/// 键就这两个。分层部件（parts/pivots）、抚摸热区（hotspots）、场景（scene）
/// 等要等对应表现真落地再加：写了没人消费的键，后台就成了「填了没效果」的
/// 死配置（3D 那批死字段就是这么清出去的）。
///
/// 动作 code 的合法值域 = `PetAction.code`（铁律 12 三处对齐的 App 端）；
/// 未知键与未知动作一律忽略，不当成错误。
///
/// ## 回退链（铁律 8：配置缺码 / 素材未随包一律不崩溃）
///
/// `render2d` 指定值 → 随包清单（`pet_art.dart`）→ null（调用方画占位图标）。
///
/// 后台填了未随包的素材码/超额的帧数时按随包结果裁剪，而不是照着配置去加载
/// 不存在的文件——一期素材全随包，加素材必然发版，配置无权凭空造资源。
library;

import '../../../constants/pet_render.dart';
import 'pet_art.dart';

/// 整只底图：`render2d.base` 优先，未配置或未随包则回退该种属该阶位的清单底图。
///
/// 注意底图是不透明图（带背景），舞台上请用 [petStageFrames] 取透明帧做身体，
/// 只有无帧素材的种属才直接拿底图演动作。
String? petBaseArt(String speciesCode, int stage,
    {Map<String, dynamic>? render2d}) {
  final code = render2d?['base'];
  if (code is String && code.isNotEmpty && petBaseArtBundled(code)) {
    return 'assets/pets/$code.png';
  }
  final arts = kPetStageArt[speciesCode];
  if (arts == null || stage < 0 || stage >= arts.length) return null;
  return arts[stage];
}

/// 某动作配置的真帧序列；未配置该动作或无真帧返回空列表（走程序补间）
List<String> petActionFrames(String speciesCode, PetAction action,
    {Map<String, dynamic>? render2d}) {
  final bundled = petBundledFrameCount(speciesCode, action.code);
  if (bundled <= 0) return const <String>[];
  final raw = render2d?['frames'];
  final configured = raw is Map ? raw[action.code] : null;
  // 未配置 = 随包帧全放；配了 = 按配置裁剪，但不许超出包里真有的帧数
  var count = configured is num ? configured.toInt() : bundled;
  if (count < 1) count = 1;
  if (count > bundled) count = bundled;
  return List<String>.generate(
    count,
    (i) => 'assets/pets/frames/${speciesCode}_${action.code}_${i + 1}.png',
  );
}

/// 舞台身体帧序列：该动作有真帧用该动作的，否则沿用 idle 帧当身体。
///
/// 之所以不能「无真帧就退回底图」：idle 帧是抠好底的透明图，底图带背景，
/// 动作期间换底图会闪出方框背景。透明身体 + 程序补间才是这套 puppet 的前提。
List<String> petStageFrames(String speciesCode, PetAction action,
    {Map<String, dynamic>? render2d}) {
  final own = petActionFrames(speciesCode, action, render2d: render2d);
  if (own.isNotEmpty || action == PetAction.idle) return own;
  return petActionFrames(speciesCode, PetAction.idle, render2d: render2d);
}

/// 弹窗/列表用单帧形象：优先 idle 首帧（透明底），回退底图，皆无返回 null
String? petPortraitArt(String speciesCode, {Map<String, dynamic>? render2d}) {
  final frames =
      petActionFrames(speciesCode, PetAction.idle, render2d: render2d);
  if (frames.isNotEmpty) return frames.first;
  return petBaseArt(speciesCode, 0, render2d: render2d);
}
