/// 西行·内置兜底配置。
///
/// 用途：journey_* 配置表尚未部署（SQL 随双端完成后统一交付）或拉取失败时，
/// 基础框架以此数据渲染与自测；数值口径与 SQL 种子保持一致。
/// 部署后远端数据可用即覆盖本兜底。
library;

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
    'unlock_merit_cost': 200,
  },
  {
    'code': 'bajie',
    'name': '八戒',
    'base_hp': 120,
    'aura_name': '贪食',
    'aura_desc': '拾取范围+经验获取加成',
    'weapon_code': 'jiuchi_paba',
    'unlock_level_no': 12,
    'unlock_merit_cost': 300,
  },
  {
    'code': 'shaseng',
    'name': '沙僧',
    'base_hp': 120,
    'aura_name': '坚韧',
    'aura_desc': '受击减伤/周期护盾',
    'weapon_code': 'jiangyao_bangzhang',
    'unlock_level_no': 16,
    'unlock_merit_cost': 400,
  },
];

const List<Map<String, dynamic>> kJourneyWeaponSeed = <Map<String, dynamic>>[
  // 角色对应（4，环绕参数差异化见引擎 _applyCharacterKit）
  {'code': 'jingubang', 'name': '金箍棒', 'category': 'active', 'attack_kind': 'orbit', 'description': '多段快转环，收割节奏最快'},
  {'code': 'jiuchi_paba', 'name': '九齿钉耙', 'category': 'active', 'attack_kind': 'orbit', 'description': '多件宽环慢转，覆盖面最大'},
  {'code': 'jiangyao_bangzhang', 'name': '降妖宝杖', 'category': 'active', 'attack_kind': 'orbit', 'description': '少件慢转重击'},
  {'code': 'staff_buddha_light', 'name': '禅杖·佛光', 'category': 'active', 'attack_kind': 'orbit', 'description': '均衡环绕，附带佛光回血光环'},
  // 常规主动（5）
  {'code': 'qiankun_circle', 'name': '乾坤圈', 'category': 'active', 'attack_kind': 'boomerang', 'description': '回旋镖'},
  {'code': 'sanmei_fire', 'name': '三昧真火', 'category': 'active', 'attack_kind': 'aura', 'description': '范围持续'},
  {'code': 'huojian_spear', 'name': '火尖枪', 'category': 'active', 'attack_kind': 'projectile', 'description': '穿透弹'},
  {'code': 'bajiao_fan', 'name': '芭蕉扇', 'category': 'active', 'attack_kind': 'beam', 'description': '击退风暴'},
  {'code': 'zijin_gourd', 'name': '紫金葫芦', 'category': 'active', 'attack_kind': 'magnet', 'description': '磁吸+伤害'},
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
];

