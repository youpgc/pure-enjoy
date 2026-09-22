part of 'g2048_game.dart';

/// 2048 棋盘渲染（part of g2048_game，共享 State 私有状态）。
///
/// 从 g2048_game.dart 的 build 中抽离（审查 P1 单文件超 500 行）：底格、方块层、
/// 拖动手势与板面容器。纯代码搬迁，布局尺寸与手势判定零变更。
extension _G2048Board on _G2048GameState {
  Widget _buildBoard(BoxConstraints constraints) {
    // 棋盘取正方形，居中显示，避免长屏被拉伸
    final board = min(constraints.maxWidth, constraints.maxHeight);
    final gap = board * 0.03;
    final cell = (board - gap * (_size + 1)) / _size;
    double pos(int index) => gap + index * (cell + gap);

    final children = <Widget>[
      // 棋盘底格
      for (var r = 0; r < _size; r++)
        for (var c = 0; c < _size; c++)
          Positioned(
            left: pos(c),
            top: pos(r),
            width: cell,
            height: cell,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFCDC1B4),
                borderRadius: BorderRadius.circular(cell * 0.14),
              ),
            ),
          ),
      // 方块
      for (final t in _tiles)
        G2048Tile(
          key: ValueKey<int>(t.id),
          value: t.value,
          size: cell,
          left: pos(t.col),
          top: pos(t.row),
          isNew: t.isNew,
          merged: t.merged,
          slide: _G2048GameState._slide,
        ),
    ];

    return Center(
      child: GestureDetector(
        // opaque：棋盘空白处同样接收拖动，避免只有方块上能滑
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          debugPrint('[G2048] panStart');
          _dragDelta = Offset.zero;
          _dragConsumed = false;
        },
        onPanUpdate: _onDragUpdate,
        onPanEnd: (_) {
          // 兜底：整段拖动都很短但已越过阈值时在抬手时判定
          if (!_dragConsumed &&
              _dragDelta.distance >= _G2048GameState._swipeThreshold) {
            _applySwipe(_dragDelta);
          }
          debugPrint('[G2048] panEnd consumed=$_dragConsumed');
          _dragDelta = Offset.zero;
          _dragConsumed = false;
        },
        // 手势被系统/手势竞技场取消时复位，避免 _dragConsumed 卡死导致后续无响应。
        onPanCancel: () {
          debugPrint('[G2048] panCancel');
          _dragDelta = Offset.zero;
          _dragConsumed = false;
        },
        child: Container(
          width: board,
          height: board,
          decoration: BoxDecoration(
            color: const Color(0xFFBBADA0),
            borderRadius: BorderRadius.circular(gap * 2),
          ),
          child: Stack(children: children),
        ),
      ),
    );
  }
}
