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

/// 详细运势解读（真实接口或内置回退统一结构）
class HoroscopeDetail {
  final String signName;
  final String overview;
  final Map<String, String> indices;
  final bool indicesArePercent;
  final String luckyColor;
  final String luckyNumber;
  final String? extraSign;
  final String? extraSignLabel;
  final bool fromRemote;

  const HoroscopeDetail({
    required this.signName,
    required this.overview,
    required this.indices,
    required this.indicesArePercent,
    required this.luckyColor,
    required this.luckyNumber,
    this.extraSign,
    this.extraSignLabel,
    required this.fromRemote,
  });

  /// 序列化为 JSON（供当日缓存持久化）
  Map<String, dynamic> toJson() => {
        'signName': signName,
        'overview': overview,
        'indices': indices,
        'indicesArePercent': indicesArePercent,
        'luckyColor': luckyColor,
        'luckyNumber': luckyNumber,
        'extraSign': extraSign,
        'extraSignLabel': extraSignLabel,
        'fromRemote': fromRemote,
      };

  /// 从 JSON 还原（[toJson] 的逆操作）
  factory HoroscopeDetail.fromJson(Map<String, dynamic> json) {
    return HoroscopeDetail(
      signName: json['signName'] as String,
      overview: json['overview'] as String,
      indices: Map<String, String>.from(
        (json['indices'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
      indicesArePercent: json['indicesArePercent'] as bool? ?? true,
      luckyColor: json['luckyColor'] as String? ?? '—',
      luckyNumber: json['luckyNumber'] as String? ?? '—',
      extraSign: json['extraSign'] as String?,
      extraSignLabel: json['extraSignLabel'] as String?,
      fromRemote: json['fromRemote'] as bool? ?? false,
    );
  }
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

/// 各星座公历日期范围（用于卡片展示），与 [zodiacSignFromDate] 区间一致
const Map<String, String> zodiacDateRange = {
  '水瓶座': '1.20 - 2.18',
  '双鱼座': '2.19 - 3.20',
  '白羊座': '3.21 - 4.19',
  '金牛座': '4.20 - 5.20',
  '双子座': '5.21 - 6.21',
  '巨蟹座': '6.22 - 7.22',
  '狮子座': '7.23 - 8.22',
  '处女座': '8.23 - 9.22',
  '天秤座': '9.23 - 10.23',
  '天蝎座': '10.24 - 11.22',
  '射手座': '11.23 - 12.21',
  '摩羯座': '12.22 - 1.19',
};
