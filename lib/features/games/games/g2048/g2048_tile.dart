import 'package:flutter/material.dart';

/// 单个 2048 方块：负责自身的位置滑动 + 出现/合并弹跳动画。
///
/// 位置用 [AnimatedPositioned] 实现丝滑滑动；出现(isNew)用缩放 0→1 弹出，
/// 合并(merged，值变化)用 1.18→1 弹一下。由父级 [G2048Game] 以稳定 id 驱动。
class G2048Tile extends StatefulWidget {
  /// 数值（决定颜色与字号）
  final int value;

  /// 边长（与棋盘格一致）
  final double size;

  /// 目标左上角坐标（相对棋盘 Stack）
  final double left;
  final double top;

  /// 是否新生成（弹出动画）
  final bool isNew;

  /// 是否本回合合并（弹一下）
  final bool merged;

  /// 滑动动画时长
  final Duration slide;

  const G2048Tile({
    super.key,
    required this.value,
    required this.size,
    required this.left,
    required this.top,
    this.isNew = false,
    this.merged = false,
    this.slide = const Duration(milliseconds: 120),
  });

  @override
  State<G2048Tile> createState() => _G2048TileState();
}

class _G2048TileState extends State<G2048Tile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: widget.isNew ? 0.1 : 1.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant G2048Tile old) {
    super.didUpdateWidget(old);
    // 合并后方块值变化 → 重放弹跳
    if (widget.merged && old.value != widget.value) {
      _ctrl.reset();
      _scale = Tween<double>(begin: 1.18, end: 1.0)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: widget.slide,
      left: widget.left,
      top: widget.top,
      width: widget.size,
      height: widget.size,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: _faceColor(widget.value),
            borderRadius: BorderRadius.circular(widget.size * 0.14),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.all(widget.size * 0.08),
              child: Text(
                '${widget.value}',
                style: TextStyle(
                  fontSize: widget.value >= 1000
                      ? widget.size * 0.34
                      : widget.size * 0.42,
                  fontWeight: FontWeight.bold,
                  color: widget.value <= 4 ? const Color(0xFF776E65) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 数值配色（经典 2048 阶）
  static Color _faceColor(int v) {
    switch (v) {
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 16:
        return const Color(0xFFF59563);
      case 32:
        return const Color(0xFFF67C5F);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 256:
        return const Color(0xFFEDCC61);
      case 512:
        return const Color(0xFFEDC850);
      case 1024:
        return const Color(0xFFEDC53F);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFF3C3A32);
    }
  }
}

/// 方块数据模型（带稳定 id，便于 Flutter 复用 Widget 做动画）
class TileModel {
  final int id;
  int value;
  int row;
  int col;
  bool isNew;
  bool merged;
  bool toRemove;

  TileModel(
    this.id,
    this.value,
    this.row,
    this.col, {
    this.isNew = false,
    this.merged = false,
    this.toRemove = false,
  });
}
