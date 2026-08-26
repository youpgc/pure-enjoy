import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../services/http_client.dart';

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

/// 星座运势服务
///
/// 数据源：国内免费公开接口 api.vvhan.com（无需 key，App 直连），返回中文运势文案。
/// 失败时静默降级（返回 null），由 UI 决定不展示，不影响首页其它内容。
///
/// 注意：该接口返回结构社区通用形态为 { code, msg, data:{ name, day, text, ... } }，
/// 此处做多字段容错解析（text / content / description / all / summary 等），
/// 即使字段名随版本变动也不崩、缺失时仅不展示。
class HoroscopeService {
  static const String _endpoint = 'https://api.vvhan.com/api/horoscope';

  /// 进程内缓存：key = "signKey|dateKey"，避免同一天重复请求 / 重建时重拉
  static final Map<String, String> _cache = {};

  /// 获取指定星座的「今日运势」文案；失败 / 无数据时返回 null
  ///
  /// [signName] 为星座中文名（如 双子座），用于拼接接口参数。
  static Future<String?> getDailyHoroscope(String signName) async {
    final cacheKey = '$signName|${_todayKey()}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final url =
        '$_endpoint?type=today&sign=${Uri.encodeComponent(signName)}';
    try {
      final resp = await HttpClient.instance.rawRequest(
        url,
        method: 'GET',
        timeout: const Duration(seconds: 10),
        note: 'horoscope',
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final text = _extractText(resp.body);
        if (kDebugMode) {
          debugPrint(
            '[星座运势] status=${resp.statusCode} '
            '提取文案=${text == null ? "null(未匹配字段)" : text.length >= 40 ? "${text.substring(0, 40)}..." : text} '
            '原文前120=${resp.body.length >= 120 ? resp.body.substring(0, 120) : resp.body}',
          );
        }
        if (text != null && text.isNotEmpty) {
          _cache[cacheKey] = text;
          return text;
        }
      } else {
        if (kDebugMode) {
          debugPrint('[星座运势] 非 2xx 响应: status=${resp.statusCode} body=${resp.body}');
        }
      }
    } catch (e) {
      // 网络异常 / 接口不可用：静默降级，不抛异常、不阻断首页
      if (kDebugMode) debugPrint('⚠️ 星座运势获取失败: $e');
    }
    return null;
  }

  /// 从响应体容错提取运势文案
  /// 兼容形态：
  ///   { data:{ text / content / description / all / summary } }
  ///   { text / content / description / horoscope }
  static String? _extractText(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;

      // 1) 优先取 data 内部常见字段
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final candidates = [
          data['text'],
          data['content'],
          data['description'],
          data['all'],
          data['summary'],
          data['horoscope'],
        ];
        for (final c in candidates) {
          if (c is String && c.trim().isNotEmpty) return c.trim();
        }
      }

      // 2) 退化到顶层常见字段
      final topCandidates = [
        json['text'],
        json['content'],
        json['description'],
        json['horoscope'],
      ];
      for (final c in topCandidates) {
        if (c is String && c.trim().isNotEmpty) return c.trim();
      }
    } catch (_) {
      // 解析失败：返回 null
    }
    return null;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
