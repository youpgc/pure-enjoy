part of 'journey_flame_game.dart';

/// 宿主对配置快照的读取入口（数值/文本/槽定义），与对局状态无耦合，
/// 从宿主拆出以降低主文件行数；方法经私有 extension 在同 library 内可见。

extension JourneyConfigAccess on JourneyFlameGame {
  /// 法宝数值参数（journey_weapon_params 后台配置；行缺失回落 fallback）。
  double weaponParam(String code, String key, double fallback) =>
      config?.weaponParam(code, key, fallback) ?? fallback;

  /// 妖王能力参数（journey_monster_params 后台配置；行缺失回落 fallback）。
  double monsterParam(String monsterCode, String key, double fallback) =>
      config?.monsterParam(monsterCode, key, fallback) ?? fallback;

  /// 玩家基础移速（player.base_speed；缺省用内置值）。
  double get baseSpeed =>
      battleNum('player', 'base_speed', JourneyPlayerComponent.baseSpeed);

  /// 通用战斗参数·文本（枚举型，未配置回落 fallback）。
  String battleText(String group, String key, String fallback) =>
      config?.battleText(group, key, fallback) ?? fallback;

  /// 护甲减伤曲线分母 K（journey_globals.armor_curve_k；缺省 80）。
  double get armorCurveK =>
      config?.armorCurveK ?? kJourneyArmorCurveK;

  /// 怪物侧护甲减伤上限（journey_globals.monster_armor_reduction_cap；
  /// 缺省 72%，高于玩家 60%，保 150~200 甲档位区分度）。
  double get monsterArmorCap =>
      config?.monsterArmorCap ?? kJourneyMonsterArmorCap;

  /// 维度槽定义（code 匹配；含远端空表回落内置种子）。
  JourneySlotDefModel? slotDefOf(String code) {
    final map = _slotDefCache ??= config?.slotDefMap() ?? const {};
    return map[code];
  }

  /// 维度槽周期秒数（period_sec 后台配置；0/缺失回落 [fallback]）。
  /// 回元/护体等周期槽的文案与真实触发周期同源，避免两处口径脱节。
  double slotPeriod(String code, double fallback) {
    final v = slotDefOf(code)?.periodSec ?? 0;
    return v > 0 ? v : fallback;
  }

  /// 基础值成长卡每级数值（journey_upgrade_cards.value）：表已配置则用表值，
  /// 否则回落 [fallback]（由调用方传 globals 存量值，兼容表未部署）。
  double upgradeCardValue(String code, double fallback) {
    final v = config?.upgradeCardMap()[code]?.value ?? 0;
    return v > 0 ? v : fallback;
  }
}
