import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

/// 消消乐方块数据模型（纯数据，由 FlameGame 统一绘制与驱动动画）。
///
/// [px]/[py] 为当前像素左上角，[update] 中向目标格 (row,col) 缓动；[scale]
/// 用于消除时的缩放弹出；[special] 标记特殊糖（'row'/'col' 条纹、'bomb' 彩爆、'wrap' 包装）。
class Candy {
  int type;
  String special;
  int row;
  int col;
  double px;
  double py;
  double scale;
  bool dying;

  /// 消除动画进度透明度（1→0），由 [Match3FlameGame.update] 驱动，
  /// 让方块「弹出再淡出」而非瞬间消失，过渡更柔和。
  double dyingAlpha = 1.0;

  /// 消除动画已过去时长（秒），用于计算 [dyingAlpha] 与 [scale] 弹出曲线。
  double dyingT = 0.0;

  /// 提示高亮剩余秒数（>0 时叠加白色脉动描边），由提示道具设置，
  /// 引擎 update 逐帧递减（道具商城扩展预留，2026-09-09）。
  double hintT = 0.0;

  Candy(
    this.type,
    this.row,
    this.col,
    this.px,
    this.py, {
    this.special = '',
    this.scale = 1,
    this.dying = false,
  });

  double get cx => px;
  double get cy => py;
}

/// 定版 SVG 的实际内容占比：图标设计在 64 逻辑坐标内，内容（含底板圆）
/// 约 52/64，四周为透明留白。用于按「格内视觉间隙」反推绘制尺寸。
const double kCandyContentRatio = 0.8125;

/// 图标内容与格边的目标间隙（px）：1-3px，取中值 2。
const double kCandyGap = 2.0;

/// 在指定格绘制一个动物头像糖块（定版 SVG 资产，按 type 渲染）。
///
/// SVG 以 [vg.loadPicture] 同步解析并缓存为 [ui.Picture]（每种类型仅解析一次），
/// 渲染时缩放平移到目标格。特殊糖标识（条纹/彩爆/包装）、提示高亮与消除
/// 动画在 SVG 之上叠加绘制，与旧版矢量自绘完全同口径。
void drawCandy(Canvas canvas, Candy candy, double cell, Color color) {
  final a = candy.dying ? candy.dyingAlpha.clamp(0.0, 1.0) : 1.0;
  if (a <= 0.01) return;
  // 放大：按「内容距格边 ≈ [kCandyGap] px」反推绘制尺寸——SVG 透明留白
  // 会略超出格界（透明无视觉影响），内容本体保持在格内。
  final size = (cell - 2 * kCandyGap) / kCandyContentRatio * candy.scale;
  if (size <= 0) return;
  final cx = candy.px + cell / 2;
  final cy = candy.py + cell / 2;
  final topLeft = Offset(cx - size / 2, cy - size / 2);
  final picture = _candyPicture(candy.type);

  canvas.save();
  // 消除淡出：saveLayer 包 alpha（drawPicture 不支持 paint.alpha）
  if (a < 0.999) {
    canvas.saveLayer(
      topLeft & Size(size, size),
      Paint()..color = Colors.white.withValues(alpha: a),
    );
  }
  canvas.translate(topLeft.dx, topLeft.dy);
  canvas.scale(size / 64, size / 64);
  if (picture != null) {
    canvas.drawPicture(picture);
  } else {
    // 资产缺失兜底：回退纯色圆形（不应发生）
    canvas.drawCircle(
      const Offset(32, 32),
      22,
      Paint()..color = color,
    );
  }
  // 特殊糖叠加（几何位置以 64 逻辑坐标计，已在 scale 变换内）
  // 特殊糖表现（2026-09-10 定版方案 A「霓虹描边环」）由引擎 render 循环
  // 在糖果之上调 Match3Overlays.drawSpecialRing 绘制（贴图标圆板外缘）。
  // 提示高亮：白色脉动描边（hintT 为剩余秒数，兼作脉动相位）
  if (candy.hintT > 0) {
    final pulse = 0.55 + 0.45 * sin(candy.hintT * 9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, 58, 58),
        Radius.circular(14),
      ),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: (0.35 + 0.45 * pulse) * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 + 1.5 * pulse,
    );
  }
  if (a < 0.999) canvas.restore();
  canvas.restore();
}

/// 六种动物头像 SVG 的 picture 缓存（按 type id 索引；资产缺失为 null）。
final Map<int, ui.Picture?> _candyPictureCache = <int, ui.Picture?>{};

ui.Picture? _candyPicture(int type) => _candyPictureCache[type];

/// 预加载六种动物头像 SVG（引擎 onLoad 触发，异步解析后写入缓存；
/// 未就绪的帧由 drawCandy 绘制纯色兜底圆，Flame 每帧重绘自动补上）。
Future<void> precacheCandyPictures() async {
  for (var t = 0; t < 6; t++) {
    try {
      final info =
          await vg.loadPicture(SvgAssetLoader('assets/games/match3/candy_$t.svg'), null);
      _candyPictureCache[t] = info.picture;
    } catch (e) {
      _candyPictureCache[t] = null;
    }
  }
}


/// 糖果基础色板（index 即 cell.type / 收集目标 collectType 的取值域），
/// HUD「目标糖果」展示与绘制共用，保证颜色一致。
const List<Color> kCandyColors = <Color>[
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFFEE58),
  Color(0xFFAB47BC),
  Color(0xFFFFA726),
];

/// 色板对应的中文名（收集模式 HUD 展示用）
const List<String> kCandyColorNames = <String>['红', '蓝', '绿', '黄', '紫', '橙'];


extension _ColorDarken on Color {
  Color darken(double amount) {
    final f = 1 - amount;
    return Color.fromARGB(
      (a * 255).round().clamp(0, 255),
      (r * f * 255).round().clamp(0, 255),
      (g * f * 255).round().clamp(0, 255),
      (b * f * 255).round().clamp(0, 255),
    );
  }
}
