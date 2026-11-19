import 'journey_flame_game.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_seed.dart';

/// 属性展示数据：局内属性面板与历史对局详情共用同一份取值口径，
/// 避免两处格式化漂移。每行以（标签, 值）结构给出，分组以 [JourneyAttrGroup] 承载。
class JourneyAttrGroup {
  final String title;
  final List<(String, String)> rows;

  const JourneyAttrGroup(this.title, this.rows);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'rows': <List<String>>[
          for (final r in rows) <String>[r.$1, r.$2],
        ],
      };

  static JourneyAttrGroup? fromJson(Map<String, dynamic> json) {
    final title = json['title'] as String?;
    if (title == null) return null;
    final raw = json['rows'];
    if (raw is! List) return JourneyAttrGroup(title, const <(String, String)>[]);
    return JourneyAttrGroup(
      title,
      <(String, String)>[
        for (final item in raw)
          if (item is List && item.length >= 2)
            (item[0].toString(), item[1].toString()),
      ],
    );
  }
}

/// 从引擎构建全量属性展示数据：基础属性 + 武器维度槽 + 被动加持。
/// 与 [JourneyAttributesSheet] 展示口径同源，供局内面板与结算快照共用。
abstract final class JourneyAttributesData {
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
    'vitality': '生机',
    'cloud': '腾云',
    'ward': '金刚',
    'recovery': '回元',
    'shield': '护体',
    'slow': '缚灵',
  };

  static List<JourneyAttrGroup> collect(JourneyFlameGame game) {
    final groups = <JourneyAttrGroup>[];
    final defs = _slotDefs();
    final hud = game.controller.hud;

    final pierceLv = game.slotLevel('pierce');
    final piercePct = pierceLv > 0
        ? (kJourneyPierceBaseRatio +
                game.slotValue('pierce', kJourneyPierceIgnorePerLv) *
                    (pierceLv - 1))
            .clamp(0.0, kJourneyPierceRatioCap) *
            100
        : 0.0;
    final arm = game.weaponArm;

    groups.add(JourneyAttrGroup('基础属性', <(String, String)>[
      // 基础攻击力只展示最终总值，分项来源不对外呈现
      (
        '基础攻击力',
        (game.character.baseAttack +
                game.levelAttackTotal +
                game.cardAttackTotal)
            .toStringAsFixed(0)
      ),
      ('境界', game.realmTitle),
      (
        '法宝品阶伤害',
        game.weaponArm?.damage.toStringAsFixed(0) ??
            game.weaponBaseDamage.toStringAsFixed(0)
      ),
      ('攻击力加成', '+${(game.attackAmp * 100).toStringAsFixed(1)}%'),
      (
        '武器增伤',
        '+${((game.damageAmp - 1).clamp(0.0, 2.0) * 100).toStringAsFixed(1)}%'
      ),
      ('单次伤害', '${game.hitDamageBase.toStringAsFixed(1)}/击'),
      (
        '环绕转速',
        '${game.displayAngularSpeed.toStringAsFixed(1)}/秒 · '
            '${game.spinDirection < 0 ? '逆时针' : '顺时针'}'
      ),
      (
        '武器臂展',
        arm == null
            ? '-'
            : '${game.maxArmDiameter > 0 ? ((arm.outerRadius * 2 / game.maxArmDiameter * 100).round()) : 0}%'
                '（直径 ${(arm.outerRadius * 2).round()} · 内圈 ${arm.innerRadius.round()}）'
      ),
      ('生命', '${hud.hp.value.round()} / ${hud.maxHp.value.round()}'),
      ('自动回复', '${game.player.regen.toStringAsFixed(1)}/秒'),
      (
        '护甲',
        '${game.player.armor.toStringAsFixed(1)}（减伤 '
            '${(JourneyDamageTickMixin.armorReductionRatio(game.player.armor,
                    curveK: game.armorCurveK,
                    cap: game.battleNum('damage', 'player_armor_cap',
                        kJourneyPlayerArmorCap)) *
                100)
                .toStringAsFixed(0)}%）'
      ),
      (
        '破甲',
        pierceLv > 0
            ? 'Lv$pierceLv · 无视护甲 ${piercePct.toStringAsFixed(1)}%'
            : '未习得'
      ),
      ('移动速度', '×${game.moveSpeedAmp.toStringAsFixed(2)}'),
      ('拾取范围', '${game.player.pickupRange.round()}'),
      ('经验获取', '×${game.expAmp.toStringAsFixed(2)}'),
      ('暴击率', '${(game.critRate * 100).toStringAsFixed(1)}%'),
      ('暴击伤害', '${(game.critDamage * 100).round()}%'),
      ('炼化状态', _evolveText(game)),
      ('特效法宝', _effectWeaponsText(game)),
      ('特殊能力', _abilitiesText(game)),
    ]));

    groups.add(JourneyAttrGroup(
      '武器维度槽',
      <(String, String)>[
        for (final slot in game.weaponSlots)
          (
            '${slotNames[slot.code] ?? slot.code} · Lv${slot.level}'
                '/${defs[slot.code]?.maxLevel ?? 3}',
            _slotCurrentValue(slot.code, slot.level, defs),
          ),
        if (game.weaponSlots.length < 6)
          (
            '空槽',
            '${6 - game.weaponSlots.length} 格 · 三选一可习得新维度',
          ),
      ],
    ));

    if (game.passiveSlotCodes.isNotEmpty) {
      groups.add(JourneyAttrGroup(
        '被动加持',
        <(String, String)>[
          for (final code in game.passiveSlotCodes)
            (
              kJourneyPassiveEffects[code]?.$1 ?? code,
              kJourneyPassiveEffects[code]?.$2 ?? '',
            ),
        ],
      ));
    }

    return groups;
  }

  /// 炼化状态：已炼化显示配方结果名，未炼化提示当前武器配方所需前置被动；
  /// 配方/被动缺失时回落通用文案，不暴露 code 或拼出半截文案。
  static String _evolveText(JourneyFlameGame game) {
    final recipe = game.config?.evoRecipeOf(game.character.weaponCode);
    final result = recipe?.resultName ?? '';
    if (game.evolved) return result.isNotEmpty ? result : '已炼化';
    final passiveCode = recipe?.requiredPassiveCode ?? '';
    final passive = kJourneyPassiveEffects[passiveCode]?.$1 ?? passiveCode;
    if (passive.isEmpty) return '未炼化';
    return '未炼化（需被动「$passive」）';
  }

  static String _slotCurrentValue(
    String code,
    int level,
    Map<String, JourneySlotDefModel> defs,
  ) {
    final def = defs[code];
    final text = journeySlotValueText(code, level, def?.valuePerLevel ?? 0);
    return text.isNotEmpty ? text : (def?.effectPerLevel ?? '');
  }

  static Map<String, JourneySlotDefModel> _slotDefs() {
    final remote = JourneyConfigService.instance.cached?.slotDefMap();
    if (remote != null && remote.isNotEmpty) return remote;
    return <String, JourneySlotDefModel>{
      for (final d in kJourneySlotDefSeed.map(JourneySlotDefModel.fromJson))
        d.code: d,
    };
  }

  static String _effectWeaponsText(JourneyFlameGame game) {
    if (game.effectWeapons.isEmpty) return '未习得';
    final config = JourneyConfigService.instance.cached;
    return game.effectWeapons.map((c) => config?.weaponOf(c)?.name ?? c).join('、');
  }

  static String _abilitiesText(JourneyFlameGame game) {
    if (game.abilities.isEmpty) return '未解锁';
    return game.abilities.map((code) {
      final char = code.startsWith('ability_') ? code.substring(8) : '';
      return kJourneyCharAbilities[char]?.$1 ?? code;
    }).join('、');
  }
}
