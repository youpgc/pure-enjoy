import 'package:flutter/material.dart';

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

/// 显示 SnackBar
void showSnackBar(BuildContext context, String message, {bool isError = false}) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? colorScheme.error : null,
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
