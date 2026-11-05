import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_seed.dart';
import 'journey_flame_game.dart';
import '../widgets/journey_theme.dart';

/// 属性详情面板（暂停时查看）：基础战斗属性 + 武器维度槽（等级/上限/
/// 每级效果）+ 被动加持——玩家当前强度的完整视图。
abstract final class JourneyAttributesSheet {
  /// 维度槽简称（HUD/面板空间有限，取两字简称；全名见维度定义表）。
  static const Map<String, String> slotNames = <String, String>{
    'radius': '臂展',
    'speed': '转速',
    'damage': '伤害',
    'knockback': '击退',
    'lifesteal': '吸血',
    'pierce': '穿刺',
    'magnet': '磁吸',
    'burn': '灼烧',
  };

  static Future<void> show(
    BuildContext context, {
    required JourneyFlameGame game,
  }) async {
    final arm = game.weaponArm;
    if (arm == null) return;
    final controller = game.controller;
    final defs = _slotDefs();

    final rows = <Widget>[];
    rows.addAll(<Widget>[
      const Text('基础属性', style: JourneyTheme.title),
      const SizedBox(height: 6),
      _attrRow('武器伤害', '${(arm.damage * game.damageAmp).toStringAsFixed(1)}/击'),
      _attrRow('环绕转速', '${(arm.speedBase * game.spinAmp).toStringAsFixed(1)}/秒'),
      _attrRow('武器臂长', '${arm.outerRadius.round()}（内圈 ${arm.innerRadius.round()}）'),
      _attrRow('生命',
          '${controller.hud.hp.value.round()} / ${controller.hud.maxHp.value.round()}'),
      _attrRow('自动回复', '${game.player.regen.toStringAsFixed(1)}/秒'),
      _attrRow('移动速度', '×${game.moveSpeedAmp.toStringAsFixed(2)}'),
      _attrRow('拾取范围', '${game.player.pickupRange.round()}'),
    ]);
    rows.add(const SizedBox(height: 12));

    rows.addAll(<Widget>[
      const Text('武器维度槽', style: JourneyTheme.title),
      const SizedBox(height: 6),
      for (final slot in game.weaponSlots)
        _attrRow(
          '${slotNames[slot.code] ?? slot.code} · Lv${slot.level}'
          '/${defs[slot.code]?.maxLevel ?? 3}',
          defs[slot.code]?.effectPerLevel ?? '',
        ),
      if (game.weaponSlots.length < 6)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '空槽 ${6 - game.weaponSlots.length} 格 · 三选一可习得新维度',
            style: JourneyTheme.faint,
          ),
        ),
    ]);
    rows.add(const SizedBox(height: 12));

    if (game.passiveSlotCodes.isNotEmpty) {
      rows.addAll(<Widget>[
        const Text('被动加持', style: JourneyTheme.title),
        const SizedBox(height: 6),
        for (final code in game.passiveSlotCodes)
          _attrRow(
            kJourneyPassiveEffects[code]?.$1 ?? code,
            kJourneyPassiveEffects[code]?.$2 ?? '',
          ),
      ]);
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
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
              const Text('属 性 详 情', style: JourneyTheme.titleLg),
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, JourneySlotDefModel> _slotDefs() {
    final remote =
        JourneyConfigService.instance.cached?.slotDefMap();
    if (remote != null && remote.isNotEmpty) return remote;
    return <String, JourneySlotDefModel>{
      for (final d in kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson))
        d.code: d,
    };
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
