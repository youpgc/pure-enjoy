/// 西行·角色数据模型（对应 journey_characters 表行）。
///
/// 自 journey_models.dart 拆出：角色模型含 aura_params/realm_titles
/// 两个 jsonb 解析器，独立成文件控制单文件规模。
library;

import 'dart:convert';

/// 角色
class JourneyCharacterModel {
  final String code;
  final String name;
  final int baseHp;

  /// 角色基础攻击（journey_characters.base_attack，后台可配）：
  /// 叠加在武器品阶伤害之上参与 hitDamageBase，0=不加成。
  final double baseAttack;

  /// 角色初始护甲（journey_characters.armor，后台可配）：
  /// 出战注入 player.armor 初值，与光环/天赋/局内护甲槽累加。
  final double armor;
  final String auraName;
  final String auraDesc;

  /// 角色光环参数（journey_characters.aura_params jsonb，后台可配）：
  /// 键值随角色语义不同（tang regen / shaseng+jinjiao armor / bajie
  /// pickup+exp_amp / laojun crit_damage 等），引擎按角色消费；
  /// 键缺失时回落内置兜底值，空对象=全部走兜底。
  final Map<String, double> auraParams;

  /// 角色境界名称（journey_characters.realm_titles jsonb，后台可配）：
  /// 9 档修行路径逐角色独立（索引=境界档位 0~8），第 9 档为原著正果
  /// 名号；行缺失/档位缺项回落引擎内置按角色表，再回落通用 9 档。
  final List<String> realmTitles;
  final String weaponCode;
  final int unlockLevelNo;
  final int unlockMeritCost;

  /// 开放/禁用开关（journey_characters.enabled，后台管理）；
  /// 禁用角色不出现在角色组/天赋页/出战舞台。缺省 true=开放。
  final bool enabled;

  const JourneyCharacterModel({
    required this.code,
    required this.name,
    required this.baseHp,
    this.baseAttack = 0,
    this.armor = 0,
    required this.auraName,
    required this.auraDesc,
    this.auraParams = const <String, double>{},
    this.realmTitles = const <String>[],
    required this.weaponCode,
    this.unlockLevelNo = 0,
    this.unlockMeritCost = 0,
    this.enabled = true,
  });

  factory JourneyCharacterModel.fromJson(Map<String, dynamic> json) {
    return JourneyCharacterModel(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseHp: (json['base_hp'] as num?)?.toInt() ?? 100,
      baseAttack: (json['base_attack'] as num?)?.toDouble() ?? 0,
      armor: (json['armor'] as num?)?.toDouble() ?? 0,
      auraName: json['aura_name'] as String? ?? '',
      auraDesc: json['aura_desc'] as String? ?? '',
      auraParams: _auraParamsOf(json['aura_params']),
      realmTitles: _realmTitlesOf(json['realm_titles']),
      weaponCode: json['weapon_code'] as String? ?? '',
      unlockLevelNo: (json['unlock_level_no'] as num?)?.toInt() ?? 0,
      unlockMeritCost: (json['unlock_merit_cost'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  /// 光环参数解析：jsonb 列远端返回 Map；兜底种子/文本入参兼容
  /// JSON 字符串；解析失败的行整体回落空对象（引擎走内置兜底）。
  static Map<String, double> _auraParamsOf(Object? raw) {
    if (raw == null) return const <String, double>{};
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = raw.cast<String, dynamic>();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        map = decoded is Map ? decoded.cast<String, dynamic>() : null;
      } catch (_) {
        return const <String, double>{};
      }
    }
    if (map == null) return const <String, double>{};
    return <String, double>{
      for (final e in map.entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    };
  }

  /// 光环参数读取：键缺失回落 [fallback]（与引擎内置兜底一致）。
  double auraNum(String key, double fallback) =>
      auraParams[key] ?? fallback;

  /// 境界名号读取：[tier]（0 起）有专属配置用专属，未配回落 null
  /// （消费侧再按角色内置名号表/通用名号表逐级兜底）。
  String? realmTitleAt(int tier) =>
      tier >= 0 && tier < realmTitles.length ? realmTitles[tier] : null;

  /// 境界名号解析：jsonb 列远端返回 List；兜底种子/文本入参兼容
  /// JSON 字符串；解析失败回落空列表（引擎走内置按角色名号表）。
  static List<String> _realmTitlesOf(Object? raw) {
    if (raw == null) return const <String>[];
    List<dynamic>? list;
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        list = decoded is List ? decoded : null;
      } catch (_) {
        return const <String>[];
      }
    }
    if (list == null) return const <String>[];
    return <String>[
      for (final e in list)
        if (e is String && e.isNotEmpty) e,
    ];
  }
}
