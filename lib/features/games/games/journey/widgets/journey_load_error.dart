import 'package:flutter/material.dart';

import '../../../../../services/error_reporter.dart';
import 'journey_theme.dart';
import 'journey_widgets.dart';

/// 配置/进度加载失败兜底：沿用游戏内主题，提供手动重试入口。
class JourneyLoadError extends StatelessWidget {
  const JourneyLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('加载失败，请检查网络后重试', style: JourneyTheme.body),
          const SizedBox(height: 12),
          JourneyButton(text: '重 试', onTap: onRetry),
        ],
      ),
    );
  }
}

/// 页面加载异常统一上报，避免各页各写一套日志。
void reportJourneyLoadError(Object error, StackTrace stack) {
  ErrorReporter.report(error, stack, module: 'games.journey');
}
