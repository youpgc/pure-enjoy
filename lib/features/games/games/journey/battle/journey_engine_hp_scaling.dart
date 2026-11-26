part of 'journey_flame_game.dart';

/// 档位边界容差：抵消血量比例的浮点误差，恰好落在档位边界时按升档计。
const double _kJourneyLowHpTierEpsilon = 1e-9;

/// 低血增益档位系数：满血=1，每缺失 10% 血量升 1 档；
/// 阈值是封顶血量比例，决定最高档在第几档，不改变每档跨度。
/// 嗜血与背水一战共用同一档位计算，阈值由 journey_battle_params.weapon 后台可配。
double journeyLowHpTierFactor(
  JourneyFlameGame game,
  String thresholdParam,
) {
  final maxHp = game.player.maxHp;
  if (maxHp <= 0) return 1;
  final threshold = game
      .battleNum('weapon', thresholdParam, kJourneyLowHpThresholdRatio)
      .clamp(0.01, 1.0);
  final tier =
      ((1 - (game.player.hp / maxHp).clamp(0.0, 1.0)) * kJourneyLowHpTierCount +
              _kJourneyLowHpTierEpsilon)
          .floor();
  final maxTier = ((1 - threshold) * kJourneyLowHpTierCount).floor();
  return 1.0 + tier.clamp(0, maxTier.clamp(0, kJourneyLowHpTierCount - 1));
}

/// 嗜血攻速乘区：按等级×每级增量×低血档位系数逐帧计算，
/// 由环绕渲染并入 spinAmp 后统一钳 5 圈/秒。
extension JourneyLowHpScaling on JourneyFlameGame {
  double get bloodlustAmp {
    final lv = slotLevel('bloodlust');
    if (lv <= 0) return 0;
    return slotValue('bloodlust', kJourneyBloodlustAmpPerLv) *
        lv *
        journeyLowHpTierFactor(this, 'bloodlust_min_hp_ratio');
  }

  /// 背水一战增伤：并入伤害公式的增伤合计（加法项），
  /// 环绕与并行弹道共用同一 Σ% 乘区。
  double get desperationAmp {
    final lv = slotLevel('desperation');
    if (lv <= 0) return 0;
    return slotValue('desperation', kJourneyDesperationAmpPerLv) *
        lv *
        journeyLowHpTierFactor(this, 'desperation_min_hp_ratio');
  }
}
