import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/journey_theme.dart';
import 'journey_battle_controller.dart';
import 'journey_hp_bar_fx.dart';
import 'journey_hud_widgets.dart';

/// 左上状态面板：立绘头像 + 等级 + 境界名同行；下方血条、经验条各带数值，
/// 末行击杀/功德铺满。高度与小地图点阵窗一致，顶边对齐自然齐平。
class JourneyHudPanel extends StatelessWidget {
  const JourneyHudPanel({
    super.key,
    required this.controller,
    required this.characterCode,
  });

  final JourneyBattleController controller;
  final String characterCode;

  @override
  Widget build(BuildContext context) {
    final hud = controller.hud;
    return Container(
      height: JourneyMinimapWindow.size,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 7),
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: JourneyTheme.panelStroke.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 首行：立绘头像 + 等级 + 境界名（横向同排，境界名占余宽）
          ValueListenableBuilder<int>(
            valueListenable: hud.level,
            builder: (context, lv, _) => ValueListenableBuilder<String>(
              valueListenable: hud.realmTitle,
              builder: (context, title, _) => Row(
                children: <Widget>[
                  _avatar(),
                  const SizedBox(width: 6),
                  Text(
                    'Lv$lv',
                    style: const TextStyle(
                      fontSize: 13,
                      color: JourneyTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: JourneyTheme.goldSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 血条：受击掉血时背后高亮残影渐变收缩，吸血增长直接动画增长
          ValueListenableBuilder<double>(
            valueListenable: hud.hp,
            builder: (context, hp, _) => ValueListenableBuilder<double>(
              valueListenable: hud.maxHp,
              builder: (context, maxHp, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  JourneyHpBarFx(value: maxHp > 0 ? hp / maxHp : 0),
                  // 护体金光：血条下方白色细线，宽度按护盾/最大生命比例
                  ValueListenableBuilder<double>(
                    valueListenable: hud.shield,
                    builder: (context, shield, _) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: SizedBox(
                          height: 2,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: Container(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: maxHp > 0
                                      ? (shield / maxHp).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '❤ ${hp.round()}/${maxHp.round()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: JourneyTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 经验条（两段式动画：升级先充满再归零，见引擎 exp part；
          // expReset 变化时按新 key 重建 TweenAnimationBuilder——
          // 重建即落位，避免「从满倒退」的反向 tween）；
          // 条下补一行当前经验/本级所需，与条间距 4px
          ValueListenableBuilder<int>(
            valueListenable: hud.expReset,
            builder: (context, reset, _) => ValueListenableBuilder<double>(
              valueListenable: hud.exp,
              builder: (context, exp, _) => ValueListenableBuilder<double>(
                valueListenable: hud.expNeed,
                builder: (context, need, _) => _bar(
                  need > 0 ? exp / need : 0,
                  const Color(0xFFA37FE0),
                  '✨ ${exp.round()}/${need.round()}',
                  animKey: ValueKey<int>(reset),
                ),
              ),
            ),
          ),
          // 末行：击杀、功德各占半行铺满宽度，文案左对齐
          ValueListenableBuilder<int>(
            valueListenable: hud.kills,
            builder: (context, kills, _) => ValueListenableBuilder<int>(
              valueListenable: hud.meritCoins,
              builder: (context, coins, _) => Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '击杀 $kills',
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: JourneyTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '功德 $coins',
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: JourneyTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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

  /// 经验条：TweenAnimationBuilder 300ms 缓动到目标值，拾取经验不跳变；
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
            padding: const EdgeInsets.only(top: 4),
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
