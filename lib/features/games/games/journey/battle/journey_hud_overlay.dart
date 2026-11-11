import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'journey_battle_controller.dart';
import 'journey_hud_slots.dart';
import 'journey_hud_widgets.dart';
import '../widgets/journey_theme.dart';

/// 对局 HUD 覆盖层（组件化拆分，对局页只挂载）：
/// 左上=状态面板（角色头像 + 血条/经验/状态行，半透明底板；点按弹属性详情）；
/// 左中=法宝槽栏（见 journey_hud_slots.dart，slotsRevision 变化重建）；
/// 右上=妖王罗盘（箭头指向据点+距离接近度）。
class JourneyHudOverlay extends StatelessWidget {
  const JourneyHudOverlay({
    super.key,
    required this.controller,
    required this.characterCode,
    this.onTopPanelTap,
  });

  final JourneyBattleController controller;

  /// 当前出战角色 code（顶部头像取 char_<code>.svg）。
  final String characterCode;

  /// 顶部状态面板点按回调（对局页弹属性详情面板）。
  final VoidCallback? onTopPanelTap;

  // 槽栏几何常量：血条定位引用，槽栏行高调整只改这里防错位
  static const double _kSlotBarTop = 132;
  static const double _kSlotBarHeight = 64; // 两行 30px 槽 + 4px 行距
  static const double _kBossBarGap = 40; // 血条与槽栏间距

