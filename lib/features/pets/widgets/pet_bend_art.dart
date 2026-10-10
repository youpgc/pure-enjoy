import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show rootBundle;

import '../../../constants/pet_bend.dart';
import '../utils/pet_bend_eval.dart';

/// 弯曲着色器程序（进程内单份）。加载失败＝弯曲退化，由本文件的整图兜底接手。
Future<ui.FragmentProgram?> petBendProgram() =>
    _petBendProgram ??= ui.FragmentProgram.fromAsset('shaders/pet_bend.frag')
        .then<ui.FragmentProgram?>((p) {
      _bendError = null;
      return p;
    }).catchError((Object e) {
      // 失败必须**可见**：静默退化的话，「弯曲已生效」会被误当成结论
      _bendError = '$e';
      if (kDebugMode) debugPrint('宠物弯曲着色器不可用，退化为整图兜底：$e');
      return null;
    });

Future<ui.FragmentProgram?>? _petBendProgram;
String? _bendError;

/// 着色器不可用的原因（null=可用或尚未尝试）
String? get petBendError => _bendError;

/// 画布外扩边距（栅格单位）。
///
/// 样片把 384 帧贴进 `384+2×64` 的画布里演弯曲，64 是按「托举＋放大合量」倒推的余量，
/// 作用是让脚底在 `dy>0`（委屈/睡觉整身下沉）时不被画布边裁掉。App 同样留这份余量，
/// 但用 [OverflowBox] 把画布外扩而不是缩小宠物，屏幕上的宠物尺寸与换渲染器之前一致。
const double _kCanvasPad = 64;

/// 父约束无界时的基准边长（与 `PetLivingArt` 同口径）
const double _kFallbackArtSize = 320;

/// 分层弯曲播放器：逐帧按编排求值，把姿态喂给 [petBendProgram] 的着色器。
///
/// 与整图刚体变换（`Transform.rotate/scale`）的本质差别：被弯曲的是**图像内部**的
/// 一行一行，不是整张图的位姿——归零线以下逐像素不动，头颈才有"软"的感觉。
class PetBendArt extends StatefulWidget {
  const PetBendArt(
      {super.key,
      required this.geo,
      required this.act,
      this.revealDir,
      this.primaryColor = Colors.white});

  /// 当前形态的栅格几何（含帧档目录）
  final PetBendGeo geo;

  /// 当前动作的编排（周期/关键帧/呼吸都来自 `kPetBendActs`）
  final PetActDef act;

  /// 进化末段换的形态目录：编排里表情档越界＝换到该目录的 `c1_neutral`
  /// （样片的第 7 档是形象修正之前的派生帧，没进在架批次，故形态替换走这里）
  final String? revealDir;

  /// 辉光主色（跟主题走，不硬编码）
  final Color primaryColor;

  @override
  State<PetBendArt> createState() => _PetBendArtState();
}

