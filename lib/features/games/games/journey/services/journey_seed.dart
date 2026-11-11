/// 西行·内置兜底配置。
///
/// 用途：journey_* 配置表尚未部署（SQL 随双端完成后统一交付）或拉取失败时，
/// 基础框架以此数据渲染与自测；数值口径与 SQL 种子保持一致。
/// 部署后远端数据可用即覆盖本兜底。
library;

import '../models/journey_talent_models.dart'
    show
        kJourneyTalentChars,
        kJourneyTalentElements,
        kJourneyTalentBranchTypes,
        kJourneyBranchMaxLv,
        journeyBranchCode;

export 'journey_curve_constants.dart';
export 'journey_growth_constants.dart';

const List<Map<String, dynamic>> kJourneyRegionSeed = <Map<String, dynamic>>[
  {'code': 'wuxingshan', 'name': '五行山', 'seq': 1, 'theme_color': '#5B9BD5'},
  {'code': 'gaolaozhuang', 'name': '高老庄', 'seq': 2, 'theme_color': '#6FBF9A'},
  {'code': 'liushahe', 'name': '流沙河', 'seq': 3, 'theme_color': '#B08968'},
  {'code': 'baibuling', 'name': '白虎岭', 'seq': 4, 'theme_color': '#D4593F'},
];

const List<Map<String, dynamic>> kJourneyLevelSeed = <Map<String, dynamic>>[
  {'level_no': 1, 'title': '金蝉遭贬', 'region_code': 'wuxingshan', 'level_kind': 'story'},
  {'level_no': 2, 'title': '出胎几杀', 'region_code': 'wuxingshan', 'level_kind': 'story'},
  {'level_no': 3, 'title': '满月抛江', 'region_code': 'wuxingshan', 'level_kind': 'story'},
  {'level_no': 4, 'title': '寻亲报冤', 'region_code': 'wuxingshan', 'level_kind': 'story'},
  {'level_no': 5, 'title': '出城逢虎', 'region_code': 'wuxingshan', 'level_kind': 'battle'},
  {'level_no': 6, 'title': '落坑折从', 'region_code': 'wuxingshan', 'level_kind': 'battle'},
  {'level_no': 7, 'title': '双叉岭上', 'region_code': 'wuxingshan', 'level_kind': 'boss', 'boss_fights': 1, 'first_clear_merit': 60},
  {'level_no': 8, 'title': '两界山头', 'region_code': 'wuxingshan', 'level_kind': 'node'},
  {'level_no': 9, 'title': '陡涧换马', 'region_code': 'wuxingshan', 'level_kind': 'node'},
  {'level_no': 10, 'title': '夜被火烧', 'region_code': 'wuxingshan', 'level_kind': 'battle'},
  {'level_no': 11, 'title': '失却袈裟', 'region_code': 'wuxingshan', 'level_kind': 'boss', 'boss_fights': 1, 'first_clear_merit': 80},
  {'level_no': 12, 'title': '收降八戒', 'region_code': 'gaolaozhuang', 'level_kind': 'node'},
  {'level_no': 13, 'title': '黄风怪阻', 'region_code': 'gaolaozhuang', 'level_kind': 'boss', 'boss_fights': 1, 'first_clear_merit': 100},
  {'level_no': 14, 'title': '请求灵吉', 'region_code': 'gaolaozhuang', 'level_kind': 'battle'},
  {'level_no': 15, 'title': '流沙难渡', 'region_code': 'liushahe', 'level_kind': 'node'},
  {'level_no': 16, 'title': '收得沙僧', 'region_code': 'liushahe', 'level_kind': 'node'},
  {'level_no': 17, 'title': '四圣显化', 'region_code': 'liushahe', 'level_kind': 'trial'},
  {'level_no': 18, 'title': '五庄观中', 'region_code': 'liushahe', 'level_kind': 'node'},
  {'level_no': 19, 'title': '难活人参', 'region_code': 'liushahe', 'level_kind': 'battle'},
  {'level_no': 20, 'title': '贬退心猿', 'region_code': 'baibuling', 'level_kind': 'boss', 'boss_fights': 3, 'first_clear_merit': 150},
];

