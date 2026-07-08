import 'package:flutter/material.dart';
import '../../../../services/supabase_service.dart';

/// 欢迎区块组件
///
/// 展示用户欢迎语和用户名，属于纯展示型组件。
class WelcomeSection extends StatelessWidget {
  const WelcomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎回来',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.instance.currentUserName ?? '用户',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '今天想做些什么？',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
