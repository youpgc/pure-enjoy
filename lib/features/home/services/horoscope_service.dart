import 'package:flutter/foundation.dart';

/// 星座信息
class ZodiacSign {
  /// 英文 key，用于接口参数（小写），如 gemini
  final String key;

  /// 中文名，如 双子座
  final String name;

  const ZodiacSign(this.key, this.name);
}

/// 根据生日字符串（yyyy-MM-dd）推算星座；生日缺失或非法时返回 null
ZodiacSign? zodiacSignFromBirthday(String? birthday) {
  if (birthday == null || birthday.isEmpty) return null;
  final d = DateTime.tryParse(birthday);
  if (d == null) return null;
  return zodiacSignFromDate(d);
}

/// 根据日期推算星座（按公历区间）
ZodiacSign? zodiacSignFromDate(DateTime d) {
  final int m = d.month;
  final int day = d.day;

  if ((m == 1 && day >= 20) || (m == 2 && day <= 18)) {
    return const ZodiacSign('aquarius', '水瓶座');
  }
  if ((m == 2 && day >= 19) || (m == 3 && day <= 20)) {
    return const ZodiacSign('pisces', '双鱼座');
  }
  if ((m == 3 && day >= 21) || (m == 4 && day <= 19)) {
    return const ZodiacSign('aries', '白羊座');
  }
  if ((m == 4 && day >= 20) || (m == 5 && day <= 20)) {
    return const ZodiacSign('taurus', '金牛座');
  }
  if ((m == 5 && day >= 21) || (m == 6 && day <= 21)) {
    return const ZodiacSign('gemini', '双子座');
  }
  if ((m == 6 && day >= 22) || (m == 7 && day <= 22)) {
    return const ZodiacSign('cancer', '巨蟹座');
  }
  if ((m == 7 && day >= 23) || (m == 8 && day <= 22)) {
    return const ZodiacSign('leo', '狮子座');
  }
  if ((m == 8 && day >= 23) || (m == 9 && day <= 22)) {
    return const ZodiacSign('virgo', '处女座');
  }
  if ((m == 9 && day >= 23) || (m == 10 && day <= 23)) {
    return const ZodiacSign('libra', '天秤座');
  }
  if ((m == 10 && day >= 24) || (m == 11 && day <= 22)) {
    return const ZodiacSign('scorpio', '天蝎座');
  }
  if ((m == 11 && day >= 23) || (m == 12 && day <= 21)) {
    return const ZodiacSign('sagittarius', '射手座');
  }
  // 12.22 - 次年 1.19
  return const ZodiacSign('capricorn', '摩羯座');
}

/// 运势结果（完整信息），供卡片展示
class HoroscopeResult {
  /// 当日运势文案
  final String text;

  /// 幸运数字
  final String luckyNumber;

  /// 幸运颜色
  final String luckyColor;

  /// 幸运方位
  final String luckyDirection;

  /// 幸运时间
  final String luckyTime;

  /// 速配星座
  final String matchSign;

  /// 分项运势星级（1~5 星），维度见 [_ratingDims]
  final Map<String, int> ratings;

  const HoroscopeResult({
    required this.text,
    required this.luckyNumber,
    required this.luckyColor,
    required this.luckyDirection,
    required this.luckyTime,
    required this.matchSign,
    required this.ratings,
  });
}

/// 星座符号（用于卡片图标展示），按中文名索引
const Map<String, String> zodiacSymbol = {
  '水瓶座': '♒',
  '双鱼座': '♓',
  '白羊座': '♈',
  '金牛座': '♉',
  '双子座': '♊',
  '巨蟹座': '♋',
  '狮子座': '♌',
  '处女座': '♍',
  '天秤座': '♎',
  '天蝎座': '♏',
  '射手座': '♐',
  '摩羯座': '♑',
};

/// 幸运数字 / 颜色 / 方位 / 时间池（日期种子选取）
const List<String> _luckyNumbers = ['1', '3', '5', '7', '8', '9', '2', '6', '4'];
const List<String> _luckyColors = [
  '红色', '橙色', '黄色', '绿色', '蓝色', '紫色', '粉色', '白色', '金色'
];
const List<String> _luckyDirections = [
  '正东', '正南', '正西', '正北', '东南', '西南', '东北', '西北'
];
const List<String> _luckyTimes = [
  '清晨 6-8 点', '上午 9-11 点', '中午 12-14 点', '下午 15-17 点', '傍晚 18-20 点', '夜晚 21-23 点'
];