const List<Map<String, dynamic>> kJourneyCharacterSeed =
    <Map<String, dynamic>>[
  {
    'code': 'tang',
    'name': '唐僧',
    'base_hp': 100,
    'aura_name': '佛光',
    'aura_desc': '周期回血光环，起手容错最高',
    'weapon_code': 'staff_buddha_light',
    'unlock_level_no': 0,
    'unlock_merit_cost': 0,
  },
  {
    'code': 'wukong',
    'name': '悟空',
    'base_hp': 110,
    'aura_name': '大圣威压',
    'aura_desc': '击杀概率触发连击/短暂攻速提升',
    'weapon_code': 'jingubang',
    'unlock_level_no': 8,
    'unlock_merit_cost': 3000,
  },
  {
    'code': 'bajie',
    'name': '八戒',
    'base_hp': 120,
    'aura_name': '贪食',
    'aura_desc': '拾取范围+经验获取加成',
    'weapon_code': 'jiuchi_paba',
    'unlock_level_no': 12,
    'unlock_merit_cost': 4000,
  },
  {
    'code': 'shaseng',
    'name': '沙僧',
    'base_hp': 120,
    'aura_name': '坚韧',
    'aura_desc': '受击减伤/周期护盾',
    'weapon_code': 'jiangyao_bangzhang',
    'unlock_level_no': 16,
    'unlock_merit_cost': 6000,
  },
  // ---- 非取经扩展角色（5，镜像 SQL 批次 feature_journey_ext_chars_20261106；
  //      解锁难号按西游记原著出场章节锚定 81 难关名）----
  {
    'code': 'jinjiao',
    'name': '金角大王',
    'base_hp': 125,
    'aura_name': '移山劲',
    'aura_desc': '摄魂厚血的抗压前排',
    'weapon_code': 'zijin_gourd',
    'unlock_level_no': 25, // 莲花洞高悬（紫金葫芦被收）
    'unlock_merit_cost': 2200,
  },
  {
    'code': 'honghaier',
    'name': '红孩儿',
    'base_hp': 105,
    'aura_name': '三昧真火',
    'aura_desc': '武器伤害 +8%，烈焰淬炼',
    'weapon_code': 'huojian_spear',
    'unlock_level_no': 31, // 请圣降妖（观音收为善财童子）
    'unlock_merit_cost': 2400,
  },
  {
    'code': 'nezha',
    'name': '哪吒',
    'base_hp': 115,
    'aura_name': '莲花化身',
    'aura_desc': '击杀加速成长的锋锐之姿',
    'weapon_code': 'qiankun_circle',
    'unlock_level_no': 40, // 普天神难伏（金兜山助战）
    'unlock_merit_cost': 2800,
  },
  {
    'code': 'laojun',
    'name': '太上老君',
    'base_hp': 100,
    'aura_name': '兜率炉火',
    'aura_desc': '炼器炉火淬炼的重击',
    'weapon_code': 'sanmei_fire',
    'unlock_level_no': 41, // 问佛根源（老君收服独角兕）
    'unlock_merit_cost': 3000,
  },
  {
    'code': 'tieshan',
    'name': '铁扇公主',
    'base_hp': 110,
    'aura_name': '罡风偃月',
    'aura_desc': '移动速度 +8%，罡风随身',
    'weapon_code': 'bajiao_fan',
    'unlock_level_no': 49, // 收缚魔王（火焰山三调芭蕉扇）
    'unlock_merit_cost': 3200,
  },
];

const List<Map<String, dynamic>> kJourneyWeaponSeed = <Map<String, dynamic>>[
  // 角色对应（4，初始环绕参数=引擎兜底口径，后台 journey_weapons 可调）
  {'code': 'jingubang', 'name': '金箍棒', 'category': 'active', 'attack_kind': 'orbit', 'description': '多段快转环，收割节奏最快', 'character_code': 'wukong',
   'orbit_speed': 3.2, 'inner_radius': 26, 'outer_radius': 96, 'blade_width': 22, 'base_damage': 13, 'starter_effect': 'pierce'},
  {'code': 'jiuchi_paba', 'name': '九齿钉耙', 'category': 'active', 'attack_kind': 'orbit', 'description': '多件宽环慢转，覆盖面最大', 'character_code': 'bajie',
   'orbit_speed': 1.9, 'inner_radius': 22, 'outer_radius': 126, 'blade_width': 30, 'base_damage': 11, 'starter_effect': 'knockback'},
  {'code': 'jiangyao_bangzhang', 'name': '降妖宝杖', 'category': 'active', 'attack_kind': 'orbit', 'description': '少件慢转重击', 'character_code': 'shaseng',
   'orbit_speed': 1.6, 'inner_radius': 26, 'outer_radius': 92, 'blade_width': 26, 'base_damage': 21, 'starter_effect': 'burn'},
  {'code': 'staff_buddha_light', 'name': '禅杖·佛光', 'category': 'active', 'attack_kind': 'orbit', 'description': '均衡环绕，附带佛光回血光环', 'character_code': 'tang',
   'orbit_speed': 2.6, 'inner_radius': 26, 'outer_radius': 104, 'blade_width': 24, 'base_damage': 14, 'starter_effect': 'lifesteal'},
  // 常规主动（5；已改角色绑定特性法宝——orbit 形态+环绕参数，
  // 跟随角色解锁自动入池，镜像 SQL 批次 feature_journey_ext_chars_20261106）
  {'code': 'qiankun_circle', 'name': '乾坤圈', 'category': 'active', 'attack_kind': 'orbit', 'description': '乾坤圈掷出砸击：快转中距，命中击退', 'character_code': 'nezha',
   'orbit_speed': 2.9, 'inner_radius': 24, 'outer_radius': 98, 'blade_width': 24, 'base_damage': 16, 'starter_effect': 'knockback'},
  {'code': 'sanmei_fire', 'name': '三昧真火', 'category': 'active', 'attack_kind': 'orbit', 'description': '三昧真火炉焰：少件重击带灼烧', 'character_code': 'laojun',
   'orbit_speed': 1.8, 'inner_radius': 26, 'outer_radius': 94, 'blade_width': 26, 'base_damage': 17, 'starter_effect': 'burn'},
  {'code': 'huojian_spear', 'name': '火尖枪', 'category': 'active', 'attack_kind': 'orbit', 'description': '火尖枪燎原：长杆点火，命中灼烧', 'character_code': 'honghaier',
   'orbit_speed': 2.5, 'inner_radius': 26, 'outer_radius': 110, 'blade_width': 20, 'base_damage': 18, 'starter_effect': 'burn'},
  {'code': 'bajiao_fan', 'name': '芭蕉扇', 'category': 'active', 'attack_kind': 'orbit', 'description': '芭蕉扇罡风：宽扇慢转，覆盖面最大', 'character_code': 'tieshan',
   'orbit_speed': 2.0, 'inner_radius': 22, 'outer_radius': 120, 'blade_width': 32, 'base_damage': 12, 'starter_effect': 'knockback'},
  {'code': 'zijin_gourd', 'name': '紫金葫芦', 'category': 'active', 'attack_kind': 'orbit', 'description': '紫金葫芦摄魂：命中回血，续航抗压', 'character_code': 'jinjiao',
   'orbit_speed': 2.3, 'inner_radius': 24, 'outer_radius': 102, 'blade_width': 26, 'base_damage': 14, 'starter_effect': 'lifesteal'},
  // 被动加持（6）
  {'code': 'jindou_cloud', 'name': '筋斗云', 'category': 'passive', 'attack_kind': '', 'description': '移速提升', 'attr_key': 'move_speed'},
  {'code': 'pantao', 'name': '蟠桃', 'category': 'passive', 'attack_kind': '', 'description': '生命上限+回复', 'attr_key': 'max_hp'},
  {'code': 'renshen_guo', 'name': '人参果', 'category': 'passive', 'attack_kind': '', 'description': '经验加成', 'attr_key': 'exp_gain'},
  {'code': 'bishui_pearl', 'name': '避水珠', 'category': 'passive', 'attack_kind': '', 'description': '攻速提升（=冷却缩减）', 'attr_key': 'attack_speed'},
  {'code': 'dingfeng_pearl', 'name': '定风珠', 'category': 'passive', 'attack_kind': '', 'description': '全环半径提升（法宝随之变大）', 'attr_key': 'orbit_radius'},
  {'code': 'shelizi', 'name': '舍利子', 'category': 'passive', 'attack_kind': '', 'description': '伤害提升', 'attr_key': 'damage_amp'},
  // 特效触发（3）
  {'code': 'kunxian_rope', 'name': '捆仙索', 'category': 'effect', 'attack_kind': '', 'description': '概率定身'},
  {'code': 'fanshang_thorns', 'name': '反伤荆棘', 'category': 'effect', 'attack_kind': '', 'description': '受击反伤'},
  {'code': 'baoji_thunder', 'name': '暴击雷引', 'category': 'effect', 'attack_kind': '', 'description': '暴击闪电链'},
  // 西游扩展批（功德解锁：3 被动 + 3 特效；relic_unlocks 定价）
  {'code': 'sanheng_mao', 'name': '三根毫毛', 'category': 'passive', 'attack_kind': '', 'description': '致命伤免死一次，回 30% 生命'},
  {'code': 'yujing_ping', 'name': '玉净瓶甘露', 'category': 'passive', 'attack_kind': '', 'description': '每 20 秒回复 20% 生命'},
  {'code': 'huoyan_jingjing', 'name': '火眼金睛', 'category': 'passive', 'attack_kind': '', 'description': '精英与妖王受伤 +20%'},
  {'code': 'zijin_ling', 'name': '紫金铃', 'category': 'effect', 'attack_kind': '', 'description': '命中 3 次引发妖火爆裂'},
  {'code': 'jinggang_zhuo', 'name': '金刚琢', 'category': 'effect', 'attack_kind': '', 'description': '周期套取最近妖物并使其虚弱'},
  {'code': 'yinyang_ping', 'name': '阴阳二气瓶', 'category': 'effect', 'attack_kind': '', 'description': '周期吸纳妖物定身灼烧'},
];

