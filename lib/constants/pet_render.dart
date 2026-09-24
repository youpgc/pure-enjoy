/// 宠物**表现层**契约（与渲染栈无关的动作命名）
///
/// 从 [pet.dart] 拆出（2026-09-24）：`pet.dart` 承载的是与 Supabase DDL check
/// 对齐的**数据库键域**（铁律 12 三端对齐），本文件承载的是**客户端表现契约**，
/// 不入库、不参与任何数值判定。两组值域不同源，故分文件登记。
library;

/// 宠物 2D 动作契约（8 个标准动作，命名全局统一，2026-09-24 表现层定版）
///
/// 三条用途，新增/改名动作必须三处同批（铁律 12）：
/// 1. App 动作仲裁与补间编排（`utils/pet_action_machine.dart`
///    + `widgets/pet_living_art.dart`）；
/// 2. `pet_species.render2d` 的 `frames` 键（该动作有真帧才走帧序列，
///    无帧走程序补间，见 `utils/pet_art.dart`）；
/// 3. 素材文件名（`assets/pets/frames/<species_code>_<action>_N.png`）。
///
/// 动作集合本身继承自 3D 期的定版口径（需求 §11.3 与《3D 展现与交互实现方案》
/// §2.1 触发矩阵）——那 8 个动作与渲染栈无关，降维到 2D 后原样沿用；
/// 被废弃的是 3D 专有的 orbit/zoom/相机预设/天空盒，不在本枚举内。
enum PetAction {
  idle('idle', '待机', 0),
  walk('walk', '行走', 1),
  sleep('sleep', '睡觉', 2),
  sad('sad', '委屈', 3),
  happy('happy', '开心', 4),
  petted('petted', '被抚摸', 5),
  eat('eat', '进食', 6),
  evolve('evolve', '进化演出', 7);

  const PetAction(this.code, this.label, this.priority);

  final String code;
  final String label;

  /// 仲裁优先级：大的打断小的；[PetAction.evolve] 最高且独占（演完才接受新请求）
  final int priority;

  /// 环境态（可循环播放）；其余为一次性反应动作，演完回落到环境态
  bool get ambient => this == idle || this == walk || this == sleep;

  static PetAction? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}
