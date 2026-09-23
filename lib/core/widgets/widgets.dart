import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 通用加载组件
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!),
          ],
        ],
      ),
    );
  }
}

/// 空状态组件
class EmptyWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyWidget({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 错误状态组件
class ErrorWidget extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onRetry;

  const ErrorWidget({
    super.key,
    required this.message,
    this.actionText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 确认对话框
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 全局轻提示（SnackBar 唯一入口）。
///
/// [isError] 红底（走主题 error 色）、[isSuccess] 绿底（[AppTheme.success]），
/// 两者都不传即默认底色。异步回调里直接调用是安全的：上下文已销毁时静默丢弃，
/// 不再抛 setState/dependents 相关异常。
void showSnackBar(BuildContext context, String message,
    {bool isError = false, bool isSuccess = false}) {
  if (!context.mounted) return;
  final colorScheme = Theme.of(context).colorScheme;
  final backgroundColor =
      isSuccess ? AppTheme.success : (isError ? colorScheme.error : null);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
    ),
  );
}

/// 异步提交按钮：自带 loading 状态与防重复提交（防抖）。
///
/// 将异步提交逻辑（含表单校验）传入 [onPressed]，按钮在首次点击后显示
/// 圆形进度指示器并禁用自身；进行中忽略后续点击，请求结束（成功/失败）后
/// 自动复位。父组件无需再维护 isSubmitting / isSaving 之类布尔位。
///
/// 典型用法：
/// ```dart
/// AsyncSubmitButton(
///   label: '保存',
///   onPressed: _save,            // Future<void> Function()，内部含 validate + 网络请求
/// )
/// ```
///
/// [onPressed] 为 null 时按钮禁用（如表单未完成）。[fullWidth] 控制是否撑满宽度。
/// 异步逻辑若提前返回（如校验失败），按钮不会出现可见的 loading 闪烁。
class AsyncSubmitButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String label;
  final bool fullWidth;
  final double? height;

  const AsyncSubmitButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.fullWidth = true,
    this.height,
  });

  @override
  State<AsyncSubmitButton> createState() => _AsyncSubmitButtonState();
}

class _AsyncSubmitButtonState extends State<AsyncSubmitButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    // 防抖：进行中直接忽略后续点击，杜绝慢网络下的重复提交
    if (_isLoading) return;
    final handler = widget.onPressed;
    if (handler == null) return;

    setState(() => _isLoading = true);
    try {
      await handler();
    } finally {
      // 卸载后不再 setState，避免对已销毁组件调用（如提交成功后 Navigator.pop）
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonChild = _isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(widget.label);

    final button = FilledButton(
      // 进行中禁用按钮（视觉置灰 + 屏蔽点击），与内部防抖双保险
      onPressed: _isLoading ? null : _handleTap,
      child: buttonChild,
    );

    if (widget.fullWidth) {
      return SizedBox(
        width: double.infinity,
        height: widget.height,
        child: button,
      );
    }
    return button;
  }
}

/// 底部弹层（showModalBottomSheet）统一内容容器。
///
/// 解决两类历史兼容问题（2026-09-14 容器审查）：
/// 1. **键盘**：BottomSheet 无自动避让，必须手动按 `viewInsets.bottom` 抬升；
/// 2. **手势条**：旧写法 `viewInsets.bottom + 常数` 在键盘收起后把手势导航条
///    （home indicator）高度算丢，底部按钮被遮挡。SafeArea 在键盘弹出时
///    bottom 会随 `padding = viewPadding - viewInsets` 自动归零（键盘本身盖住
///    手势条），收起后恢复——因此「viewInsets + SafeArea」组合在两种状态下都正确。
///
/// 结构：
/// ```
/// Padding(bottom: viewInsets.bottom)   ← 键盘抬升（无键盘时为 0）
/// └─ SafeArea(top: false)              ← 手势条高度（键盘弹出时自动归零）
///    └─ [ConstrainedBox(maxHeightFactor)]
///       └─ [SingleChildScrollView]     ← scrollable=false 时省略（内容自带滚动）
///          └─ child
/// ```
///
/// 用法：弹层 builder 直接返回本组件（调用方仍需 `isScrollControlled: true`）：
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => SheetContainer(child: Column(mainAxisSize: MainAxisSize.min, ...)),
/// );
/// ```
class SheetContainer extends StatelessWidget {
  final Widget child;

  /// 内容内边距；底部不在此设置，统一由 [bottomSpacing] 追加在 SafeArea 之内
  final EdgeInsetsGeometry padding;

  /// 内容与底部安全区之间的间距（键盘弹出时同样生效，压在键盘上方）
  final double bottomSpacing;

  /// 内容最大高度占屏幕比例（如 0.85）；null = 不限制，由内容 + 滚动兜底
  final double? maxHeightFactor;

  /// 内容是否包 SingleChildScrollView；内容自带 ListView（如选关列表、
  /// DraggableScrollableSheet）时传 false，避免嵌套滚动冲突
  final bool scrollable;

  /// 透传给内部 SingleChildScrollView 的控制器（scrollable=true 时生效）
  final ScrollController? scrollController;

  const SheetContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.bottomSpacing = 16,
    this.maxHeightFactor,
    this.scrollable = true,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final contentPadding = padding.add(EdgeInsets.only(bottom: bottomSpacing));
    Widget content = SingleChildScrollView(
      controller: scrollController,
      padding: contentPadding,
      child: child,
    );
    if (!scrollable) {
      content = Padding(
        padding: contentPadding,
        child: child,
      );
    }
    final factor = maxHeightFactor;
    if (factor != null) {
      // 键盘弹出时父级可用高度 (屏高 - 键盘) 小于该约束，父级约束优先生效，
      // 内容靠内部滚动保证完整可达——不会溢出
      content = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * factor,
        ),
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(top: false, child: content),
    );
  }
}