/// 分项运势维度（用于星级评分展示，顺序即卡片展示顺序）
const List<String> _ratingDims = ['整体', '事业', '财运', '爱情', '健康'];

/// 星座运势服务（内置离线数据集，稳定可用）
///
/// 设计说明：原依赖的第三方免费公开接口（api.vvhan.com 等）在 2026 年已陆续停服 /
/// DNS 失效 / 返回 404，导致首页运势长期拉取失败。为避免再次因外部接口不稳定而
/// 「功能时灵时不灵」，改为内置中文运势文案数据集：
///   - 完全离线，不依赖任何外部网络，首页永远能展示；
///   - 按「星座序号 + 一年中的第几天」做日期种子，每天轮换、各星座不同；
///   - 文案为正向、适合欢迎卡单行展示的短句。
///
/// 若后续需要「真实每日运势数据」，可在此函数内优先请求稳定的付费/鉴权接口
/// （如天行数据、聚合数据，需申请 key），失败时再回退到本数据集即可。
class HoroscopeService {
  /// 各星座运势文案池（按中文名索引）；数量可自由扩充。
  static const Map<String, List<String>> _pool = {
    '水瓶座': [
      '今天灵感迸发，适合尝试新鲜的点子，别被条条框框束缚。',
      '社交运不错，朋友的一句话可能点醒你困扰已久的问题。',
      '保持独立判断，随波逐流反而会错失好机会。',
      '理性与感性今天难得平衡，重大决策可放心推进。',
      '给生活留一点空白，你会发现比忙碌更有收获。',
      '好奇心是最好的向导，今天去了解一件没接触过的事吧。',
    ],
    '双鱼座': [
      '直觉今天很准，相信第一感觉往往不会错。',
      '温柔待人的同时，也别忘了照顾自己的情绪。',
      '适合把酝酿已久的创意落到纸面，会有意外进展。',
      '人际关系回暖，一句主动的问候能化解隔阂。',
      '放慢脚步，音乐或散步能帮你找回内心的平静。',
      '别把别人的期待当成自己的负担，你本就足够好。',
    ],
    '白羊座': [
      '行动力爆棚，想做的事今天就迈出第一步。',
      '冲劲虽好，先听一遍不同意见能少走弯路。',
      '今天的你自带气场，谈判或表达都更有底气。',
      '把注意力收回到最重要的一件事上，效率翻倍。',
      '小挫折别挂心，你的复原力比想象中强。',
      '带领团队时多给同伴一点肯定，成果会更稳。',
    ],
    '金牛座': [
      '稳扎稳打的一天，长期坚持的事开始看到回报。',
      '财运平稳，理性消费能帮你攒下小惊喜。',
      '亲手做点什么会让你特别踏实，哪怕是整理房间。',
      '别被短期波动干扰，你的节奏本就比别人更稳。',
      '味觉今天很敏锐，好好吃一顿犒劳自己。',
      '对在乎的人多些耐心，关系会比平时更暖。',
    ],
    '双子座': [
      '思维活跃，适合处理需要灵活应变的事。',
      '今天沟通运极佳，表达想法别人更容易买账。',
      '多线程并行也没问题，但别忘了给重要事留时间。',
      '一个新信息可能打开你没想到的大门。',
      '好奇心带你认识有趣的人，别拒绝邀约。',
      '把碎片想法记下来，晚上回看会有串联的惊喜。',
    ],
    '巨蟹座': [
      '家的温暖今天格外重要，给家人发个消息吧。',
      '细腻的你容易察觉别人忽略的情绪，善用它而非内耗。',
      '安全感来自规划，列个清单会让心里踏实不少。',
      '旧友可能主动联系，一段关系悄悄回暖。',
      '照顾好自己的胃和睡眠，状态就会回来。',
      '付出值得被看见，今天也请为自己说句话。',
    ],
    '狮子座': [
      '今天你就是聚光灯，展现自我正当其时。',
      '慷慨分享会让你收获更多意想不到的支持。',
      '创意点子被认可的概率很高，大胆说出来。',
      '领导气质在线，团队需要你拍板时就别犹豫。',
      '适度的炫耀无妨，自信本身就是一种吸引力。',
      '把光芒也分给身边的人，你会赢得更真的心。',
    ],
    '处女座': [
      '条理清晰的一天，复杂任务也能被你拆得明明白白。',
      '细节决定成败，你的认真今天会被人记住。',
      '别追求完美到卡住，完成比完美更重要。',
      '整理环境会同步整理心情，一举两得。',
      '帮别人把关时，也给自己留一点松弛空间。',
      '健康作息是最好的投资，今晚早点休息。',
    ],
    '天秤座': [
      '纠结的事今天容易找到平衡点，相信你的审美。',
      '人际和谐运强，误会能在轻松聊天中化解。',
      '做选择时优先考虑「让自己舒服」，别总迁就。',
      '审美在线，今天适合给生活添一点美感。',
      '公平待人的你，也会被人公平以待。',
      '独处片刻能让摇摆的天平重新稳住。',
    ],
    '天蝎座': [
      '洞察力今天格外锋利，看人看事别被表象骗。',
      '专注深挖一件事，你会比谁都更快摸到门道。',
      '沉默是金，有些话放在心里反而更有力量。',
      '旧账今天适合做个了结，轻装才好上路。',
      '直觉预警的事，宁可谨慎也别侥幸。',
      '信任要慢慢给，但一旦认定就别轻易动摇。',
    ],
    '射手座': [
      '向往自由的心今天特别旺，安排点新鲜体验。',
      '乐观感染力强，身边人会被你带动起来。',
      '长途或学习计划有进展，别半途而废。',
      '说走就走的冲动不妨落地成小行动。',
      '开阔眼界的事最对你胃口，去接触不同观点。',
      '直言直语没问题，但记得给敏感的人留台阶。',
    ],
    '摩羯座': [
      '脚踏实地的你，今天每一步都算数。',
      '长期布局进入兑现期，耐心没有白费。',
      '责任在肩也别忘了休息，张弛有度才走得远。',
      '把大目标拆成小节点，今天就能推进一截。',
      '低调做事的人，成果会自己说话。',
    ],
  };

