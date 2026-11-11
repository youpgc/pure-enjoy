import 'dart:async';

import 'package:flutter/material.dart';

import 'journey_loading.dart';
import 'journey_theme.dart';

/// 交互等待遮罩：异步操作超过阈值仍在进行时覆盖页面，展示西行 loading
/// 并拦截重复点击；操作很快结束时不插入遮罩，避免闪烁。
abstract final class JourneyBusy {
  static Future<T> run<T>(
    BuildContext context,
    Future<T> Function() task, {
    String label = '处理中…',
    Duration delay = const Duration(milliseconds: 120),
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return task();

    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: <Widget>[
          const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: JourneyTheme.bgDeep.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: JourneyTheme.gold, width: 1.2),
              ),
              child: JourneyLoading(label: label, size: 48),
            ),
          ),
        ],
      ),
    );
    var inserted = false;
    var finished = false;
    final timer = Timer(delay, () {
      if (finished) return;
      try {
        overlay.insert(entry);
        inserted = true;
      } catch (_) {
        // 页面已退出时 Overlay 随之销毁，无需再展示
      }
    });
    try {
      return await task();
    } finally {
      finished = true;
      timer.cancel();
      if (inserted && entry.mounted) entry.remove();
    }
  }
}