  @override
  Widget build(BuildContext context) {
    // 状态栏与摄像头挖孔区不画 HUD：整块内容下移安全区高度，内部相对间距不变
    final safeTop = MediaQuery.of(context).viewPadding.top;
    return Stack(
      children: <Widget>[
        Positioned(
          top: safeTop + 8,
          left: 10,
          // 信息栏自适应宽度：右缘与右侧小地图列（132+12）保持 20px 间距
          right: 164,
          child: GestureDetector(
            onTap: onTopPanelTap,
            child: _HudPanel(
              controller: controller,
              characterCode: characterCode,
            ),
          ),
        ),
        Positioned(
          top: safeTop + _kSlotBarTop,
          left: 10,
          child: JourneyHudSlotBar(controller: controller),
        ),
        // 妖王大血条：6+6 槽栏正下方 40px，水平居中，宽 81% 屏
        Positioned(
          top: safeTop + _kSlotBarTop + _kSlotBarHeight + _kBossBarGap,
          left: 0,
          right: 0,
          child: Center(child: JourneyBossHpBar(controller: controller)),
        ),
        // 小地图点阵窗：右上角（原罗盘位）；罗盘移至其正下方
        Positioned(
          top: safeTop + 8,
          right: 12,
          child: JourneyMinimapWindow(controller: controller),
        ),
        // 对局横幅（节点11）：开场难名/妖王降临/里程碑共用位
        JourneyBattleBanner(controller: controller),
        // 等待接管摇杆：世界仍时停，提示玩家按下即继续
        ValueListenableBuilder<bool>(
          valueListenable: controller.hud.awaitingJoystick,
          builder: (context, waiting, _) => waiting
              ? const Align(
                  alignment: Alignment(0, 0.2),
                  child: IgnorePointer(
                    child: Text(
                      '拖动摇杆 · 继续战斗',
                      style: TextStyle(
                        fontSize: 13,
                        color: JourneyTheme.gold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Positioned(
          // 罗盘在小地图（132 高 + 上下间距）正下方
          top: safeTop + 150,
          right: 12,
          child: _Compass(controller: controller),
        ),
      ],
    );
  }
}

/// 左上状态面板：角色头像（圆形裁剪）+ 血条/经验条/状态行。
class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.controller, required this.characterCode});

  final JourneyBattleController controller;
  final String characterCode;

  @override
  Widget build(BuildContext context) {
    final hud = controller.hud;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 7),
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: JourneyTheme.panelStroke.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _avatar(),
          const SizedBox(width: 6),
          Expanded(
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
                // 经验条（两段式动画：升级先充满再归零，见引擎 exp part；
                // expReset 变化时按新 key 重建 TweenAnimationBuilder——
                // 重建即落位，避免「从满倒退」的反向 tween）
                ValueListenableBuilder<int>(
                  valueListenable: hud.expReset,
                  builder: (context, reset, _) =>
                      ValueListenableBuilder<double>(
                    valueListenable: hud.exp,
                    builder: (context, exp, _) =>
                        ValueListenableBuilder<double>(
                      valueListenable: hud.expNeed,
                      builder: (context, need, _) => _bar(
                        exp / need,
                        const Color(0xFFA37FE0),
                        '',
                        animKey: ValueKey<int>(reset),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // 状态行（面板收窄至 132 后文案等比缩放防溢出）
                ValueListenableBuilder<int>(
                  valueListenable: hud.kills,
                  builder: (context, kills, _) => ValueListenableBuilder<int>(
                    valueListenable: hud.meritCoins,
                    builder: (context, coins, _) => ValueListenableBuilder<int>(
                      valueListenable: hud.level,
                      builder: (context, lv, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 出战角色头像：char_<code>.svg 圆形裁剪；缺失回落人形占位图标。
  Widget _avatar() {
    return ClipOval(
      child: Container(
        width: 30,
        height: 30,
        color: Colors.black.withValues(alpha: 0.35),
        child: SvgPicture.asset(
          'assets/games/journey/char_$characterCode.svg',
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.person,
            size: 20,
            color: JourneyTheme.gold,
          ),
        ),
      ),
    );
  }

  /// 进度条：TweenAnimationBuilder 300ms 缓动到目标值，
  /// 升级/拾取经验与受击掉血均平滑过渡不跳变；
  /// [animKey] 变化时重建（新 State 直接落位到 end 值，无反向动画）。
  Widget _bar(double value, Color color, String label, {Key? animKey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            key: animKey,
            tween: Tween<double>(end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              color: color,
            ),
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

/// 妖王罗盘：箭头指向妖王据点 + 距离接近度文案；无有效引导信息时整块隐藏。
/// 无妖章回（hasBoss=false）：切换为坚持通关倒计时。
class _Compass extends StatelessWidget {
  const _Compass({required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.hud.hasBoss,
      builder: (context, hasBoss, _) => hasBoss
          ? ValueListenableBuilder<bool>(
              // 妖王未降临时没有可导航的目标，整块隐藏
              valueListenable: controller.hud.bossPresent,
              builder: (context, present, _) => !present
                  ? const SizedBox.shrink()
                  : ValueListenableBuilder<bool>(
                      // 清剿结束（末场伏诛/坚持功成）：移除妖王距离导航；
                      // 多场战（三打白骨精等）重生期间 bossDefeated 未置位，
                      // 导航保持指向，全部击败才消失。
                      valueListenable: controller.hud.bossDefeated,
                      builder: (context, defeated, _) => defeated
                          ? const SizedBox.shrink()
                          : _bossCompass(controller),
                    ),
            )
          : _surviveCountdown(controller),
    );
  }

  Widget _bossCompass(JourneyBattleController controller) {
    final hud = controller.hud;
    return ValueListenableBuilder<double>(
      valueListenable: hud.bearing,
      builder: (context, bearing, _) => ValueListenableBuilder<double>(
        valueListenable: hud.progress,
        builder: (context, near, _) => ValueListenableBuilder<double>(
          valueListenable: hud.bossStartDist,
          builder: (context, startDist, _) {
            // 距妖王（里）= 接近度缺口 × 出生点基准距离 ÷ 25
            // （1 里=25 世界单位；同屏内数值收敛到个位十里，消除
            // 「同屏却显示 200 里」的观感失真）
            final dist =
                ((1 - near) * startDist).clamp(0.0, double.infinity);
            final li = dist / 25.0;
            return Column(
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
                    // 距离分层：同屏内（<420 单位≈17 里）只提示临近，不显里数
                    li <= 0.05
                        ? '已抵据点'
                        : dist < 420
                            ? '妖王就在附近'
                            : '距妖王 ${li.toStringAsFixed(li < 10 ? 1 : 0)} 里',
                    style: const TextStyle(
                      fontSize: 11,
                      color: JourneyTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 无妖章回：坚持满时长即功成（倒计时圆盘 + 剩余秒文案）；
  /// 倒计时归零后整块隐藏；无尽妖潮（endlessWave>0）：同位展示当前波数。
  Widget _surviveCountdown(JourneyBattleController controller) {
    final hud = controller.hud;
    return ValueListenableBuilder<int>(
      valueListenable: hud.endlessWave,
      builder: (context, wave, _) => wave > 0
          ? _endlessWaveView(wave)
          : ValueListenableBuilder<int>(
              valueListenable: hud.surviveLeft,
              builder: (context, left, _) =>
                  left <= 0 ? const SizedBox.shrink() : _surviveView(left),
            ),
    );
  }

  Widget _surviveView(int left) {
    return Column(
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
    );
  }

  /// 无尽妖潮罗盘位：波数徽标 + 当前波文案（波间休整/刷怪节奏见 spawns part）。
  Widget _endlessWaveView(int wave) {
    return Column(
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
          child: const Icon(Icons.waves, color: JourneyTheme.gold, size: 28),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '妖潮 · 第 $wave 波',
            style: const TextStyle(
              fontSize: 11,
              color: JourneyTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
