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
      // 只要已插入就移除，不得以 entry.mounted 作为门槛：mounted 在本 SDK
      // 语义为「条目 State 已构建」而非「已插入」，插入后首帧构建前仍为
      // false——任务恰在插入与首帧构建之间完成时会跳过移除，遮罩永久残留
      // （rootOverlay 级、跨页面不消失）。remove() 对未构建条目安全：仅从
      // _entries 移除并标记脏重建，不会触碰未挂载的 State。
      if (inserted) {
        try {
          entry.remove();
        } catch (_) {
          // 极端时序下条目已被 Overlay 自行回收，无需处理
        }
      }
    }
  }
}