const List<Map<String, dynamic>> kJourneyMonsterSeed = <Map<String, dynamic>>[
  // 五行山段（关 1~11）
  {'code': 'yin_jiangjun', 'name': '寅将军', 'ai_tier': 'boss', 'base_hp': 380, 'base_speed': 58, 'contact_damage': 14, 'size_scale': 1.9, 'exp_drop': 50, 'merit_drop': 20},
  {'code': 'yao_pig', 'name': '野猪精', 'ai_tier': 'normal', 'base_hp': 40, 'base_speed': 60, 'contact_damage': 8, 'size_scale': 1.0, 'exp_drop': 5},
  {'code': 'lang_yao', 'name': '狼妖', 'ai_tier': 'normal', 'base_hp': 30, 'base_speed': 92, 'contact_damage': 6, 'size_scale': 0.9, 'exp_drop': 5},
  {'code': 'hou_yao', 'name': '猴妖', 'ai_tier': 'normal', 'base_hp': 35, 'base_speed': 80, 'contact_damage': 7, 'size_scale': 0.95, 'exp_drop': 5},
  {'code': 'xiong_yao', 'name': '黑熊妖卒', 'ai_tier': 'elite', 'base_hp': 120, 'base_speed': 62, 'contact_damage': 11, 'size_scale': 1.35, 'exp_drop': 14},
  {'code': 'heixiong_jing', 'name': '黑熊精', 'ai_tier': 'boss', 'base_hp': 500, 'base_speed': 55, 'contact_damage': 15, 'size_scale': 2.0, 'exp_drop': 60, 'merit_drop': 20},
  // 高老庄段（关 12~14）
  {'code': 'zhu_yao', 'name': '猪妖', 'ai_tier': 'normal', 'base_hp': 60, 'base_speed': 58, 'contact_damage': 10, 'size_scale': 1.05, 'exp_drop': 7},
  {'code': 'shan_chao', 'name': '山魈', 'ai_tier': 'normal', 'base_hp': 55, 'base_speed': 74, 'contact_damage': 9, 'size_scale': 1.0, 'exp_drop': 7},
  {'code': 'diao_yao', 'name': '雕妖', 'ai_tier': 'normal', 'base_hp': 48, 'base_speed': 100, 'contact_damage': 8, 'size_scale': 0.85, 'exp_drop': 7},
  {'code': 'huangfeng_jing', 'name': '黄风怪', 'ai_tier': 'boss', 'base_hp': 900, 'base_speed': 60, 'contact_damage': 18, 'size_scale': 2.1, 'exp_drop': 90, 'merit_drop': 30},
  // 流沙河段（关 15~19）
  {'code': 'shui_yao', 'name': '水妖', 'ai_tier': 'normal', 'base_hp': 85, 'base_speed': 55, 'contact_damage': 12, 'size_scale': 1.05, 'exp_drop': 9},
  {'code': 'sha_yao', 'name': '沙妖', 'ai_tier': 'normal', 'base_hp': 75, 'base_speed': 68, 'contact_damage': 11, 'size_scale': 1.0, 'exp_drop': 9},
  {'code': 'he_guai', 'name': '河怪', 'ai_tier': 'elite', 'base_hp': 220, 'base_speed': 52, 'contact_damage': 15, 'size_scale': 1.4, 'exp_drop': 20},
  // 白虎岭段（关 20）
  {'code': 'gutou_bing', 'name': '骷髅兵', 'ai_tier': 'normal', 'base_hp': 110, 'base_speed': 64, 'contact_damage': 14, 'size_scale': 1.0, 'exp_drop': 12},
  {'code': 'baigu_yaozu', 'name': '白骨妖卒', 'ai_tier': 'normal', 'base_hp': 95, 'base_speed': 76, 'contact_damage': 13, 'size_scale': 0.95, 'exp_drop': 12},
  {'code': 'yemao_jing', 'name': '野猫精', 'ai_tier': 'elite', 'base_hp': 260, 'base_speed': 88, 'contact_damage': 16, 'size_scale': 1.3, 'exp_drop': 26},
  {'code': 'baigu_jing', 'name': '白骨精', 'ai_tier': 'boss', 'base_hp': 2400, 'base_speed': 52, 'contact_damage': 22, 'size_scale': 2.3, 'exp_drop': 220, 'merit_drop': 60},
  // 原著妖王群像（白虎岭之后各章回实际妖怪，区域 boss_code 驱动）
  {'code': 'huangpao_guai', 'name': '黄袍怪', 'ai_tier': 'boss', 'base_hp': 3400, 'base_speed': 54, 'contact_damage': 24, 'size_scale': 2.3, 'exp_drop': 260, 'merit_drop': 70},
  {'code': 'jinjiao_dawang', 'name': '金角大王', 'ai_tier': 'boss', 'base_hp': 4200, 'base_speed': 52, 'contact_damage': 26, 'size_scale': 2.4, 'exp_drop': 320, 'merit_drop': 80},
  {'code': 'shili_guai', 'name': '狮猁怪', 'ai_tier': 'boss', 'base_hp': 5000, 'base_speed': 52, 'contact_damage': 28, 'size_scale': 2.4, 'exp_drop': 380, 'merit_drop': 90},
  {'code': 'honghaier', 'name': '圣婴大王·红孩儿', 'ai_tier': 'boss', 'base_hp': 6000, 'base_speed': 58, 'contact_damage': 30, 'size_scale': 2.3, 'exp_drop': 460, 'merit_drop': 100},
  {'code': 'tuolong', 'name': '鼍龙', 'ai_tier': 'boss', 'base_hp': 6800, 'base_speed': 54, 'contact_damage': 30, 'size_scale': 2.4, 'exp_drop': 520, 'merit_drop': 110},
  {'code': 'huli_daxian', 'name': '虎力大仙', 'ai_tier': 'boss', 'base_hp': 7600, 'base_speed': 52, 'contact_damage': 32, 'size_scale': 2.4, 'exp_drop': 580, 'merit_drop': 120},
  {'code': 'linggan_dawang', 'name': '灵感大王', 'ai_tier': 'boss', 'base_hp': 8400, 'base_speed': 54, 'contact_damage': 32, 'size_scale': 2.5, 'exp_drop': 640, 'merit_drop': 130},
  {'code': 'dujiao_si', 'name': '独角兕大王', 'ai_tier': 'boss', 'base_hp': 9200, 'base_speed': 52, 'contact_damage': 34, 'size_scale': 2.5, 'exp_drop': 700, 'merit_drop': 140},
  {'code': 'xiezi_jing', 'name': '蝎子精', 'ai_tier': 'boss', 'base_hp': 10000, 'base_speed': 56, 'contact_damage': 34, 'size_scale': 2.4, 'exp_drop': 760, 'merit_drop': 150},
  {'code': 'liuer_mihou', 'name': '六耳猕猴', 'ai_tier': 'boss', 'base_hp': 10800, 'base_speed': 60, 'contact_damage': 36, 'size_scale': 2.3, 'exp_drop': 820, 'merit_drop': 160},
  {'code': 'niu_mowang', 'name': '牛魔王', 'ai_tier': 'boss', 'base_hp': 11600, 'base_speed': 54, 'contact_damage': 38, 'size_scale': 2.6, 'exp_drop': 880, 'merit_drop': 170},
  {'code': 'jiutou_chong', 'name': '九头虫', 'ai_tier': 'boss', 'base_hp': 12400, 'base_speed': 56, 'contact_damage': 38, 'size_scale': 2.5, 'exp_drop': 940, 'merit_drop': 180},
  {'code': 'shibagong', 'name': '劲节十八公', 'ai_tier': 'boss', 'base_hp': 13000, 'base_speed': 50, 'contact_damage': 38, 'size_scale': 2.4, 'exp_drop': 990, 'merit_drop': 190},
  {'code': 'huangmei_dawang', 'name': '黄眉大王', 'ai_tier': 'boss', 'base_hp': 13800, 'base_speed': 52, 'contact_damage': 40, 'size_scale': 2.5, 'exp_drop': 1050, 'merit_drop': 200},
  {'code': 'honglin_mang', 'name': '红鳞大蟒', 'ai_tier': 'boss', 'base_hp': 14400, 'base_speed': 56, 'contact_damage': 40, 'size_scale': 2.6, 'exp_drop': 1100, 'merit_drop': 210},
  {'code': 'sai_taishui', 'name': '赛太岁', 'ai_tier': 'boss', 'base_hp': 15000, 'base_speed': 54, 'contact_damage': 42, 'size_scale': 2.5, 'exp_drop': 1160, 'merit_drop': 220},
  {'code': 'baiyan_mojun', 'name': '百眼魔君', 'ai_tier': 'boss', 'base_hp': 15600, 'base_speed': 54, 'contact_damage': 42, 'size_scale': 2.5, 'exp_drop': 1220, 'merit_drop': 230},
  {'code': 'dapeng', 'name': '大鹏金翅雕', 'ai_tier': 'boss', 'base_hp': 16200, 'base_speed': 60, 'contact_damage': 44, 'size_scale': 2.6, 'exp_drop': 1280, 'merit_drop': 240},
  {'code': 'bailu_jing', 'name': '白鹿精', 'ai_tier': 'boss', 'base_hp': 16800, 'base_speed': 54, 'contact_damage': 44, 'size_scale': 2.4, 'exp_drop': 1330, 'merit_drop': 250},
  {'code': 'laoshu_jing', 'name': '金鼻白毛老鼠精', 'ai_tier': 'boss', 'base_hp': 17400, 'base_speed': 56, 'contact_damage': 46, 'size_scale': 2.3, 'exp_drop': 1390, 'merit_drop': 260},
  {'code': 'nanshan_dawang', 'name': '南山大王', 'ai_tier': 'boss', 'base_hp': 18000, 'base_speed': 54, 'contact_damage': 46, 'size_scale': 2.4, 'exp_drop': 1450, 'merit_drop': 270},
  {'code': 'jiuling_yuansheng', 'name': '九灵元圣', 'ai_tier': 'boss', 'base_hp': 18600, 'base_speed': 52, 'contact_damage': 48, 'size_scale': 2.7, 'exp_drop': 1510, 'merit_drop': 280},
  {'code': 'pihan_dawang', 'name': '辟寒大王', 'ai_tier': 'boss', 'base_hp': 19200, 'base_speed': 54, 'contact_damage': 48, 'size_scale': 2.5, 'exp_drop': 1570, 'merit_drop': 290},
  {'code': 'yutu_jing', 'name': '玉兔精', 'ai_tier': 'boss', 'base_hp': 19800, 'base_speed': 58, 'contact_damage': 50, 'size_scale': 2.3, 'exp_drop': 1630, 'merit_drop': 300},
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

/// 天赋 85 层：5 系×(16 常规+1 标志强化)，相生相克前置。
/// 天赋点总量 81（首通 1 点/难），不可全满强制取舍。
/// seq 为**元素内层号**（1..17），前置判定与进度键均按 element:seq；
/// 展示顺序由五系常量顺序保证，与 seq 无关。
List<Map<String, dynamic>> buildJourneyTalentSeed() {
  // 每系 17 行（seq 1..17），seq 17=标志层。
  const plans = <String, int>{
    'metal': 17,
    'wood': 17,
    'water': 17,
    'fire': 17,
    'earth': 17,
  };
  const attrByElement = <String, List<String>>{
    'metal': ['attack', 'crit_damage'],
    'wood': ['max_hp', 'regen'],
    'water': ['attack_speed', 'projectile_speed'],
    'fire': ['damage_amp', 'burn'],
    'earth': ['armor', 'knockback', 'pickup_range'],
  };
  // 常规层西游名号（与 journey_talents SQL 命名口径一致：前缀+层号罗马数字）
  const nameByAttr = <String, String>{
    'attack': '锐金·攻伐',
    'crit_damage': '锐金·破煞',
    'max_hp': '青木·固本',
    'regen': '青木·回息',
    'attack_speed': '玄水·疾涌',
    'projectile_speed': '玄水·奔流',
    'damage_amp': '离火·威烈',
    'burn': '离火·焚灼',
    'armor': '厚土·镇岳',
    'knockback': '厚土·震荡',
    'pickup_range': '厚土·承纳',
  };
  const signature = <String, List<String>>{
    'metal': ['锐金·破阵', '攻击无视目标护甲（穿透），暴击伤害大幅提升'],
    'wood': ['青木·回春', '自动回复翻倍，生命上限突破 +10%'],
    'water': ['玄水·流转', '攻速上限突破至 +75%，弹体+1'],
    'fire': ['离火·焚天', '灼烧可叠加，持续伤害翻倍'],
    'earth': ['厚土·不动', '周期护盾（每 20s 抵消一次接触伤害），拾取磁吸全屏'],
  };
  const roman = <String>[
    'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ',
    'ⅩⅠ', 'ⅩⅡ', 'ⅩⅢ', 'ⅩⅣ', 'ⅩⅤ', 'ⅩⅥ',
  ];
  final rows = <Map<String, dynamic>>[];
  plans.forEach((element, count) {
    final attrs = attrByElement[element]!;
    for (var i = 0; i < count; i++) {
      final seq = i + 1;
      final isSig = seq == count;
      rows.add(<String, dynamic>{
        'element': element,
        'seq': seq,
        'name': isSig
            ? signature[element]![0]
            : '${nameByAttr[attrs[i % attrs.length]]} ${roman[i]}',
        'attr_key': isSig ? 'signature_$element' : attrs[i % attrs.length],
        'value_per_level': 1,
        'is_signature': isSig,
        'signature_desc': isSig ? signature[element]![1] : '',
      });
    }
  });
  return rows;
}

/// 武器维度槽定义兜底（远端 journey_weapon_slots 优先）。
/// 6 主动槽=维度槽：初始武器占 1 特效槽（角色映射见引擎），空槽由
/// 三选一「习得」卡填入；每级效果/上限为运营配置，此处仅兜底。
const List<Map<String, dynamic>> kJourneySlotDefSeed =
    <Map<String, dynamic>>[
  {'code': 'radius', 'name': '臂展', 'kind': 'attribute', 'effect_per_level': '武器臂长 +14（受击环带变宽，武器等比变大）', 'max_level': 4},
  {'code': 'speed', 'name': '转速', 'kind': 'attribute', 'effect_per_level': '环绕转速 +10%', 'max_level': 4},
  {'code': 'damage', 'name': '伤害', 'kind': 'attribute', 'effect_per_level': '武器伤害 +20%', 'max_level': 4},
  {'code': 'knockback', 'name': '击退', 'kind': 'effect', 'effect_per_level': '命中击退距离 +16', 'max_level': 3},
  {'code': 'lifesteal', 'name': '吸血', 'kind': 'effect', 'effect_per_level': '命中回复武器伤害的 5%', 'max_level': 3},
  {'code': 'pierce', 'name': '穿刺', 'kind': 'effect', 'effect_per_level': '武器伤害 +15%（穿透加成）', 'max_level': 3},
  {'code': 'magnet', 'name': '磁吸', 'kind': 'effect', 'effect_per_level': '拾取范围 +40', 'max_level': 3},
  {'code': 'burn', 'name': '灼烧', 'kind': 'effect', 'effect_per_level': '命中点燃：8/秒 持续 2 秒（可刷新）', 'max_level': 3},
];