const List<Map<String, dynamic>> kJourneyMonsterSeed = <Map<String, dynamic>>[
  // 五行山段（关 1~11）
  {'code': 'yin_jiangjun', 'name': '寅将军', 'ai_tier': 'boss', 'base_hp': 3800, 'base_speed': 58, 'contact_damage': 22, 'size_scale': 1.9, 'exp_drop': 50, 'merit_drop': 20},
  {'code': 'yao_pig', 'name': '野猪精', 'ai_tier': 'normal', 'base_hp': 40, 'base_speed': 60, 'contact_damage': 8, 'size_scale': 1.0, 'exp_drop': 5},
  {'code': 'lang_yao', 'name': '狼妖', 'ai_tier': 'normal', 'base_hp': 30, 'base_speed': 92, 'contact_damage': 6, 'size_scale': 0.9, 'exp_drop': 5},
  {'code': 'hou_yao', 'name': '猴妖', 'ai_tier': 'normal', 'base_hp': 35, 'base_speed': 80, 'contact_damage': 7, 'size_scale': 0.95, 'exp_drop': 5},
  {'code': 'xiong_yao', 'name': '黑熊妖卒', 'ai_tier': 'elite', 'base_hp': 120, 'base_speed': 62, 'contact_damage': 11, 'size_scale': 1.35, 'exp_drop': 14},
  {'code': 'heixiong_jing', 'name': '黑熊精', 'ai_tier': 'boss', 'base_hp': 5000, 'base_speed': 55, 'contact_damage': 24, 'size_scale': 2.0, 'exp_drop': 60, 'merit_drop': 20},
  // 高老庄段（关 12~14）
  {'code': 'zhu_yao', 'name': '猪妖', 'ai_tier': 'normal', 'base_hp': 60, 'base_speed': 58, 'contact_damage': 10, 'size_scale': 1.05, 'exp_drop': 7},
  {'code': 'shan_chao', 'name': '山魈', 'ai_tier': 'normal', 'base_hp': 55, 'base_speed': 74, 'contact_damage': 9, 'size_scale': 1.0, 'exp_drop': 7},
  {'code': 'diao_yao', 'name': '雕妖', 'ai_tier': 'normal', 'base_hp': 48, 'base_speed': 100, 'contact_damage': 8, 'size_scale': 0.85, 'exp_drop': 7},
  {'code': 'huangfeng_jing', 'name': '黄风怪', 'ability_key': 'swift_wind', 'ai_tier': 'boss', 'base_hp': 9000, 'base_speed': 60, 'contact_damage': 29, 'size_scale': 2.1, 'exp_drop': 90, 'merit_drop': 30},
  // 流沙河段（关 15~19）
  {'code': 'shui_yao', 'name': '水妖', 'ai_tier': 'normal', 'base_hp': 85, 'base_speed': 55, 'contact_damage': 12, 'size_scale': 1.05, 'exp_drop': 9},
  {'code': 'sha_yao', 'name': '沙妖', 'ai_tier': 'normal', 'base_hp': 75, 'base_speed': 68, 'contact_damage': 11, 'size_scale': 1.0, 'exp_drop': 9},
  {'code': 'he_guai', 'name': '河怪', 'ai_tier': 'elite', 'base_hp': 220, 'base_speed': 52, 'contact_damage': 15, 'size_scale': 1.4, 'exp_drop': 20},
  // 白虎岭段（关 20）
  {'code': 'gutou_bing', 'name': '骷髅兵', 'ai_tier': 'normal', 'base_hp': 110, 'base_speed': 64, 'contact_damage': 14, 'size_scale': 1.0, 'exp_drop': 12},
  {'code': 'baigu_yaozu', 'name': '白骨妖卒', 'ai_tier': 'normal', 'base_hp': 95, 'base_speed': 76, 'contact_damage': 13, 'size_scale': 0.95, 'exp_drop': 12},
  {'code': 'yemao_jing', 'name': '野猫精', 'ai_tier': 'elite', 'base_hp': 260, 'base_speed': 88, 'contact_damage': 16, 'size_scale': 1.3, 'exp_drop': 26},
  {'code': 'baigu_jing', 'name': '白骨精', 'ability_key': 'bone_split', 'ai_tier': 'boss', 'base_hp': 24000, 'base_speed': 52, 'contact_damage': 35, 'size_scale': 2.3, 'exp_drop': 220, 'merit_drop': 60},
  // 原著妖王群像（白虎岭之后各章回实际妖怪，区域 boss_code 驱动）
  {'code': 'huangpao_guai', 'name': '黄袍怪', 'ai_tier': 'boss', 'base_hp': 34000, 'base_speed': 54, 'contact_damage': 38, 'size_scale': 2.3, 'exp_drop': 260, 'merit_drop': 70},
  {'code': 'jinjiao_dawang', 'name': '金角大王', 'ability_key': 'gourd_pull', 'ai_tier': 'boss', 'base_hp': 42000, 'base_speed': 52, 'contact_damage': 42, 'size_scale': 2.4, 'exp_drop': 320, 'merit_drop': 80},
  {'code': 'shili_guai', 'name': '狮猁怪', 'ai_tier': 'boss', 'base_hp': 50000, 'base_speed': 52, 'contact_damage': 45, 'size_scale': 2.4, 'exp_drop': 380, 'merit_drop': 90},
  {'code': 'honghaier', 'name': '圣婴大王·红孩儿', 'ability_key': 'samadhi_fire', 'ai_tier': 'boss', 'base_hp': 60000, 'base_speed': 58, 'contact_damage': 48, 'size_scale': 2.3, 'exp_drop': 460, 'merit_drop': 100},
  {'code': 'tuolong', 'name': '鼍龙', 'ai_tier': 'boss', 'base_hp': 68000, 'base_speed': 54, 'contact_damage': 48, 'size_scale': 2.4, 'exp_drop': 520, 'merit_drop': 110},
  {'code': 'huli_daxian', 'name': '虎力大仙', 'ai_tier': 'boss', 'base_hp': 76000, 'base_speed': 52, 'contact_damage': 51, 'size_scale': 2.4, 'exp_drop': 580, 'merit_drop': 120},
  {'code': 'linggan_dawang', 'name': '灵感大王', 'ai_tier': 'boss', 'base_hp': 84000, 'base_speed': 54, 'contact_damage': 51, 'size_scale': 2.5, 'exp_drop': 640, 'merit_drop': 130},
  {'code': 'dujiao_si', 'name': '独角兕大王', 'ability_key': 'iron_horn', 'ai_tier': 'boss', 'base_hp': 92000, 'base_speed': 52, 'contact_damage': 54, 'size_scale': 2.5, 'exp_drop': 700, 'merit_drop': 140},
  {'code': 'xiezi_jing', 'name': '蝎子精', 'ability_key': 'poison_mist', 'ai_tier': 'boss', 'base_hp': 100000, 'base_speed': 56, 'contact_damage': 54, 'size_scale': 2.4, 'exp_drop': 760, 'merit_drop': 150},
  {'code': 'liuer_mihou', 'name': '六耳猕猴', 'ai_tier': 'boss', 'base_hp': 108000, 'base_speed': 60, 'contact_damage': 58, 'size_scale': 2.3, 'exp_drop': 820, 'merit_drop': 160},
  {'code': 'niu_mowang', 'name': '牛魔王', 'ability_key': 'unmovable', 'ai_tier': 'boss', 'base_hp': 116000, 'base_speed': 54, 'contact_damage': 61, 'size_scale': 2.6, 'exp_drop': 880, 'merit_drop': 170},
  {'code': 'jiutou_chong', 'name': '九头虫', 'ability_key': 'blood_frenzy', 'ai_tier': 'boss', 'base_hp': 124000, 'base_speed': 56, 'contact_damage': 61, 'size_scale': 2.5, 'exp_drop': 940, 'merit_drop': 180},
  {'code': 'shibagong', 'name': '劲节十八公', 'ai_tier': 'boss', 'base_hp': 130000, 'base_speed': 50, 'contact_damage': 61, 'size_scale': 2.4, 'exp_drop': 990, 'merit_drop': 190},
  {'code': 'huangmei_dawang', 'name': '黄眉大王', 'ai_tier': 'boss', 'base_hp': 138000, 'base_speed': 52, 'contact_damage': 64, 'size_scale': 2.5, 'exp_drop': 1050, 'merit_drop': 200},
  {'code': 'honglin_mang', 'name': '红鳞大蟒', 'ai_tier': 'boss', 'base_hp': 144000, 'base_speed': 56, 'contact_damage': 64, 'size_scale': 2.6, 'exp_drop': 1100, 'merit_drop': 210},
  {'code': 'sai_taishui', 'name': '赛太岁', 'ai_tier': 'boss', 'base_hp': 150000, 'base_speed': 54, 'contact_damage': 67, 'size_scale': 2.5, 'exp_drop': 1160, 'merit_drop': 220},
  {'code': 'baiyan_mojun', 'name': '百眼魔君', 'ability_key': 'spider_web', 'ai_tier': 'boss', 'base_hp': 156000, 'base_speed': 54, 'contact_damage': 67, 'size_scale': 2.5, 'exp_drop': 1220, 'merit_drop': 230},
  {'code': 'dapeng', 'name': '大鹏金翅雕', 'ability_key': 'roc_speed', 'ai_tier': 'boss', 'base_hp': 162000, 'base_speed': 60, 'contact_damage': 70, 'size_scale': 2.6, 'exp_drop': 1280, 'merit_drop': 240},
  {'code': 'bailu_jing', 'name': '白鹿精', 'ai_tier': 'boss', 'base_hp': 168000, 'base_speed': 54, 'contact_damage': 70, 'size_scale': 2.4, 'exp_drop': 1330, 'merit_drop': 250},
  {'code': 'laoshu_jing', 'name': '金鼻白毛老鼠精', 'ai_tier': 'boss', 'base_hp': 174000, 'base_speed': 56, 'contact_damage': 74, 'size_scale': 2.3, 'exp_drop': 1390, 'merit_drop': 260},
  {'code': 'nanshan_dawang', 'name': '南山大王', 'ai_tier': 'boss', 'base_hp': 180000, 'base_speed': 54, 'contact_damage': 74, 'size_scale': 2.4, 'exp_drop': 1450, 'merit_drop': 270},
  {'code': 'jiuling_yuansheng', 'name': '九灵元圣', 'ai_tier': 'boss', 'base_hp': 186000, 'base_speed': 52, 'contact_damage': 77, 'size_scale': 2.7, 'exp_drop': 1510, 'merit_drop': 280},
  {'code': 'pihan_dawang', 'name': '辟寒大王', 'ai_tier': 'boss', 'base_hp': 192000, 'base_speed': 54, 'contact_damage': 77, 'size_scale': 2.5, 'exp_drop': 1570, 'merit_drop': 290},
  {'code': 'yutu_jing', 'name': '玉兔精', 'ai_tier': 'boss', 'base_hp': 198000, 'base_speed': 58, 'contact_damage': 80, 'size_scale': 2.3, 'exp_drop': 1630, 'merit_drop': 300},
  // 原著精英妖将
  {'code': 'yinjiao_dawang', 'name': '银角大王', 'ai_tier': 'elite', 'base_hp': 1800, 'base_speed': 60, 'contact_damage': 24, 'size_scale': 1.8, 'exp_drop': 90},
  {'code': 'hu_xianfeng', 'name': '虎先锋', 'ai_tier': 'elite', 'base_hp': 1500, 'base_speed': 66, 'contact_damage': 20, 'size_scale': 1.7, 'exp_drop': 80},
  {'code': 'luli_daxian', 'name': '鹿力大仙', 'ai_tier': 'elite', 'base_hp': 2200, 'base_speed': 58, 'contact_damage': 26, 'size_scale': 1.8, 'exp_drop': 100},
  {'code': 'yangli_daxian', 'name': '羊力大仙', 'ai_tier': 'elite', 'base_hp': 2400, 'base_speed': 60, 'contact_damage': 26, 'size_scale': 1.7, 'exp_drop': 105},
  {'code': 'youlai_qu', 'name': '有来有去', 'ai_tier': 'elite', 'base_hp': 3200, 'base_speed': 62, 'contact_damage': 28, 'size_scale': 1.4, 'exp_drop': 125},
  {'code': 'yumian_gongzhu', 'name': '玉面公主', 'ai_tier': 'elite', 'base_hp': 2600, 'base_speed': 64, 'contact_damage': 26, 'size_scale': 1.5, 'exp_drop': 110},
  {'code': 'benboer_ba', 'name': '奔波儿灞', 'ai_tier': 'elite', 'base_hp': 3000, 'base_speed': 56, 'contact_damage': 28, 'size_scale': 1.7, 'exp_drop': 120},
  {'code': 'zhizhu_jing', 'name': '蜘蛛精', 'ai_tier': 'elite', 'base_hp': 3400, 'base_speed': 62, 'contact_damage': 30, 'size_scale': 1.7, 'exp_drop': 130},
  {'code': 'qingshi_jing', 'name': '青狮精', 'ai_tier': 'elite', 'base_hp': 3800, 'base_speed': 56, 'contact_damage': 32, 'size_scale': 2.0, 'exp_drop': 140},
  {'code': 'baixiang_jing', 'name': '白象精', 'ai_tier': 'elite', 'base_hp': 4200, 'base_speed': 54, 'contact_damage': 34, 'size_scale': 2.1, 'exp_drop': 150},
  {'code': 'huangshi_jing', 'name': '黄狮精', 'ai_tier': 'elite', 'base_hp': 4600, 'base_speed': 58, 'contact_damage': 34, 'size_scale': 1.9, 'exp_drop': 160},
  {'code': 'bishu_dawang', 'name': '辟暑大王', 'ai_tier': 'elite', 'base_hp': 5000, 'base_speed': 56, 'contact_damage': 36, 'size_scale': 2.0, 'exp_drop': 170},
  {'code': 'bichen_dawang', 'name': '辟尘大王', 'ai_tier': 'elite', 'base_hp': 5400, 'base_speed': 56, 'contact_damage': 36, 'size_scale': 2.0, 'exp_drop': 180},
  // 原著妖卒
  {'code': 'xiao_zuanfeng', 'name': '小钻风', 'ai_tier': 'normal', 'base_hp': 2000, 'base_speed': 70, 'contact_damage': 26, 'size_scale': 1.2, 'exp_drop': 40},
];

