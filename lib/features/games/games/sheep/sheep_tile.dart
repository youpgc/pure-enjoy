import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/game_icons.dart';

/// 羊了个羊方块状态
enum SheepTileState {
  /// 在棋盘堆中
  board,

  /// 已放入底部槽位
  slot,

  /// 被道具移出（临时移除，不参与渲染）
  removing,
}

/// 羊了个羊单块数据模型。
///
/// 坐标为逻辑单位（方块尺寸=1，layer 越大越靠上）。[covered] 由遮挡计算得出，
/// 仅未遮挡的方块可点击；[state] 决定其渲染位置（棋盘 / 槽位）。
class SheepTile {
  final int id;
  int type;
  final int layer;
  final double x;
  final double y;

  SheepTileState state;
  int slotIndex;
  bool covered;

  SheepTile(
    this.id,
    this.type,
    this.layer,
    this.x,
    this.y,
  )   : state = SheepTileState.board,
        slotIndex = -1,
        covered = false;
}

/// 羊了个羊方块视图：位置滑动 + 遮挡变暗 + 水果 SVG 图标。
class SheepTileWidget extends StatelessWidget {
  final SheepTile tile;
  final double left;
  final double top;
  final double size;
  final VoidCallback? onTap;
  final Duration slide;

  const SheepTileWidget({
    super.key,
    required this.tile,
    required this.left,
    required this.top,
    required this.size,
    this.onTap,
    this.slide = const Duration(milliseconds: 140),
  });

  @override
  Widget build(BuildContext context) {
    final blocked = tile.covered || tile.state != SheepTileState.board;
    return AnimatedPositioned(
      duration: slide,
      left: left,
      top: top,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: blocked ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: tile.covered ? 0.5 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(size * 0.18),
              border: Border.all(
                color: tile.covered ? Colors.grey.shade300 : const Color(0xFFE0E0E0),
              ),
              boxShadow: blocked
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            padding: EdgeInsets.all(size * 0.08),
            child: SvgPicture.string(
              GameIcons.fruit(tile.type),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
