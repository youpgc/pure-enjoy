import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/journey_theme.dart';
import '../services/journey_config_service.dart';
import 'journey_battle_controller.dart';

/// 法宝槽栏（HUD 覆盖层子组件，独立文件避免主文件超行限）：
/// 上排=武器维度槽 6（金框：维度图标 + 等级角标——初始武器特效槽 +
/// 习得维度）；下排=被动槽 6（蓝框，加持资源）。
/// slotsRevision 变化时重建。
class JourneyHudSlotBar extends StatelessWidget {
  const JourneyHudSlotBar({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.hud.slotsRevision,
      builder: (context, _, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _dimensionRow(controller.activeSlots),
            const SizedBox(height: 4),
            _slotRow(controller.passiveSlots, const Color(0xFF7FA8E0)),
          ],
        );
      },
    );
  }

  /// 维度槽：6 格，每格显示维度图标 + 右下角等级角标。
  Widget _dimensionRow(List<JourneyWeaponSlot> slots) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: i < slots.length
                ? _dimensionSlot(slots[i])
                : _emptySlot(JourneyTheme.gold),
          ),
      ],
    );
  }

  Widget _dimensionSlot(JourneyWeaponSlot slot) {
    // 满级判定：journey_weapon_slots.max_level 配置驱动（缺省回落 9）
    final maxLv =
        JourneyConfigService.instance.cached?.slotDefMap()[slot.code]?.maxLevel ?? 9;
    final isMax = slot.level >= maxLv;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isMax ? const Color(0xFFE8C470) : JourneyTheme.gold,
          width: 1.6,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: SvgPicture.asset(
              'assets/games/journey/icon_slot_${slot.code}.svg',
              width: 16,
              height: 16,
              // 图标缺失回落两字简称，槽位语义不丢
              errorBuilder: (_, __, ___) => Text(
                _slotAbbr(slot.code),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  color: JourneyTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // 满级标识：左下角 max（槽位达上限，不再出现在三选一）
          if (isMax)
            const Positioned(
              left: 1,
              bottom: 0,
              child: Text(
                'max',
                style: TextStyle(
                  fontSize: 8,
                  height: 1.0,
                  color: Color(0xFFE8C470),
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Positioned(
            right: 1,
            bottom: 0,
            child: Text(
              '${slot.level}',
              style: const TextStyle(
                fontSize: 9,
                height: 1.0,
                color: JourneyTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotRow(List<String> codes, Color stroke) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: i < codes.length
                ? _filledSlot(codes[i], stroke)
                : _emptySlot(stroke),
          ),
      ],
    );
  }

  Widget _emptySlot(Color stroke) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: stroke.withValues(alpha: 0.35), width: 1),
      ),
    );
  }

  Widget _filledSlot(String code, Color stroke) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: stroke, width: 1.6),
      ),
      child: SvgPicture.asset(
        'assets/games/journey/weapon_$code.svg',
        width: 22,
        height: 22,
        errorBuilder: (_, __, ___) => Icon(
          Icons.auto_awesome,
          color: stroke,
          size: 16,
        ),
      ),
    );
  }

  /// 维度槽简称（SVG 缺失回落用，取两字简称；全名见维度定义表）。
  String _slotAbbr(String code) {
    const names = <String, String>{
      'radius': '臂展',
      'speed': '转速',
      'damage': '伤害',
      'knockback': '击退',
      'lifesteal': '吸血',
      'pierce': '穿刺',
      'magnet': '磁吸',
      'burn': '灼烧',
      'clone': '分身',
    };
    final name = names[code] ?? code;
    return name.length > 2 ? name.substring(0, 2) : name;
  }
}