/// 五行天赋分支种子（4 角色 × 5 系 × 3 分支 = 60 行；镜像 SQL 批次
/// feature_journey_talent_v4_branches_20261106）：v4 分支树制——每系
/// core 本源枝 8 层（核心属性）/ growth 生息枝 5 层（第二属性）/
/// sig 化形枝 3 层（标志强化），点亮双消耗（1 天赋点 + cost_base×
/// 层号 功德），相生 1:1 循环锁 + 相克制衡在 App 端判定。

/// 系 → (core, growth, sig) 每层数值（与 SQL 种子一致）。
const Map<String, List<num>> _kJourneyBranchValue =
    <String, List<num>>{
  'metal': <num>[0.03, 0.05, 1],
  'wood': <num>[8, 0.3, 1],
  'water': <num>[0.02, 0.04, 1],
  'fire': <num>[0.03, 0.015, 1],
  'earth': <num>[0.5, 8, 1],
};

/// 系 → (core, growth, sig) attr_key。
const Map<String, List<String>> _kJourneyBranchAttr =
    <String, List<String>>{
  'metal': <String>['attack', 'crit_damage', 'signature_metal'],
  'wood': <String>['max_hp', 'regen', 'signature_wood'],
  'water': <String>['attack_speed', 'exp_gain', 'signature_water'],
  'fire': <String>['damage_amp', 'crit_rate', 'signature_fire'],
  'earth': <String>['armor', 'pickup_range', 'signature_earth'],
};