  /// 星座中文名 -> 序号（用于日期种子错位，避免所有星座同一天雷同）
  static const List<String> _order = [
    '水瓶座',
    '双鱼座',
    '白羊座',
    '金牛座',
    '双子座',
    '巨蟹座',
    '狮子座',
    '处女座',
    '天秤座',
    '天蝎座',
    '射手座',
    '摩羯座',
  ];

  /// 获取指定星座的「今日运势」完整信息（文案 + 幸运数字/颜色/方位/时间/速配/分项星级）；
  /// 始终返回非空结果（离线内置）。
  ///
  /// [signName] 为星座中文名（如 双子座）。未知星座回退到通用文案。
  static Future<HoroscopeResult?> getDailyHoroscope(String signName) async {
    final signIndex = _order.indexOf(signName).clamp(0, _order.length - 1);
    final dayOfYear = _dayOfYear(DateTime.now());

    final list = _pool[signName];
    final text = (list == null || list.isEmpty)
        ? '保持好心情，今天也是值得期待的一天。'
        : list[(dayOfYear + signIndex) % list.length];

    final luckyNumber =
        _luckyNumbers[(dayOfYear + signIndex * 3) % _luckyNumbers.length];
    final luckyColor =
        _luckyColors[(dayOfYear + signIndex * 5) % _luckyColors.length];
    final luckyDirection =
        _luckyDirections[(dayOfYear + signIndex * 2) % _luckyDirections.length];
    final luckyTime =
        _luckyTimes[(dayOfYear + signIndex * 4) % _luckyTimes.length];
    // 速配星座：至少偏移 1，且日期种子稳定，避免与自身相同
    final matchOffset = 1 + (dayOfYear ~/ 7) % (_order.length - 1);
    final matchSign = _order[(signIndex + matchOffset) % _order.length];

    // 分项星级：每天稳定、各维度略有差异（1~5 星）
    final ratings = <String, int>{
      for (var i = 0; i < _ratingDims.length; i++)
        _ratingDims[i]: ((dayOfYear + signIndex * 7 + i * 3) % 5) + 1,
    };

    if (kDebugMode) {
      debugPrint(
        '[星座运势] 内置数据集命中 sign=$signName day=$dayOfYear -> $text | '
        '幸运$luckyNumber/$luckyColor/$luckyDirection/$luckyTime | 速配$matchSign | '
        '星级$ratings',
      );
    }
    return HoroscopeResult(
      text: text,
      luckyNumber: luckyNumber,
      luckyColor: luckyColor,
      luckyDirection: luckyDirection,
      luckyTime: luckyTime,
      matchSign: matchSign,
      ratings: ratings,
    );
  }

  /// 计算一年中的第几天（1-366）
  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }
}
