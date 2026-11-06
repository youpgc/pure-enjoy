import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
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
    'clone': '分身',
    'crit_rate': '暴击',
    'crit_damage': '暴伤',
    'armor': '护甲',
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
      // 面板口径与实际伤害/角速度同源：damageMult（≤3.0 钳）与
      // displayAngularSpeed（2 圈/秒钳），见主类 getter
      _attrRow('武器伤害', '${(arm.damage * game.damageMult).toStringAsFixed(1)}/击'),
      _attrRow(
        '环绕转速',
        '${game.displayAngularSpeed.toStringAsFixed(1)}/秒 · '
        '${game.spinDirection < 0 ? '逆时针' : '顺时针'}',
      ),
      // 臂展做百分比展示（基准=屏幕最大宽-40，即左右各留 20px 空余）；
      // 内部 px 数值保留在括号里便于运营核对
      _attrRow(
        '武器臂展',
        '${game.maxArmDiameter > 0 ? ((arm.outerRadius * 2 / game.maxArmDiameter * 100).round()) : 0}%'
        '（直径 ${(arm.outerRadius * 2).round()} · 内圈 ${arm.innerRadius.round()}）',
      ),
      _attrRow('生命',
          '${controller.hud.hp.value.round()} / ${controller.hud.maxHp.value.round()}'),
      _attrRow('自动回复', '${game.player.regen.toStringAsFixed(1)}/秒'),
      _attrRow('护甲', '${game.player.armor.toStringAsFixed(1)}（减伤 '
          '${(JourneyDamageTickMixin.armorReductionRatio(game.player.armor) * 100).toStringAsFixed(0)}%）'),
      _attrRow('移动速度', '×${game.moveSpeedAmp.toStringAsFixed(2)}'),
      _attrRow('拾取范围', '${game.player.pickupRange.round()}'),
      _attrRow('经验获取', '×${game.expAmp.toStringAsFixed(2)}'),
      // 暴击与炼化（节点11/4）：暴击率/暴击伤害/炼化状态/特效法宝
      _attrRow('暴击率', '${(game.critRate * 100).toStringAsFixed(1)}%'),
      _attrRow('暴击伤害', '${(game.critDamage * 100).round()}%'),
      _attrRow('炼化状态', game.evolved ? '已炼化' : '未炼化'),
      _attrRow('特效法宝', _effectWeaponsText(game)),
      _attrRow('特殊能力', _abilitiesText(game)),
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

    // 打开属性详情主动暂停（已在暂停/选卡暂停中则保持原状），关闭后恢复
    final wasPaused = game.paused;
    if (!wasPaused) game.pauseEngine();
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
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
      ),
    );
    if (!wasPaused && !game.isPausedForLevelUp && !game.paused) {
      game.resumeEngine();
    }
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

  /// 特效法宝名单：配置表名字优先，缺省回落编码；空显示'未习得'。
  static String _effectWeaponsText(JourneyFlameGame game) {
    if (game.effectWeapons.isEmpty) return '未习得';
    final config = JourneyConfigService.instance.cached;
    return game.effectWeapons
        .map((c) => config?.weaponOf(c)?.name ?? c)
        .join('、');
  }

  /// 已解锁角色特殊能力名单（'ability_<char>' 标记 → 能力名）；
  /// 未解锁显示'未解锁'。
  static String _abilitiesText(JourneyFlameGame game) {
    if (game.abilities.isEmpty) return '未解锁';
    return game.abilities.map((code) {
      final char = code.startsWith('ability_') ? code.substring(8) : '';
      return kJourneyCharAbilities[char]?.$1 ?? code;
    }).join('、');
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
