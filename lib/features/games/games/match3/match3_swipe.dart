import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 单根手指的滑动追踪状态（起始坐标 + 起始格 + 是否已触发）
class _PanState {
  Offset origin;
  int r;
  int c;
  bool fired = false;
  _PanState(this.origin, this.r, this.c);
}

/// 消消乐滑动手势识别（按**起始格**驱动交换，多指隔离）。
///
/// 主流三消的核心交互是「按住某格朝相邻格拖动」，而非两次点选。本 mixin
/// 只负责手势识别：以**指尖触屏第一时间**的坐标锁定起始格，位移超过
/// [swipeThreshold] 后按主轴判定方向，再通过 [onSwipe] 把
/// (起始行, 起始列, 行增量, 列增量) 交给宿主执行交换；宿主无需关心坐标
/// 换算与手势细节。
///
/// 2026-09-14 审查修复两点（「滑动换错方块/滑了没反应」根因）：
/// 1. **多指状态串扰**：原实现滑动状态为全局单份，第二触点（手掌边缘
///    误触常见）onPanStart 会覆盖第一根手指正在拖动的状态，随后第一根
///    手指越阈值时按「第二触点的格 + 第一根手指的方向」换出无关方块。
///    现改为按 pointerId 隔离（宿主需混入 [MultiTouchDragDetector]）。
/// 2. **动画期滑动整条丢弃**：原 onPanStart 在 canInteract=false 时直接
///    丢弃手势，导致连锁动画期间（~0.5-2s）开始的滑动全部失效。现改为
///    始终记录起始格并照常识别，执行时机（立即执行或缓冲到动画结束）
///    由宿主在 [onSwipe] 里决定（输入缓冲是主流三消标准做法）。
///
/// 与点选共存：一次拖动在部分机型上仍会补发 tap，宿主应在 tap 回调开头用
/// [recentSwipe] 屏蔽这类伪点击，避免「滑动交换后又误触发点选」。
///
/// 用法：`class X extends FlameGame with TapCallbacks, MultiTouchDragDetector,
/// Match3SwipeMixin`，并实现 [cellAt] / [canInteract] / [onSwipe]。
///
/// [MultiTouchDragDetector] 必须写在**本 mixin 之前**：它注册拖动手势
/// 识别器并提供 pointerId，本 mixin 覆写其 onDragXxx 空实现，故需在其之后。
mixin Match3SwipeMixin on FlameGame, MultiTouchDragDetector {
  /// 判定为滑动的最小位移（逻辑像素）；低于此值视为抖动，不当作滑动
  static const double swipeThreshold = 16.0;

  /// 滑动后屏蔽伪点击的时间窗
  static const Duration _tapGuard = Duration(milliseconds: 320);

  /// 把画布坐标换算为格坐标 (行, 列)；落在盘面之外返回 null。
  ///
  /// 由宿主实现，避免 mixin 反向依赖宿主的私有布局字段。
  (int, int)? cellAt(double x, double y);

  /// 当前是否接受输入（未加载 / 动画中 / 已结束时应为 false）。
  ///
  /// 识别阶段不再用它丢弃手势（见类注释第 2 点），仅供宿主在 [onSwipe]
  /// 中决定「立即执行还是缓冲」。
  bool get canInteract;

  /// 识别到有效滑动：(起始行, 起始列, 行增量, 列增量)。
  ///
  /// 目标格可能越界（边缘格向外滑），宿主需自行判空后再执行交换。
  /// 宿主可在此做输入缓冲：canInteract=false 时缓存，动画结束补执行。
  void onSwipe(int r, int c, int dr, int dc);

  final Map<int, _PanState> _pans = <int, _PanState>{};
  DateTime _lastSwipeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 距上次有效滑动是否仍在防误触时间窗内
  bool get recentSwipe => DateTime.now().difference(_lastSwipeAt) < _tapGuard;

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    // eventPosition.widget 即「相对 GameWidget 画布的局部坐标」，为指尖
    // 触屏第一时间（pointer down）的全局坐标经 convertGlobalToLocalCoordinate
    // 的换算结果，与 onTapUp 的 event.canvasPosition 同一坐标系（flame 1.38
    // 已统一），cellAt 可直接消费。
    final p = info.eventPosition.widget;
    final cell = cellAt(p.x, p.y);
    if (cell == null) return; // 起始点在盘面外（如 HUD/留白），不追踪该指
    _pans[pointerId] = _PanState(Offset(p.x, p.y), cell.$1, cell.$2);
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final state = _pans[pointerId];
    if (state == null || state.fired) return;
    final p = info.eventPosition.widget;
    final dx = p.x - state.origin.dx;
    final dy = p.y - state.origin.dy;
    if (dx.abs() < swipeThreshold && dy.abs() < swipeThreshold) return;

    // 取位移较大的轴为主方向，保证斜向拖动也能稳定命中一个相邻格
    final horizontal = dx.abs() > dy.abs();
    final dr = horizontal ? 0 : (dy > 0 ? 1 : -1);
    final dc = horizontal ? (dx > 0 ? 1 : -1) : 0;

    state.fired = true; // 每根手指每次按住至多触发一次
    _lastSwipeAt = DateTime.now();
    onSwipe(state.r, state.c, dr, dc);
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) => _pans.remove(pointerId);

  @override
  void onDragCancel(int pointerId) => _pans.remove(pointerId);
}