/// 系 → (core, growth, sig) 每层效果说明。
const Map<String, List<String>> _kJourneyBranchDesc =
    <String, List<String>>{
  'metal': <String>[
    '每层 攻击力 +3%',
    '每层 暴击伤害 +5%',
    '每层 武器伤害 +5%',
  ],
  'wood': <String>[
    '每层 生命上限 +8',
    '每层 自动回复 +0.3/秒',
    '点亮 回复翻倍+生命上限+10%；3 层 回复+1/秒',
  ],
  'water': <String>[
    '每层 环绕转速 +2%',
    '每层 经验获取 +4%',
    '每层 环绕转速突破 +5%',
  ],
  'fire': <String>[
    '每层 武器伤害 +3%',
    '每层 暴击率 +1.5%',
    '每层 武器伤害 +5%',
  ],
  'earth': <String>[
    '每层 护甲 +0.5',
    '每层 拾取范围 +8',
    '点亮 拾取磁吸全屏；每层 护甲 +1.5',
  ],
};

/// 分支中文名（名称拼接用）。
const Map<String, String> _kJourneyBranchNames = <String, String>{
  'core': '本源',
  'growth': '生息',
  'sig': '化形',
};

/// 基础功德价（第 n 层消耗 = 此值 × n；与 SQL cost_base 默认一致）。
const int _kJourneyTrackCostBase = 50;

