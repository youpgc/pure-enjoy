import '../battle/journey_battle_controller.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import '../services/journey_config_service.dart';

/// 对局页进战前的设置期辅助：局外 loadout 构建 / 主题色 / 游历里程碑。
/// 与页面解耦便于复用与测试（页面只编排时序，不承载换算逻辑）。

/// 局外预注入：出战角色五行天赋树分支增量（每系 core/growth/sig 三
/// 分支，每层数值取分支配置，远端缺行按内置口径兜底）；加强点点亮 →
/// 特殊能力（引擎按角色标记挂钩）。
JourneyLoadout buildJourneyLoadout(JourneyProgressModel p, String charCode) {
  final snapshot = JourneyConfigService.instance.cached;
  double bv(String e, String b) {
    final branch = snapshot?.branchOf(charCode, e, b);
    return (branch?.valuePerLevel ?? kJourneyBranchFallbackValue[b]?[e] ?? 1)
        .toDouble();
  }

  int bl(String e, String b) =>
      p.talentLevelOf(charCode, journeyBranchCode(charCode, e, b));

  // core 本源枝：金/火→伤害、木→生命、水→转速、土→护甲
  final metalCore = bl('metal', 'core');
  final fireCore = bl('fire', 'core');
  final woodCore = bl('wood', 'core');
  final waterCore = bl('water', 'core');
  final earthCore = bl('earth', 'core');
  // growth 生息枝：金→暴击伤害、火→暴击率、木→回复、水→经验、土→拾取
  final metalGrowth = bl('metal', 'growth');
  final fireGrowth = bl('fire', 'growth');
  final woodGrowth = bl('wood', 'growth');
  final waterGrowth = bl('water', 'growth');
  final earthGrowth = bl('earth', 'growth');
  // sig 化形枝：金/火→伤害、水→转速、土→护甲+磁吸、木→回复特效
  final metalSig = bl('metal', 'sig');
  final fireSig = bl('fire', 'sig');
  final waterSig = bl('water', 'sig');
  final woodSig = bl('wood', 'sig');
  final earthSig = bl('earth', 'sig');

  final maxHpGain = woodCore * bv('wood', 'core');
  var regenGain = woodGrowth * bv('wood', 'growth');
  if (woodSig >= 3) regenGain += 1; // 回春 3 层：回复 +1/秒

  return JourneyLoadout(
    attackAmp: metalCore * bv('metal', 'core') +
        fireCore * bv('fire', 'core') +
        (metalSig + fireSig) * 0.05,
    spinAmp: waterCore * bv('water', 'core') + waterSig * 0.05,
    armorFlat: earthCore * bv('earth', 'core') + earthSig * 1.5,
    bonusMaxHp: maxHpGain,
    regenFlat: regenGain,
    pickupRangeFlat: earthGrowth * bv('earth', 'growth'),
    expAmp: 1.0 + waterGrowth * bv('water', 'growth'),
    critRateFlat: fireGrowth * bv('fire', 'growth'),
    critDamageBonus: metalGrowth * bv('metal', 'growth'),
    signatures: <String>{
      if (woodSig > 0) 'signature_wood',
      if (earthSig > 0) 'signature_earth',
    },
    // 加强点：本树五系修满后点亮 → 角色特殊能力（引擎钩子生效）
    abilities: <String>{
      if (p.talentEnhanceLit(charCode)) 'ability_$charCode',
    },
  );
}

/// 主题色：游历图走 journey_daily_maps 后台配置；主线走远端区域
/// 配置（缺省鎏金）。
String journeyThemeColorOf(JourneyLevelModel level, JourneyConfigSnapshot snapshot) {
  if (level.kind == 'daily') {
    return snapshot.dailyMapOf(level.regionCode)?.themeColor ?? '#E8C470';
  }
  return snapshot.regionOf(level.regionCode)?.themeColor ?? '#E8C470';
}

/// 每日游历里程碑：开场横幅（2.4s）之后播报一次「已游历 N 里」
/// （每图里数=journey_daily_maps 后台配置，缺行回落内置种子）；
/// stillMounted 由页面传入（延迟回调期页面可能已销毁）。
void scheduleDailyMilestone(
  JourneyBattleController controller,
  JourneyLevelModel level, {
  required bool Function() stillMounted,
}) {
  final map =
      JourneyConfigService.instance.cached?.dailyMapOf(level.regionCode);
  if (map == null) return;
  Future<void>.delayed(const Duration(milliseconds: 2600), () {
    if (!stillMounted()) return;
    controller.hud.milestoneText.value = '已游历 ${map.milestoneLi} 里';
  });
}
