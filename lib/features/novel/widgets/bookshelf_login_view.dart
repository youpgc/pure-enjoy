import 'package:flutter/material.dart';

/// 书架未登录视图
class BookshelfLoginView extends StatelessWidget {
  final VoidCallback onLogin;

  const BookshelfLoginView({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '请先登录后查看书架',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onLogin,
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}