const Map<String, String> _kJourneyTalentCharNames = <String, String>{
  'tang': '唐僧',
  'wukong': '悟空',
  'bajie': '八戒',
  'shaseng': '沙僧',
  'nezha': '哪吒',
  'honghaier': '红孩儿',
  'tieshan': '铁扇公主',
  'laojun': '太上老君',
  'jinjiao': '金角大王',
};

const Map<String, String> _kJourneyTalentElementNames = <String, String>{
  'metal': '锐金',
  'wood': '青木',
  'water': '玄水',
  'fire': '离火',
  'earth': '厚土',
};

List<Map<String, dynamic>> buildJourneyTalentBranchSeed() =>
    <Map<String, dynamic>>[
      for (final char in kJourneyTalentChars)
        for (final element in kJourneyTalentElements)
          for (final (i, branch) in kJourneyTalentBranchTypes.indexed)
            {
              'character_code': char,
              'element': element,
              'branch_type': branch,
              'branch_code': journeyBranchCode(char, element, branch),
              'seq': i + 1,
              'name': '${_kJourneyTalentCharNames[char]}'
                  '·${_kJourneyTalentElementNames[element]}'
                  '·${_kJourneyBranchNames[branch]}',
              'attr_key': _kJourneyBranchAttr[element]![i],
              'value_per_level': _kJourneyBranchValue[element]![i],
              'max_lv': kJourneyBranchMaxLv[branch],
              'cost_base': _kJourneyTrackCostBase,
              'effect_desc': _kJourneyBranchDesc[element]![i],
            },
    ];

/// 武器维度槽定义兜底（远端 journey_weapon_slots 优先；镜像 SQL 批次
/// feature_journey_slots_lv9_clone_20261106：8 槽上限 9 级 + 新增 clone 槽）。
/// 6 主动槽=维度槽：初始武器占 1 特效槽（角色映射见引擎），空槽由
/// 三选一「习得」卡填入；每级效果/上限为运营配置，此处仅兜底。
const List<Map<String, dynamic>> kJourneySlotDefSeed =
    <Map<String, dynamic>>[
  {'code': 'radius', 'name': '臂展', 'kind': 'attribute', 'effect_per_level': '武器臂长 +14', 'max_level': 9},
  {'code': 'speed', 'name': '转速', 'kind': 'attribute', 'effect_per_level': '环绕转速 +10%', 'max_level': 9},
  {'code': 'damage', 'name': '伤害', 'kind': 'attribute', 'effect_per_level': '武器伤害 +20%', 'max_level': 9},
  {'code': 'knockback', 'name': '击退', 'kind': 'effect', 'effect_per_level': '命中击退距离 +16', 'max_level': 9},
  {'code': 'lifesteal', 'name': '吸血', 'kind': 'effect', 'effect_per_level': '命中回复武器伤害的 12%', 'max_level': 9},
  {'code': 'pierce', 'name': '穿刺', 'kind': 'effect', 'effect_per_level': '武器伤害 +15%', 'max_level': 9},
  {'code': 'magnet', 'name': '磁吸', 'kind': 'effect', 'effect_per_level': '拾取范围 +40', 'max_level': 9},
  {'code': 'burn', 'name': '灼烧', 'kind': 'effect', 'effect_per_level': '命中点燃：8/秒 持续 2 秒', 'max_level': 9},
  {'code': 'clone', 'name': '分身', 'kind': 'attribute', 'effect_per_level': '环绕法宝 +1 条扇叶', 'max_level': 3},
  // 暴击体系补全（暴击/暴伤/护甲局内成长路径；镜像 SQL 批次
  // feature_journey_crit_slots_20261106；暴击率钳 60%、暴伤钳 200%）
  {'code': 'crit_rate', 'name': '暴击', 'kind': 'attribute', 'effect_per_level': '暴击率 +2.5%', 'max_level': 9},
  {'code': 'crit_damage', 'name': '暴伤', 'kind': 'attribute', 'effect_per_level': '暴击伤害 +6%', 'max_level': 9},
  {'code': 'armor', 'name': '护甲', 'kind': 'attribute', 'effect_per_level': '护甲 +1.5', 'max_level': 9},
];

