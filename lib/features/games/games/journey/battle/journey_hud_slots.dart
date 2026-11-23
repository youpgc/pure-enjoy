import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/journey_theme.dart';
import '../services/journey_config_service.dart';
import 'journey_battle_controller.dart';
import 'journey_sprites.dart';

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
        return ValueListenableBuilder<Map<String, JourneySlotCooldown>>(
          valueListenable: controller.hud.slotCooldowns,
          builder: (context, cooldowns, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _dimensionRow(controller.activeSlots, cooldowns),
              const SizedBox(height: 4),
              _slotRow(
                  controller.passiveSlots, const Color(0xFF7FA8E0), cooldowns),
            ],
          ),
        );
      },
    );
  }

  /// 维度槽：6 格，每格显示维度图标 + 右下角等级角标。
  Widget _dimensionRow(
      List<JourneyWeaponSlot> slots, Map<String, JourneySlotCooldown> cooldowns) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: i < slots.length
                ? _dimensionSlot(slots[i], cooldowns[slots[i].code])
                : _emptySlot(JourneyTheme.gold),
          ),
      ],
    );
  }

  Widget _dimensionSlot(JourneyWeaponSlot slot, JourneySlotCooldown? cd) {
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
              JourneySprites.slotIcon(slot.code),
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
          // 计时类维度槽（回元/护体）：顺时针蒙层 + 居中秒数倒计时
          if (cd != null) _cooldownOverlay(cd),
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

  Widget _slotRow(List<String> codes, Color stroke,
      Map<String, JourneySlotCooldown> cooldowns) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: i < codes.length
                ? _filledSlot(codes[i], stroke, cooldowns[codes[i]])
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

  Widget _filledSlot(String code, Color stroke, JourneySlotCooldown? cd) {
    // 计时类被动槽冷却中：暗边框 + 顺时针蒙层 + 居中秒数倒计时
    final cooling = cd != null;
    final icon = SvgPicture.asset(
      JourneySprites.weapon(code),
      width: 22,
      height: 22,
      errorBuilder: (_, __, ___) => Icon(
        Icons.auto_awesome,
        color: stroke,
        size: 16,
      ),
    );
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: cooling ? stroke.withValues(alpha: 0.4) : stroke,
          width: 1.6,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(child: icon),
          if (cd != null) _cooldownOverlay(cd),
        ],
      ),
    );
  }

  /// 计时槽时钟蒙层：缺口自 12 点起顺时针扩展，剩余部分以半透明扇形压暗，
  /// 圆心叠加剩余整秒文案。progress=剩余/周期，随倒计时推进蒙层收缩至消失。
  Widget _cooldownOverlay(JourneySlotCooldown cd) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(painter: _CooldownPainter(cd.progress)),
            ),
            Center(
              child: Text(
                '${cd.secs}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  color: Color(0xFFFF9B7A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
      'crit_rate': '暴击',
      'crit_damage': '暴伤',
      'armor': '护甲',
      'vitality': '生机',
      'cloud': '腾云',
      'ward': '金刚',
      'recovery': '回元',
      'shield': '护体',
      'slow': '缚灵',
    };
    final name = names[code] ?? code;
    return name.length > 2 ? name.substring(0, 2) : name;
  }
}

/// 时钟冷却扇形蒙层：缺口自 12 点（−90°）起顺时针扩展 (1-progress)×360°，
/// 剩余 progress×360° 为蒙层压暗槽图标；半径取槽对角线确保覆盖到四角，外层 ClipRRect 裁圆角。
class _CooldownPainter extends CustomPainter {
  const _CooldownPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width * math.sqrt2;
    // 缺口随倒计时从 12 点顺时针扩大，蒙层始终终止于 12 点。
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (1 - progress) * math.pi * 2,
      progress * math.pi * 2,
      true,
      Paint()..color = const Color(0x99000000),
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
