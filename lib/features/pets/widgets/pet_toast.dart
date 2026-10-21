import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 宠物模块专用轻提示（Toast）——替代全局 [showSnackBar]。
///
/// 与 SnackBar 的差异：
/// - **层级置顶**：挂 rootNavigator 的 Overlay 最顶层，插入时位于当时
///   所有内容之上——弹窗打开期间触发的提示会浮在弹窗上方（SnackBar 挂
///   在 Scaffold 内会被弹窗压住，20261012 用户反馈）；后开的弹窗仍会盖
///   住先显示的提示（toast 3s 自灭，不抢后续弹窗）；
/// - **宠物元素**：左侧爪印圆徽 + 宠物色系三态（默认主题蓝 / 成功绿 /
///   失败红）；
/// - **替换式单条**：连续触发时立即替换上一条，不排队不叠加；
/// - 顶部安全区下方滑入，3s 自动淡出，点击整条可提前关闭，
///   上划或右滑甩出（达距离/速度阈值）也可移除；
///
/// 用法与 showSnackBar 同构：`showPetToast(context, '文案', isError: true)`。
/// 宠物模块内一律用它替代 showSnackBar（调用点机械替换，文案不变）。
OverlayEntry? _toastEntry;
Timer? _toastTimer;
GlobalKey<_PetToastViewState>? _toastKey;

void showPetToast(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  if (!context.mounted) return;
  _removeEntry(); // 替换式：立即收起上一条（不做退出动画）
  final overlay = Overlay.of(context, rootOverlay: true);
  final key = GlobalKey<_PetToastViewState>();
  _toastKey = key;
  _toastEntry = OverlayEntry(
    builder: (_) => _PetToastView(
      key: key,
      message: message,
      isError: isError,
      isSuccess: isSuccess,
    ),
  );
  overlay.insert(_toastEntry!);
  _toastTimer = Timer(const Duration(milliseconds: 3000), dismissPetToast);
}

/// 提前收起当前宠物 Toast（若有；淡出动画结束后真正摘除）
void dismissPetToast() {
  _toastKey?.currentState?.fadeOut();
}

/// 真正摘除 OverlayEntry（幂等；替换式重入与淡出完成共用）
void _removeEntry() {
  _toastTimer?.cancel();
  _toastTimer = null;
  final entry = _toastEntry;
  _toastEntry = null;
  _toastKey = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _PetToastView extends StatefulWidget {
  const _PetToastView({
    super.key,
    required this.message,
    required this.isError,
    required this.isSuccess,
  });

  final String message;
  final bool isError;
  final bool isSuccess;

  @override
  State<_PetToastView> createState() => _PetToastViewState();
}

class _PetToastViewState extends State<_PetToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.6),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = _ctrl;

  bool _closing = false;

  /// 拖拽偏移（20261021 用户拍板：支持上划/右滑甩出移除；只允许向右或向上，
  /// 未达距离/速度阈值松手则弹回原位）
  Offset _drag = Offset.zero;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_closing) return; // 已在淡出（timer 到点等）不再跟手
    setState(() {
      _drag = Offset(
        (_drag.dx + d.delta.dx).clamp(0.0, double.infinity),
        (_drag.dy + d.delta.dy).clamp(double.negativeInfinity, 0.0),
      );
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_closing) return;
    // 快甩任意方向也视为移除意图（距离阈值只认右上,速度阈值不限方向）
    final fast = d.velocity.pixelsPerSecond.distanceSquared > 700 * 700;
    final far = _drag.dx > 60 || -_drag.dy > 48;
    if (fast || far) {
      fadeOut();
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      // identity 比对:替换式重入后本 state 已不属于当前 toast,
      // 不得摘除新 entry(20261021 审查 P3 竞态)
      if (status == AnimationStatus.dismissed &&
          _closing &&
          identical(_toastKey?.currentState, this)) {
        _removeEntry();
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 淡出并摘除（幂等：timer / 点击 / 替换式重入都只触发一次）
  void fadeOut() {
    if (_closing) return;
    _closing = true;
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.isError
        ? cs.error
        : (widget.isSuccess ? AppTheme.success : cs.primary);
    // 20261021 用户拍板：下移（原 +12 → +22 → +34 → +46 → 再 +4 = +50）
    final top = MediaQuery.paddingOf(context).top + 50;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            // 对齐原 SnackBar 的 liveRegion：读屏主动播报（复审批 P3）
            child: Semantics(
              liveRegion: true,
              button: true,
              onTap: dismissPetToast,
              child: GestureDetector(
                onTap: dismissPetToast,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                // 手势被系统打断(来电/抢 arena)时弹回原位,不留中途偏移
                onPanCancel: () => setState(() => _drag = Offset.zero),
                child: Transform.translate(
                  offset: _drag,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 宠物元素：爪印圆徽（随消息状态换色）
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pets, size: 15, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ), // Row
                  ), // Container
                ), // Transform.translate
              ), // GestureDetector
            ), // Semantics
          ), // Material
        ), // FadeTransition
      ), // SlideTransition
    ); // Positioned
  }
}
