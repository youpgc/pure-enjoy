import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journey_battle_controller.dart';
import 'journey_hud_panel.dart';
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

  // HUD 顶部几何：面板与小地图同高同顶边，槽栏、罗盘、面板右缘都由
  // 小地图边长推导，调整边长时不会漏改某个相对位置。
  static const double _kTopInset = 8;
  static const double _kMinimapRight = 12;
  static const double _kPanelGap = 20;
  static const double _kCompassGap = 10;
  static const double _kSlotBarPanelGap = 10; // 槽栏与面板上下间距
  static const double _kSlotBarTop =
      _kTopInset + JourneyMinimapWindow.size + _kSlotBarPanelGap;
  static const double _kSlotBarHeight = 64; // 两行 30px 槽 + 4px 行距
  static const double _kBossBarGap = 40; // 血条与槽栏间距

  @override
  Widget build(BuildContext context) {
    // 状态栏与摄像头挖孔区不画 HUD：整块内容下移安全区高度，内部相对间距不变
    final safeTop = MediaQuery.of(context).viewPadding.top;
    return Stack(
      children: <Widget>[
        Positioned(
          top: safeTop + _kTopInset,
          left: 10,
          // 信息栏自适应宽度：右缘与小地图列保持固定间距
          right: _kMinimapRight + JourneyMinimapWindow.size + _kPanelGap,
          child: GestureDetector(
            onTap: onTopPanelTap,
            child: JourneyHudPanel(
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
          top: safeTop + _kTopInset,
          right: _kMinimapRight,
          child: JourneyMinimapWindow(controller: controller),
        ),
        // 对局横幅（节点11）：开场难名/妖王降临/里程碑共用位
        JourneyBattleBanner(controller: controller),
        Positioned(
          // 罗盘紧贴小地图下沿，间距由顶部几何常量推导
          top: safeTop +
              _kTopInset +
              JourneyMinimapWindow.size +
              _kCompassGap,
          right: _kMinimapRight,
          child: _Compass(controller: controller),
        ),
        // 等待接管摇杆：世界仍时停，半透明蒙层聚焦注意力 + 引导文案，
        // 提示玩家移动摇杆即可继续；整块 IgnorePointer 确保手势穿透到下层摇杆控件。
        ValueListenableBuilder<bool>(
          valueListenable: controller.hud.awaitingJoystick,
          builder: (context, waiting, _) => waiting
              ? Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: <Widget>[
                        // 蒙层：暗化世界、突出引导（手势穿透，不拦截摇杆）
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        // 居中偏下引导内容（避开顶部状态/血条区）
                        const Align(
                          alignment: Alignment(0, 0.18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.gamepad,
                                size: 44,
                                color: JourneyTheme.goldSoft,
                              ),
                              SizedBox(height: 14),
                              Text(
                                '移动即可继续游戏',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: JourneyTheme.gold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '按住并推动左下角虚拟摇杆',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: JourneyTheme.textSecondary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 妖王罗盘：箭头指向妖王据点 + 距离接近度文案；无有效引导信息时整块隐藏。
/// 无妖章回（hasBoss=false）：每日游历不展示通关条件/提示（进图即亮「功成」、
/// 随时可结算）；无妖主线章回=西行里程。
class _Compass extends StatelessWidget {
  const _Compass({required this.controller});

  final JourneyBattleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.hud.hasBoss,
      builder: (context, hasBoss, _) => hasBoss
          ? ValueListenableBuilder<bool>(
              valueListenable: controller.hud.bossPresent,
              builder: (context, present, _) => present
                  ? ValueListenableBuilder<bool>(
                      // 清剿结束（末场伏诛/西行功成）：移除妖王距离导航；
                      // 多场战（三打白骨精等）重生期间 bossDefeated 未置位，
                      // 导航保持指向，全部击败才消失。
                      valueListenable: controller.hud.bossDefeated,
                      builder: (context, defeated, _) => defeated
                          ? const SizedBox.shrink()
                          : _bossCompass(controller),
                    )
                  : ValueListenableBuilder<int>(
                      valueListenable: controller.hud.bossSpawnIn,
                      builder: (context, left, _) => left > 0
                          ? _bossSpawnCountdownView(left)
                          : const SizedBox.shrink(),
                    ),
            )
          // 无尽妖潮 hasBoss=false：妖王补位倒计时与波数共用罗盘位，
          // 倒计时优先，避免降临提示被波数分支吞掉。
          : ValueListenableBuilder<int>(
              valueListenable: controller.hud.bossSpawnIn,
              builder: (context, left, _) => left > 0
                  ? _bossSpawnCountdownView(left)
                  : _surviveCountdown(controller),
            ),
    );
  }

  Widget _bossCompass(JourneyBattleController controller) {
    final hud = controller.hud;
    return ValueListenableBuilder<double>(
      valueListenable: hud.bearing,
      builder: (context, bearing, _) => ValueListenableBuilder<double>(
        valueListenable: hud.bossDistWorld,
        builder: (context, distWorld, _) {
          // 距妖王（里）= 实际距离 ÷ 25（1 里=25 世界单位）。
          // 不经接近度反推：玩家绕路时离妖王可能比出生基准更远，
          // 接近度钳 0 会把文案钉死在基准里数不再更新。
          final li = distWorld / 25.0;
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
                      : distWorld < 420
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
    );
  }

  /// 罗盘位通用「圆盘 + 徽标文案」视图：妖王降临倒计时/游历倒计时/
  /// 西行里程/无尽波数多处同构展示的唯一实现。
  Widget _radarBadge(IconData icon, String text) {
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
                color: JourneyTheme.gold.withValues(alpha: 0.85), width: 1.6),
          ),
          child: Icon(icon, color: JourneyTheme.gold, size: 28),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
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

  /// 妖王降临倒计时（首次降临与多场战复活共用）：完整倒计时常显，
  /// 归零复活后由引擎置 0 自然隐藏。
  Widget _bossSpawnCountdownView(int left) =>
      _radarBadge(Icons.hourglass_top, '妖王降临 · ${left}s');

  /// 无妖章回收口展示：每日游历不展示任何通关条件/提示（进图即亮「功成」、
  /// 随时可结算，整块隐藏）；无妖主线章回=西行里程（剩余里数，按玩家实际
  /// 位移累计，挂机不可达成）；无尽妖潮（endlessWave>0）：同位展示当前波数。
  Widget _surviveCountdown(JourneyBattleController controller) {
    final hud = controller.hud;
    return ValueListenableBuilder<int>(
      valueListenable: hud.endlessWave,
      builder: (context, wave, _) => wave > 0
          ? _radarBadge(Icons.waves, '妖潮 · 第 $wave 波')
          : ValueListenableBuilder<bool>(
              valueListenable: hud.travelBased,
              builder: (context, travel, _) => travel
                  ? ValueListenableBuilder<int>(
                      valueListenable: hud.travelLeft,
                      builder: (context, left, _) => left <= 0
                          ? const SizedBox.shrink()
                          : _radarBadge(Icons.directions_walk, '西行 · 余 $left 里'),
                    )
                  : const SizedBox.shrink(),
            ),
    );
  }
}
