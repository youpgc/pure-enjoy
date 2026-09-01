import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 消消乐滑动手势识别（按**起始格**驱动交换）。
///
/// 主流三消的核心交互是「按住某格朝相邻格拖动」，而非两次点选。本 mixin
/// 只负责手势识别：锁定滑动**起始格**，位移超过 [swipeThreshold] 后按主轴
/// 判定方向，再通过 [onSwipe] 把 (起始行, 起始列, 行增量, 列增量) 交给宿主
/// 执行交换；宿主无需关心坐标换算与手势细节。
///
/// 与点选共存：一次拖动在部分机型上仍会补发 tap，宿主应在 tap 回调开头用
/// [recentSwipe] 屏蔽这类伪点击，避免「滑动交换后又误触发点选」。
///
/// 用法：`class X extends FlameGame with TapCallbacks, PanDetector,
/// Match3SwipeMixin`，并实现 [cellAt] / [canInteract] / [onSwipe]。
///
/// [PanDetector] 必须写在**本 mixin 之前**：Flame 靠 `game is PanDetector`
/// 决定是否注册 pan 手势（见 gesture_detector_builder），本 mixin 覆写其
/// onPanXxx 默认空实现，故需在其之后应用。
mixin Match3SwipeMixin on FlameGame, PanDetector {
  /// 判定为滑动的最小位移（逻辑像素）；低于此值视为抖动，不当作滑动
  static const double swipeThreshold = 16.0;

  /// 滑动后屏蔽伪点击的时间窗
  static const Duration _tapGuard = Duration(milliseconds: 320);

  /// 把画布坐标换算为格坐标 (行, 列)；落在盘面之外返回 null。
  ///
  /// 由宿主实现，避免 mixin 反向依赖宿主的私有布局字段。
  (int, int)? cellAt(double x, double y);

  /// 当前是否接受输入（未加载 / 动画中 / 已结束时应为 false）
  bool get canInteract;

  /// 识别到有效滑动：(起始行, 起始列, 行增量, 列增量)。
  ///
  /// 目标格可能越界（边缘格向外滑），宿主需自行判空后再执行交换。
  void onSwipe(int r, int c, int dr, int dc);

  Offset? _panOrigin;
  int? _panR;
  int? _panC;
  bool _swipeFired = false;
  DateTime _lastSwipeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 距上次有效滑动是否仍在防误触时间窗内
  bool get recentSwipe => DateTime.now().difference(_lastSwipeAt) < _tapGuard;

  @override
  void onPanStart(DragStartInfo info) {
    _resetPan();
    if (!canInteract) return;
    final p = info.eventPosition.widget;
    final cell = cellAt(p.x, p.y);
    if (cell == null) return;
    _panR = cell.$1;
    _panC = cell.$2;
    _panOrigin = Offset(p.x, p.y);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_swipeFired || _panR == null || _panC == null || _panOrigin == null) {
      return;
    }
    if (!canInteract) return;
    final p = info.eventPosition.widget;
    final dx = p.x - _panOrigin!.dx;
    final dy = p.y - _panOrigin!.dy;
    if (dx.abs() < swipeThreshold && dy.abs() < swipeThreshold) return;

    // 取位移较大的轴为主方向，保证斜向拖动也能稳定命中一个相邻格
    final horizontal = dx.abs() > dy.abs();
    final dr = horizontal ? 0 : (dy > 0 ? 1 : -1);
    final dc = horizontal ? (dx > 0 ? 1 : -1) : 0;

    _swipeFired = true;
    _lastSwipeAt = DateTime.now();
    onSwipe(_panR!, _panC!, dr, dc);
  }

  @override
  void onPanEnd(DragEndInfo info) => _resetPan();

  @override
  void onPanCancel() => _resetPan();

  void _resetPan() {
    _panR = null;
    _panC = null;
    _panOrigin = null;
    _swipeFired = false;
  }
}
