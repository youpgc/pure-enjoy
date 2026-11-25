part of 'journey_flame_game.dart';

/// 被动加持名称（入槽即生效，效果实现见 _grantPassiveWeapon）。
/// 效果文案见 journeyPassiveEffectDesc：数值从法宝参数实时读取，与结算同源。
const Map<String, String> kJourneyPassiveNames = <String, String>{
  'jindou_cloud': '筋斗云',
  'pantao': '蟠桃',
  'renshen_guo': '人参果',
  'bishui_pearl': '避水珠',
  'dingfeng_pearl': '定风丹',
  'shelizi': '舍利子',
  // 西游扩展批（以下 6 件功德解锁、图鉴直购，见 kJourneyMeritPassives）
  'sanheng_mao': '三根毫毛',
  'yujing_ping': '玉净瓶',
  'huoyan_jingjing': '火眼金睛',
  'jinlan_kasha': '锦襕袈裟',
  'feilong_staff': '飞龙宝杖',
  'bihuo_zhao': '辟火罩',
  // 护盾攻防批：免费入池（不在 kJourneyMeritPassives），开局即可三选一
  'zhaoyao_jing': '照妖镜',
  'zhenyao_zhong': '震妖钟',
};

/// 特效触发法宝名称（§6）：入池=图鉴已解锁，触发结算见 _hitMonster /
/// updateDamageTick；激活即入 game.effectWeapons。
/// 效果文案见 journeyEffectWeaponDesc，数值从法宝参数实时读取。
const Map<String, String> kJourneyEffectWeaponNames = <String, String>{
  'kunxian_rope': '幌金绳',
  'fanshang_thorns': '反伤荆棘',
  'baoji_thunder': '暴击雷引',
  // 西游扩展批（功德解锁，图鉴直购）
  'zijin_ling': '紫金铃',
  'jinggang_zhuo': '金刚琢',
  'yinyang_ping': '阴阳二气瓶',
  'huntian_ling': '混天绫',
  'fenghuo_lun': '风火轮',
  'qixing_jian': '七星剑',
  'juyao_fan': '聚妖幡',
};

/// 功德解锁的扩展被动（图鉴直购；未解锁不进三选一免费池）。
const Set<String> kJourneyMeritPassives = <String>{
  'sanheng_mao',
  'yujing_ping',
  'huoyan_jingjing',
  'jinlan_kasha',
  'feilong_staff',
  'bihuo_zhao',
};

/// 效果文案的数值格式化：比例按百分比展示，计数/秒数按整数或一位小数展示。
String _paramPct(
  double Function(String code, String key, double fallback) param,
  String code,
  String key,
  double fallback,
) {
  final x = param(code, key, fallback) * 100;
  return x == x.roundToDouble()
      ? '${x.toStringAsFixed(0)}%'
      : '${x.toStringAsFixed(1)}%';
}

String _paramAmount(
  double Function(String code, String key, double fallback) param,
  String code,
  String key,
  double fallback,
) {
  final x = param(code, key, fallback);
  return x == x.roundToDouble()
      ? x.toStringAsFixed(0)
      : x.toStringAsFixed(1);
}

String _paramCount(
  double Function(String code, String key, double fallback) param,
  String code,
  String key,
  double fallback,
) => param(code, key, fallback).round().toString();

/// 周期秒数统一口径：整数显示整数，非整数保留一位小数。
String _paramPeriod(
  double Function(String code, String key, double fallback) param,
  String code,
  String key,
  double fallback,
) => _paramAmount(param, code, key, fallback);

/// 被动加持效果文案：按法宝参数实时生成，键与 _grantPassiveWeapon /
/// 各能力实现读取的键一致。后台改参数后三选一卡与属性面板同步变化，
/// 避免数值已生效但文案仍写旧百分比。
String journeyPassiveEffectDesc(
  String code,
  double Function(String code, String key, double fallback) param,
) {
  String pct(String key, double fb) => _paramPct(param, code, key, fb);
  String amount(String key, double fb) => _paramAmount(param, code, key, fb);
  String period(String key, double fb) => _paramPeriod(param, code, key, fb);

  switch (code) {
    case 'jindou_cloud':
      return '移速 +${pct('move', 0.12)}';
    case 'pantao':
      return '生命上限 +${pct('hp_ratio', 0.2)}，回复 +${amount('regen', 0.5)}/秒';
    case 'renshen_guo':
      return '经验 +${pct('exp', 0.25)}';
    case 'bishui_pearl':
      return '转速 +${pct('spin', 0.15)}';
    case 'dingfeng_pearl':
      return '臂长 +${amount('radius', 18)}';
    case 'shelizi':
      return '伤害 +${pct('damage', 0.15)}';
    case 'sanheng_mao':
      return '免死一次，回 ${pct('heal', 0.3)} 生命';
    case 'yujing_ping':
      return '每 ${period('period', 20)} 秒回 ${pct('heal', 0.2)} 生命';
    case 'huoyan_jingjing':
      return '精英/妖王受伤 +${pct('elite', 0.2)}';
    case 'jinlan_kasha':
      return '护甲 +${amount('armor', 5)}';
    case 'feilong_staff':
      return '命中击退 +${amount('knockback', 12)}';
    case 'bihuo_zhao':
      return '火系伤害减免 ${pct('resist', 0.15)}';
    case 'zhaoyao_jing':
      return '盾抵伤时额外反震 ${pct('reflect_ratio', 1.0)} 减伤前伤害，与金钟罩维度叠加（不吃护甲，总上限 ${pct('reflect_cap', 3.0)}）';
    case 'zhenyao_zhong':
      final ignoreArmor =
          param(code, 'burst_armor_ignore', 0) > 0 ? '（无视护甲）' : '';
      return '盾破时以破盾那击减伤前伤害的 ${pct('burst_ratio', 0.6)} 向周围 ${amount('burst_radius', 140)} 范围震荡$ignoreArmor';
    default:
      return '';
  }
}

/// 特效触发法宝效果文案：数值按键与引擎实际读取的参数同源。
/// 引擎以「参数表值 > 内置兜底」结算，此处按同一口径展示，避免脱节。
String journeyEffectWeaponDesc(
  String code,
  double Function(String code, String key, double fallback) param,
) {
  String pct(String key, double fb) => _paramPct(param, code, key, fb);
  String count(String key, double fb) => _paramCount(param, code, key, fb);
  String period(String key, double fb) => _paramPeriod(param, code, key, fb);

  switch (code) {
    case 'kunxian_rope':
      return '${pct('chance', 0.12)} 概率定身 ${_paramAmount(param, code, 'root', 1.5)} 秒';
    case 'fanshang_thorns':
      return '受击反弹 ${pct('thorns', 0.30)} 伤害';
    case 'baoji_thunder':
      return '暴击引闪电链，波及 ${count('targets', 2)} 妖';
    case 'zijin_ling':
      return '同目标命中 ${count('hits', 3)} 次引爆';
    case 'jinggang_zhuo':
      return '每 ${period('period', 12)} 秒套取并虚弱最近妖物';
    case 'yinyang_ping':
      return '每 ${period('period', 18)} 秒定身灼烧最近妖物';
    case 'huntian_ling':
      return '${pct('chance', 0.12)} 概率把妖物拖拽近身';
    case 'fenghuo_lun':
      return '点燃妖物并向周围逐代扩散灼烧';
    case 'qixing_jian':
      return '暴击对精英妖王追加真伤';
    case 'juyao_fan':
      return '每 ${period('period', 15)} 秒招引范围妖物主动来攻';
    default:
      return '';
  }
}
