/// 2D 分层弯曲的**编排求值**：把「绝对时钟 + 动作」算成一个姿态。
///
/// 本文件是冻结件 `pet_anim_demo/idle_rig_action_defs.mjs` 里 `ch / faceAt / evalAct`
/// 三个函数的逐式转录，不是重写：样片与 App 必须同源，否则「验收过的画面」和
/// 「真机上的画面」是两套数学，任何一次复测都分不清差在素材还是差在插值。
/// 数据表（关键帧、周期、呼吸参数）也不在这里，见 `constants/pet_bend.dart`。
///
/// 三条硬约束（随编排表冻结，改任何数值都要回样片复跑门禁）：
/// 1. `|θ| ≤ 1°`；2. 表情档之间硬切（[PetBendPose.frame] 只做整数换档，绝不做混合）；
/// 3. 归零线以下真·不动（权重场在着色器与 [PetBendGeo.wR] 里是同一条公式）。
library;

import 'dart:math' as math;

import '../../../constants/pet_bend.dart';

const double _tau = 6.283185307179586;

/// 段内 smoothstep 插值（`ch`）：关键帧之间不是线性而是缓入缓出，两端留平。
/// 通道未写时取 [fallback]（位移类为 0，压扁类为 1）。
double ch(PetKeys keys, double u, {double fallback = 0}) {
  if (keys == null || keys.isEmpty) return fallback;
  final n = keys.length;
  if (n == 1) return keys.first[1];
  if (u <= keys.first[0]) return keys.first[1];
  if (u >= keys[n - 1][0]) return keys[n - 1][1];
  var i = n - 1;
  while (i > 0 && u < keys[i][0]) {
    i--;
  }
  final p = keys[i];
  final q = keys[i + 1 > n - 1 ? n - 1 : i + 1];
  final k = q[0] > p[0] ? _smoothstep((u - p[0]) / (q[0] - p[0])) : 0.0;
  return p[1] + (q[1] - p[1]) * k;
}

/// 表情档（`faceAt`）：**硬切**，取最后一个相位 ≤ u 的档，不做任何混合
int faceAt(PetActDef act, double u) {
  final e = act.expr;
  if (e == null || e.isEmpty) return 0;
  var i = e.length - 1;
  while (i > 0 && u < e[i][0]) {
    i--;
  }
  return e[i][1].round();
}

/// 一个时刻的完整姿态。空间量的单位全在 `side×side` 生产栅格上：
/// px 位移要乘显示缩放才落到逻辑像素，角度与压扁倍率不随尺寸变。
class PetBendPose {
  const PetBendPose({
    required this.frame,
    required this.thRad,
    required this.a,
    required this.dx,
    required this.dy,
    required this.sx,
    required this.sy,
    required this.glow,
    required this.u,
  });

  /// 表情档下标（= `kPetBendFrameFiles` 的序）；≥ 表长表示「进化末段换形态」
  final int frame;

  /// 弯曲角度（弧度，正=顺时针，按 [PetBendGeo.wR] 沿 y 分配）
  final double thRad;

  /// 头部竖向低垂量（px，正=向下，按 [PetBendGeo.wA] 分配）
  final double a;

  /// 刚体平移（px，dy 向下为正）
  final double dx;
  final double dy;

  /// 压扁拉伸倍率（原点=脚底中心）
  final double sx;
  final double sy;

  /// 进化辉光 0~1
  final double glow;

  /// 整周期归一化相位
  final double u;
}

/// `evalAct`：循环态用 [clockSec] 取模得相位；一次性动作由调用方给 [phaseOverride]
/// （播完停在 u=1——不能让结束计时的抖动把相位绕回 0，那会在末尾闪一帧首档）。
///
/// 呼吸按**绝对时间**跑（与样片一致）：它不参与动作起止，被打断也不重头呼吸。
PetBendPose evalAct(PetActDef act, double side, double clockSec,
    {double? phaseOverride}) {
  final per = act.per;
  final u = phaseOverride ?? (((clockSec % per) + per) % per / per);
  var dx = ch(act.dx, u);
  var dy = ch(act.dy, u);
  var sx = ch(act.sx, u, fallback: 1);
  var sy = ch(act.sy, u, fallback: 1);
  final b = act.breath;
  if (b != null) {
    final amp = b.amp / 100;
    final br = math.sin(_tau * clockSec / b.per);
    sx *= 1 - amp * 0.6 * br;
    sy *= 1 + amp * br;
    // 样片 v4 定版的微漂移（幅度 0.6% 时约 ±1.4px / ±0.9px）；
    // dy 统一「向下为正」并居中去均值，所以常量项是 0.1 而不是 0.3
    dx += 0.6 * amp * side * math.sin(_tau * clockSec / (b.per * 1.2));
    dy += 0.1 * amp * side -
        0.2 *
            amp *
            side *
            (1 - math.cos(2 * _tau * clockSec / (b.per * 1.2)));
  }
  return PetBendPose(
    frame: faceAt(act, u),
    thRad: ch(act.th, u) * math.pi / 180,
    a: ch(act.a, u),
    dx: dx,
    dy: dy,
    sx: sx,
    sy: sy,
    glow: ch(act.glow, u),
    u: u,
  );
}

double _smoothstep(double v) => v >= 1 ? 1 : v <= 0 ? 0 : v * v * (3 - 2 * v);
