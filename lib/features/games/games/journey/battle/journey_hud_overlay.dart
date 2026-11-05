import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'journey_battle_controller.dart';
import '../widgets/journey_theme.dart';

/// 对局 HUD 覆盖层（组件化拆分，对局页只挂载）：
/// 左上=状态面板（血条/经验/状态行，半透明底板提升可读性）；
/// 左中=法宝槽栏（6 主动金框 + 6 被动蓝框，随 slotsRevision 重建）；
/// 右上=妖王罗盘（箭头指向据点+距离接近度）。
class JourneyHudOverlay extends StatelessWidget {
  const JourneyHudOverlay({super.key, required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          top: 8,
          left: 10,
          // 右侧预留罗盘列宽度（罗盘 58 + 距离文案 ~90，right:12 起），
          // 窄屏上面板与罗盘文案不重叠。
          right: 108,
          child: _HudPanel(controller: controller),
        ),
        Positioned(
          top: 132,
          left: 10,
          child: _SlotBar(controller: controller),
        ),
        Positioned(
          // 罗盘列在暂停按钮（top 4，高 ~44）下方，右上角纵向排布不重叠
          top: 54,
          right: 12,
          child: _Compass(controller: controller),
        ),
      ],
    );
  }
}

/// 左上状态面板：半透明深底 + 血条/经验条/状态行（字号加大）。
class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    final hud = controller.hud;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: JourneyTheme.panelStroke.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 血条
          ValueListenableBuilder<double>(
            valueListenable: hud.hp,
            builder: (context, hp, _) => ValueListenableBuilder<double>(
              valueListenable: hud.maxHp,
              builder: (context, maxHp, _) => _bar(
                hp / maxHp,
                const Color(0xFFE0604C),
                '❤ ${hp.round()}/${maxHp.round()}',
              ),
            ),
          ),
          const SizedBox(height: 5),
          // 经验条
          ValueListenableBuilder<double>(
            valueListenable: hud.exp,
            builder: (context, exp, _) => ValueListenableBuilder<double>(
              valueListenable: hud.expNeed,
              builder: (context, need, _) =>
                  _bar(exp / need, const Color(0xFFA37FE0), ''),
            ),
          ),
          const SizedBox(height: 5),
          // 状态行
          ValueListenableBuilder<int>(
            valueListenable: hud.kills,
            builder: (context, kills, _) => ValueListenableBuilder<int>(
              valueListenable: hud.meritCoins,
              builder: (context, coins, _) => ValueListenableBuilder<int>(
                valueListenable: hud.level,
                builder: (context, lv, _) => Text(
                  'Lv$lv · 击杀 $kills · 功德 $coins',
                  style: const TextStyle(
                    fontSize: 13,
                    color: JourneyTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double value, Color color, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            color: color,
          ),
        ),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: JourneyTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// 法宝槽栏：上排=武器维度槽 6（金框：维度名 + 等级角标——初始武器
/// 特效槽 + 习得维度）；下排=被动槽 6（蓝框，加持资源）。
/// slotsRevision 变化时重建。
class _SlotBar extends StatelessWidget {
  const _SlotBar({required this.controller});

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

  /// 维度槽：6 格，每格显示维度名（竖排两字）+ 右下角等级角标。
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
    final name = kJourneySlotNames[slot.code] ?? slot.code;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: JourneyTheme.gold, width: 1.6),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Text(
              name.length > 2 ? name.substring(0, 2) : name,
              style: const TextStyle(
                fontSize: 11,
                height: 1.0,
                color: JourneyTheme.textPrimary,
                fontWeight: FontWeight.w700,
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
}

/// 维度槽简称（HUD 空间有限，取两字简称；全名见维度定义表）。
const Map<String, String> kJourneySlotNames = <String, String>{
  'radius': '臂展',
  'speed': '转速',
  'damage': '伤害',
  'knockback': '击退',
  'lifesteal': '吸血',
  'pierce': '穿刺',
  'magnet': '磁吸',
  'burn': '灼烧',
};

/// 妖王罗盘：箭头指向妖王据点 + 距离接近度文案。
/// 无妖章回（hasBoss=false）：切换为坚持通关倒计时。
class _Compass extends StatelessWidget {
  const _Compass({required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.hud.hasBoss,
      builder: (context, hasBoss, _) => hasBoss
          ? _bossCompass(controller)
          : _surviveCountdown(controller),
    );
  }

  Widget _bossCompass(JourneyBattleController controller) {
    final hud = controller.hud;
    return ValueListenableBuilder<double>(
      valueListenable: hud.bearing,
      builder: (context, bearing, _) => ValueListenableBuilder<double>(
        valueListenable: hud.progress,
        builder: (context, near, _) => Column(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
                border: Border.all(
                    color: JourneyTheme.gold.withValues(alpha: 0.85),
                    width: 1.6),
              ),
              child: Transform.rotate(
                // navigation 图标默认朝上（-y），世界角 atan2 以 +x 为 0
                angle: bearing + math.pi / 2,
                child: const Icon(Icons.navigation,
                    color: JourneyTheme.gold, size: 28),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                near >= 0.99
                    ? '妖王就在此处'
                    : '距妖王 ${((1 - near) * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: JourneyTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 无妖章回：坚持满时长即功成（倒计时圆盘 + 剩余秒文案）。
  Widget _surviveCountdown(JourneyBattleController controller) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.hud.surviveLeft,
      builder: (context, left, _) => Column(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
              border: Border.all(
                  color: JourneyTheme.gold.withValues(alpha: 0.85),
                  width: 1.6),
            ),
            child: const Icon(Icons.hourglass_bottom,
                color: JourneyTheme.gold, size: 28),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '此难无妖 · 坚持 ${left}s',
              style: const TextStyle(
                fontSize: 11,
                color: JourneyTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
