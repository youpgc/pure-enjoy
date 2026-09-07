import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

/// 游戏模块统一的「局部加载」占位：内容区小 spinner + 文案。
///
/// 规范（2026-09-07）：游戏模块内禁止整页 loading——页面骨架（AppBar/头部卡）
/// 必须立即渲染，数据区域用本组件占位等待。
class GameLocalLoading extends StatelessWidget {
  /// 加载文案（如「模式加载中…」「积分结算中…」）
  final String label;

  const GameLocalLoading({super.key, this.label = '加载中…'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 12),
            Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AppTheme.neutral500)),
          ],
        ),
      ),
    );
  }
}
