import 'package:flutter/material.dart';

import 'journey_attributes_data.dart';
import 'journey_flame_game.dart';
import '../widgets/journey_theme.dart';

/// 属性详情面板：由对局页先进入暂停态再展示，面板不改变引擎运行状态。
/// 取值与历史对局详情共用 [JourneyAttributesData]，避免两处格式化漂移。
abstract final class JourneyAttributesSheet {
  static Future<void> show(
    BuildContext context, {
    required JourneyFlameGame game,
  }) async {
    final groups = JourneyAttributesData.collect(game);
    final rows = <Widget>[
      for (final group in groups) ...<Widget>[
        Text(group.title, style: JourneyTheme.title),
        const SizedBox(height: 6),
        for (final row in group.rows) _attrRow(row.$1, row.$2),
        const SizedBox(height: 12),
      ],
    ];
    if (rows.isNotEmpty) rows.removeLast();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: JourneyTheme.bgDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: JourneyTheme.panelStroke),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 把手：置于面板容器内（默认把手浮在弹窗外）
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: JourneyTheme.gold.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('属 性 详 情', style: JourneyTheme.titleLg),
              const SizedBox(height: 6),
              Text(
                '${game.character.name} · Lv${game.controller.hud.level.value}',
                style: JourneyTheme.caption,
              ),
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _attrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 108, child: Text(label, style: JourneyTheme.body)),
          Expanded(child: Text(value, style: JourneyTheme.caption)),
        ],
      ),
    );
  }
}