class _PetBendArtState extends State<PetBendArt>
    with TickerProviderStateMixin {
  /// 绝对时钟：呼吸按它跑（不参与动作起止，被打断也不重头呼吸）
  final Stopwatch _clock = Stopwatch();

  /// 每帧只推重绘，不重建 widget 树
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// 表情帧（下标同 [kPetBendFrameFiles]）与进化末档的替换帧
  final List<ui.Image?> _frames =
      List<ui.Image?>.filled(kPetBendFrameFiles.length, null);
  ui.Image? _reveal;

  ui.FragmentShader? _shader;

  /// 一次性动作的起播时刻（绝对时钟坐标，秒）
  double _actStart = 0;

  /// 素材加载序号：换形态后迟到的解码结果不能写进新形态的帧槽
  int _loadSeq = 0;

  late final Ticker _ticker;

  PetActDef get _act => widget.act;

  @override
  void initState() {
    super.initState();
    _clock.start();
    _ticker = createTicker((_) => _tick.value++)..start();
    petBendProgram().then((p) {
      if (!mounted || p == null) return;
      setState(() => _shader = p.fragmentShader());
      _tick.value++;
    });
    _loadFrames();
  }

  @override
  void didUpdateWidget(covariant PetBendArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geo.dir != widget.geo.dir ||
        oldWidget.revealDir != widget.revealDir) {
      _loadFrames();
    }
    if (oldWidget.act.key != widget.act.key) {
      // 一次性动作从 0 起演；循环动作也重算起点（绝对时钟上的呼吸不受影响）
      _actStart = _clock.elapsedMilliseconds / 1000;
    }
  }

  Future<void> _loadFrames() async {
    final seq = ++_loadSeq;
    for (var i = 0; i < kPetBendFrameFiles.length; i++) {
      final img =
          await _decode('${widget.geo.dir}/${kPetBendFrameFiles[i]}.png');
      if (!mounted || seq != _loadSeq) {
        img?.dispose();
        return;
      }
      _frames[i]?.dispose();
      _frames[i] = img;
      _tick.value++;
    }
    final rd = widget.revealDir;
    if (rd == null) return;
    final img = await _decode('$rd/${kPetBendFrameFiles.first}.png');
    if (!mounted || seq != _loadSeq) {
      img?.dispose();
      return;
    }
    _reveal?.dispose();
    _reveal = img;
    _tick.value++;
  }

  /// 按原尺寸解码——缩放解码（`cacheWidth`）会把 384 栅格换成别的尺寸，
  /// 而弯曲几何、归零线、眼区行程全部定义在 384 上，一改尺寸就逐像素错位。
  Future<ui.Image?> _decode(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (e) {
      // 素材与清单脱节时画透明帧，不抛异常（铁律 8）
      if (kDebugMode) debugPrint('宠物弯曲帧解码失败（$asset）：$e');
      return null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.stop();
    _tick.dispose();
    for (final f in _frames) {
      f?.dispose();
    }
    _reveal?.dispose();
    super.dispose();
  }

  /// 当前姿态：循环态用绝对时钟取模；一次性动作停在 u=1
  /// （结束计时的抖动不能把相位绕回 0，否则末尾会闪一帧首档）
  PetBendPose _pose() {
    final t = _clock.elapsedMilliseconds / 1000;
    final side = widget.geo.side.toDouble();
    if (_act.loop) return evalAct(_act, side, t);
    return evalAct(_act, side, t,
        phaseOverride: ((t - _actStart) / _act.per).clamp(0.0, 1.0));
  }

  ui.Image? _imageFor(int frame) =>
      frame < _frames.length ? _frames[frame] : (_reveal ?? _frames.last);

  void _paint(Canvas canvas, Size size) {
    final pose = _pose();
    final side = widget.geo.side.toDouble();
    // 画布＝栅格 + 四周外扩，故「基准边长」＝画布边长换算回 384 口径
    final ref = size.width * side / (side + _kCanvasPad * 2);
    _paintGlow(canvas, pose, size, ref);
    final img = _imageFor(pose.frame);
    if (img == null) return;
    final shader = _shader;
    if (shader == null) {
      _paintFallback(canvas, pose, img, ref / side);
      return;
    }
    _feedShader(shader, pose, img, ref);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  /// 着色器不可用（加载失败或尚未返回）时的兜底画面。
  ///
  /// 退化的是「图像内部被逐行弯曲」这一层：`th`/`a` 两个通道丢弃，位移与压扁
  /// 拉伸用 canvas 变换近似，**表情分档切换仍然工作**（分档在 Dart 侧求值）。
  /// 这样最坏情况是一只会动会换表情的宠物，而不是一只消失的宠物。
  void _paintFallback(
      Canvas canvas, PetBendPose p, ui.Image img, double unit) {
    final geo = widget.geo;
    final cx = geo.side / 2 * unit;
    final fy = geo.foot * unit;
    final src = Offset.zero & Size(img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromLTWH(_kCanvasPad * unit, _kCanvasPad * unit,
        img.width * unit, img.height * unit);
    canvas.save();
    // 变换原点固定在脚底中心——与着色器里 tx/ty 的原点口径一致，脚底不飘
    canvas.translate(p.dx * unit, p.dy * unit);
    canvas.translate(cx, fy);
    canvas.scale(p.sx, p.sy);
    canvas.translate(-cx, -fy);
    canvas.drawImageRect(
        img, src, dst, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }

  /// 进化辉光：径向白→主色→透明，淡入淡出由编排的 glow 通道给（跟随主题主色）
  void _paintGlow(Canvas canvas, PetBendPose pose, Size size, double ref) {
    final g = pose.glow;
    if (g <= 0.01) return;
    final d = ref * 1.7;
    final rect =
        Rect.fromCenter(center: size.center(Offset.zero), width: d, height: d);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.0, 0.45, 0.85],
          colors: [
            Colors.white.withValues(alpha: 0.75 * g),
            widget.primaryColor.withValues(alpha: 0.25 * g),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  /// uniform 装配（顺序＝着色器声明顺序，采样器不占浮点槽位）：
  /// `uPose`(0~3) `uGeo`(4~7) `uXf`(8~11) `uRes`(12~15)
  ///
  /// 四段全部按 vec4 对齐摆放（`uPose` 在着色器里声明成 vec4，第四分量留空）——
  /// 这样「按声明顺序累加浮点下标」与「按 std140 补齐」两种布局算出的下标完全相同，
  /// 不必赌引擎到底给 vec3 补不补那 4 个字节。
  void _feedShader(
      ui.FragmentShader s, PetBendPose p, ui.Image img, double ref) {
    final geo = widget.geo;
    final side = geo.side.toDouble();
    final band = (geo.yn - geo.headTop).toDouble();
    // 低垂斜坡＝移动区比例，但有长度下限（归零线被拖小时趋零＝线上一个硬断口）
    final ramp = geo.droopRamp * band;
    final dn = math.max(ramp, geo.droopRampMin);
    // k＝逻辑像素/栅格单位。着色器里的片元坐标是画布局部的**逻辑**像素（见 pet_bend.frag
    // 的实测口径），所以这里**不乘 dpr**——乘了会把整幅 `v` 推到栅格外，逐像素判界成全透明。
    final k = ref / side;
    s
      ..setFloat(0, p.thRad)
      ..setFloat(1, p.a)
      ..setFloat(2, geo.yn + band / 2) // 支点：归零线再往头顶半格
      ..setFloat(3, 0)
      ..setFloat(4, geo.yn.toDouble())
      ..setFloat(5, 1 / band)
      ..setFloat(6, 1 / dn)
      ..setFloat(7, side)
      ..setFloat(8, p.sx)
      ..setFloat(9, p.sy)
      // tx/ty＝样片里的画布原点，含外扩边距；缩放原点固定在脚底中心
      ..setFloat(10, side / 2 + p.dx - side / 2 * p.sx + _kCanvasPad)
      ..setFloat(11, geo.foot + p.dy - geo.foot * p.sy + _kCanvasPad)
      ..setFloat(12, k)
      ..setFloat(13, 1 / side)
      ..setFloat(14, 0)
      ..setFloat(15, 0);
    s.setImageSampler(0, img);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final box = constraints.biggest;
      final ref = box.width.isFinite && box.height.isFinite
          ? math.min(box.width, box.height)
          : _kFallbackArtSize;
      final side = widget.geo.side.toDouble();
      final grid = ref * (side + _kCanvasPad * 2) / side;
      // 画布外扩到栅格+边距，宠物本体仍占 ref（与整图补间的 contain 尺寸一致）
      return OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: grid,
        maxHeight: grid,
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: grid,
            child: CustomPaint(painter: _BendPainter(_paint, _tick)),
          ),
        ),
      );
    });
  }
}

class _BendPainter extends CustomPainter {
  _BendPainter(this._onPaint, Listenable repaint) : super(repaint: repaint);

  final void Function(Canvas canvas, Size size) _onPaint;

  @override
  void paint(Canvas canvas, Size size) => _onPaint(canvas, size);

  @override
  bool shouldRepaint(covariant _BendPainter oldDelegate) => false;
}