// ---- 局外玩法种子（M3；镜像 SQL 种子 feature_journey_m3_20261105）----

/// 还魂复活功德基准价（journey_globals.revive_merit_base）；
/// 实际消耗 = 基准 × 关卡号，单局 1 次（局内控制）。
const int kJourneyReviveMeritBase = 60;

/// 角色等级上限（journey_globals.char_level_cap 镜像；满级经验条恒满）。
const int kJourneyCharLevelCap = 99;

/// 开局铺场只数（journey_globals.initial_pack_size 镜像；0=关闭铺场）。
const int kJourneyInitialPackSize = 24;

/// 妖穴集中概率（journey_globals.spawn_den_ratio 镜像，0~1；
/// 刷怪点落入 demon_den 热区的比例）。
const double kJourneySpawnDenRatio = 0.70;

/// 妖王天赋点掉率（journey_globals.talent_drop_rate 镜像，0~1；
/// 末场伏诛判定命中后全部角色点池各 +1；点池不设上限）。
const double kJourneyTalentDropRate = 0.10;

/// 妖王首次降临延迟（秒；journey_globals.boss_spawn_delay_sec 可覆盖）。
const int kJourneyBossSpawnDelaySec = 300;

/// 前期发育保护期（秒；journey_globals.early_game_protect_sec 可覆盖）：
/// 期间只刷普通怪，留出发育窗口。
const int kJourneyEarlyGameProtectSec = 60;

/// 保护期结束后精英率每分钟增量（journey_globals.elite_rate_per_min
/// 可覆盖）；实际精英率随时间线性增长并钳到 [kJourneyEliteRateCap]。
const double kJourneyEliteRatePerMin = 0.06;

/// 精英率上限：后期仍保留普通怪，避免盘面全为精英。
const double kJourneyEliteRateCap = 0.60;

/// 掉落表种子（journey_drops；4 组 11 行镜像 SQL 种子，weight=0 行
/// 不掉落，breakable 组「空掉落」行 pickup_code 为 null）。
const List<Map<String, dynamic>> kJourneyDropSeed =
    <Map<String, dynamic>>[
  {'table_code': 'monster_normal', 'source_kind': 'monster', 'pickup_code': 'xianghuo', 'weight': 100, 'qty_min': 1, 'qty_max': 2},
  {'table_code': 'monster_normal', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 12, 'qty_min': 2, 'qty_max': 5},
  {'table_code': 'monster_normal', 'source_kind': 'monster', 'pickup_code': 'pantao_pickup', 'weight': 2, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_elite', 'source_kind': 'monster', 'pickup_code': 'xianghuo', 'weight': 100, 'qty_min': 2, 'qty_max': 4},
  {'table_code': 'monster_elite', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 30, 'qty_min': 4, 'qty_max': 8},
  {'table_code': 'monster_elite', 'source_kind': 'monster', 'pickup_code': 'baoxiang', 'weight': 100, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_boss', 'source_kind': 'monster', 'pickup_code': 'baoxiang', 'weight': 100, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_boss', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 100, 'qty_min': 10, 'qty_max': 20},
  {'table_code': 'breakable_default', 'source_kind': 'breakable', 'pickup_code': null, 'weight': 40, 'qty_min': 0, 'qty_max': 0},
  {'table_code': 'breakable_default', 'source_kind': 'breakable', 'pickup_code': 'gongde_tongqian', 'weight': 45, 'qty_min': 1, 'qty_max': 3},
  {'table_code': 'breakable_default', 'source_kind': 'breakable', 'pickup_code': 'pantao_pickup', 'weight': 8, 'qty_min': 1, 'qty_max': 1},
  // 后期（21+ 难）掉落分档：高价值拾取物权重上调（App 端 levelNo>20 切换）
  {'table_code': 'monster_normal_late', 'source_kind': 'monster', 'pickup_code': 'xianghuo', 'weight': 100, 'qty_min': 2, 'qty_max': 4},
  {'table_code': 'monster_normal_late', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 18, 'qty_min': 4, 'qty_max': 8},
  {'table_code': 'monster_normal_late', 'source_kind': 'monster', 'pickup_code': 'yaodan', 'weight': 6, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_normal_late', 'source_kind': 'monster', 'pickup_code': 'lingzhu', 'weight': 3, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_normal_late', 'source_kind': 'monster', 'pickup_code': 'jinding', 'weight': 2, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'xianghuo', 'weight': 100, 'qty_min': 3, 'qty_max': 6},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 35, 'qty_min': 8, 'qty_max': 16},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'baoxiang', 'weight': 100, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'yaodan', 'weight': 25, 'qty_min': 1, 'qty_max': 2},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'lingzhu', 'weight': 15, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_elite_late', 'source_kind': 'monster', 'pickup_code': 'jinding', 'weight': 10, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_boss_late', 'source_kind': 'monster', 'pickup_code': 'baoxiang', 'weight': 100, 'qty_min': 1, 'qty_max': 1},
  {'table_code': 'monster_boss_late', 'source_kind': 'monster', 'pickup_code': 'gongde_tongqian', 'weight': 100, 'qty_min': 20, 'qty_max': 40},
  {'table_code': 'monster_boss_late', 'source_kind': 'monster', 'pickup_code': 'yaodan', 'weight': 60, 'qty_min': 2, 'qty_max': 4},
  {'table_code': 'monster_boss_late', 'source_kind': 'monster', 'pickup_code': 'lingzhu', 'weight': 40, 'qty_min': 1, 'qty_max': 2},
  {'table_code': 'monster_boss_late', 'source_kind': 'monster', 'pickup_code': 'jinding', 'weight': 30, 'qty_min': 1, 'qty_max': 2},
];

