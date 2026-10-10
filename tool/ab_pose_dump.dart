// 一次性 A/B 对照：把 App 侧编排求值的采样点打到 stdout，供
// `pet_anim_demo/tools/ab_app_vs_sandbox.mjs` 与沙盒冻结件逐点比对。
//  purpose：证明 `pet_bend_eval.dart` 是样片 `idle_rig_action_defs.mjs` 的等价转录，
//  而不是「看起来一样」。跑法（仓库根）：
//    dart run tool/ab_pose_dump.dart > build/ab_dart.json
import 'dart:convert';
import 'dart:io';

import 'package:pure_enjoy/constants/pet_bend.dart';
import 'package:pure_enjoy/features/pets/utils/pet_bend_eval.dart';

void main() {
  const side = 384.0;
  const steps = 201; // 覆盖两个周期，取 201 点（含首尾）
  final rows = <List<Object>>[];
  for (final act in kPetBendActs.values) {
    for (var i = 0; i < steps; i++) {
      final t = 2 * act.per * i / (steps - 1);
      final p = evalAct(act, side, t);
      rows.add([
        act.key, t, p.frame, p.u, p.thRad * 180 / 3.141592653589793,
        p.a, p.dx, p.dy, p.sx, p.sy, p.glow,
      ]);
    }
  }
  stdout.write(const JsonEncoder().convert(rows));
}
