/// 宠物**表现层**契约（与渲染栈无关的动作命名）
///
/// 从 [pet.dart] 拆出（2026-09-24）：`pet.dart` 承载的是与 Supabase DDL check
/// 对齐的**数据库键域**（铁律 12 三端对齐），本文件承载的是**客户端表现契约**，
/// 不入库、不参与任何数值判定。两组值域不同源，故分文件登记。
library;

/// 宠物 2D 动作契约（2026-10-08 定版修订：核心 5 + 氛围 1，见需求 §11.3）
///
/// **核心动作集（5）**：idle（常驻载体，六帧基座）｜eat（喂养反馈，**唯一真帧
/// 例外**——食物层交互）｜petted（高频互动反馈，正向单槽位）｜sad（低状态
/// 环境态，接历险出发阈值）｜evolve（里程碑演出：程序特效 + s2_reveal 帧）。
/// **氛围增强（1）**：sleep（夜间/久无操作环境态，待 pet_config 阈值接线启用）。
///
/// 口径修订记录：`happy` 已并入 petted（正向反馈单槽位，触发点改播 petted）；
/// `walk` 已移出定版集（无真实交互场景，且逐行弯曲表达不了腿部位移）。
/// 两枚举值**保留**：素材文件命名（`<species>_<action>_N.png`）与既有关卡
/// switch 依赖它们，App 内不再触发。
///
/// 三条用途，新增/改名动作必须三处同批（铁律 12）：
/// 1. App 动作仲裁与补间编排（`utils/pet_action_machine.dart`
///    + `widgets/pet_living_art.dart`）；
/// 2. `pet_species.render2d` 的 `frames` 键（该动作有真帧才走帧序列，
///    无帧走程序补间；契约与取图见 `utils/pet_art_resolver.dart`）；
/// 3. 素材文件名（`assets/pets/frames/<species_code>_<action>_N.png`）。
enum PetAction {
  idle('idle', '待机', 0),
  walk('walk', '行走（已移出定版集，值保留兼容）', 1),
  sleep('sleep', '睡觉（氛围增强）', 2),
  sad('sad', '委屈（低状态环境态）', 3),
  happy('happy', '开心（已并入 petted，值保留兼容）', 4),
  petted('petted', '被抚摸', 5),
  eat('eat', '进食', 6),
  evolve('evolve', '进化演出', 7);

  const PetAction(this.code, this.label, this.priority);

  final String code;
  final String label;

  /// 仲裁优先级：大的打断小的；[PetAction.evolve] 最高且独占（演完才接受新请求）
  final int priority;

  /// 环境态（可循环播放）；其余为一次性反应动作，演完回落到环境态。
  /// 2026-10-08 修订：sad 入列（低状态环境态，经 machine.ambientOverride 注入）；
  /// walk 移出定版集不再被选中（值保留兼容）；sleep 待配置接线，未接线时
  /// ambient 恒回 idle。
  bool get ambient => this == idle || this == sad || this == sleep;

  static PetAction? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}