/// 炼化配方种子（journey_evo_recipes；4 条镜像 SQL 种子，
/// 表顺序 seq = 宝箱同时满足多配方时的判定优先级）。
const List<Map<String, dynamic>> kJourneyEvoRecipeSeed =
    <Map<String, dynamic>>[
  {'seq': 1, 'weapon_code': 'jingubang', 'required_passive_code': 'jindou_cloud', 'required_passive_lv': 1, 'result_code': 'dasheng_form', 'result_name': '大圣形态'},
  {'seq': 2, 'weapon_code': 'jiuchi_paba', 'required_passive_code': 'pantao', 'required_passive_lv': 1, 'result_code': 'tianpeng_armor', 'result_name': '天蓬战甲'},
  {'seq': 3, 'weapon_code': 'jiangyao_bangzhang', 'required_passive_code': 'bishui_pearl', 'required_passive_lv': 1, 'result_code': 'fumo_staff', 'result_name': '伏魔宝杖'},
  {'seq': 4, 'weapon_code': 'staff_buddha_light', 'required_passive_code': 'dingfeng_pearl', 'required_passive_lv': 1, 'result_code': 'jinshen_light', 'result_name': '金身佛光'},
];

/// 图鉴解锁种子（journey_relic_unlocks；4 件强法宝，
/// 解锁 = 达成成就 + 功德定价，未解锁不进三选一候选池）。
const List<Map<String, dynamic>> kJourneyRelicUnlockSeed =
    <Map<String, dynamic>>[
  {'seq': 1, 'weapon_code': 'kunxian_rope', 'achievement_code': 'journey_kills_5000', 'merit_cost': 300},
  {'seq': 2, 'weapon_code': 'fanshang_thorns', 'achievement_code': 'journey_first_clear_7', 'merit_cost': 200},
  {'seq': 3, 'weapon_code': 'baoji_thunder', 'achievement_code': 'journey_kills_1000', 'merit_cost': 400},
  // zijin_gourd 直购行已退役（改 jinjiao 角色绑定特性法宝，随角色解锁）
];

/// 拾取物配置种子（journey_pickups；code/effect/value 镜像已部署种子）。
const List<Map<String, dynamic>> kJourneyPickupConfigSeed =
    <Map<String, dynamic>>[
  {'code': 'xianghuo', 'name': '香火', 'effect': 'exp', 'value': 1, 'radius': 12, 'magnet_range': 40},
  {'code': 'gongde_tongqian', 'name': '功德铜钱', 'effect': 'merit', 'value': 3, 'radius': 12, 'magnet_range': 40},
  {'code': 'pantao_pickup', 'name': '蟠桃', 'effect': 'heal', 'value': 15, 'radius': 12, 'magnet_range': 40},
  {'code': 'baoxiang', 'name': '宝箱', 'effect': 'chest', 'value': 0, 'radius': 16, 'magnet_range': 0},
  {'code': 'yaodan', 'name': '妖丹', 'effect': 'exp', 'value': 30, 'radius': 12, 'magnet_range': 40},
  {'code': 'lingzhu', 'name': '灵珠', 'effect': 'heal', 'value': 80, 'radius': 12, 'magnet_range': 40},
  {'code': 'jinding', 'name': '功德金锭', 'effect': 'merit', 'value': 30, 'radius': 13, 'magnet_range': 40},
];

// ---- 每日游历·特色地图（journey_daily_maps 后台可配；此为离线兜底种子，
//      运营在管理后台增删地图后以远端列表为准）----

/// 游历地图兜底种子（code/名称/主题色/里程碑里数/功成时长）；
/// 主题色驱动地图渲染，里数为进关里程碑播报口径。
const List<Map<String, dynamic>> kJourneyDailyMapSeed = <Map<String, dynamic>>[
  {'code': 'huaguoshan', 'name': '花果山', 'theme_color': '#6FBF9A', 'milestone_li': 800, 'duration_target_sec': 300, 'description': '猴王故里，沿途铜钱雨不断', 'sort': 1},
  {'code': 'gaolaozhuang', 'name': '高老庄', 'theme_color': '#B08968', 'milestone_li': 1200, 'duration_target_sec': 300, 'description': '田园庄院，庄稼间妖气隐现', 'sort': 2},
  {'code': 'huangfengling', 'name': '黄风岭', 'theme_color': '#D4A73F', 'milestone_li': 1600, 'duration_target_sec': 300, 'description': '黄沙漫岭，妖风裹挟而行', 'sort': 3},
  {'code': 'liushahe', 'name': '流沙河', 'theme_color': '#5B9BD5', 'milestone_li': 2000, 'duration_target_sec': 300, 'description': '八百里流沙，鹅毛难浮', 'sort': 4},
  {'code': 'huoyanshan', 'name': '火焰山', 'theme_color': '#D4593F', 'milestone_li': 2600, 'duration_target_sec': 300, 'description': '八百里火焰，寸草不生', 'sort': 5},
];
