import 'dart:convert';
import 'package:flutter/foundation.dart';

/// 统一请求日志子系统（从 http_client 抽取，保持输出格式完全一致）。
/// 仅用于 debug 模式下的请求可视化，不参与任何请求逻辑。

const String logDivider =
    '════════════════════════════════════════════════';

/// 是否敏感字段（日志脱敏，避免泄露密码/令牌等凭据）
bool isSensitiveKey(String key) {
  final k = key.toLowerCase();
  return k.contains('password') ||
      k.contains('token') ||
      k == 'authorization' ||
      k.contains('secret') ||
      k.contains('otp') ||
      k == 'code' ||
      k.contains('credential');
}

/// 将请求入参转为可打印字符串，并对敏感字段脱敏
String describeParams(Object? params) {
  if (params == null) return '';
  if (params is Map) {
    final redacted = <String, dynamic>{};
    params.forEach((k, v) {
      final key = k.toString();
      redacted[key] = isSensitiveKey(key) ? '******' : v;
    });
    try {
      return jsonEncode(redacted);
    } catch (_) {
      return redacted.toString();
    }
  }
  if (params is String) {
    try {
      final decoded = jsonDecode(params);
      if (decoded is Map) {
        final redacted = <String, dynamic>{};
        decoded.forEach((k, v) {
          final key = k.toString();
          redacted[key] = isSensitiveKey(key) ? '******' : v;
        });
        return jsonEncode(redacted);
      }
    } catch (_) {}
    return params;
  }
  return params.toString();
}

/// 截断过长的字符串（响应体可能很大，避免刷屏）
String truncate(String s, [int max = 800]) {
  if (s.length <= max) return s;
  return '${s.substring(0, max)} …(已截断，原长 ${s.length} 字符)';
}

/// 统一请求日志：打印 方法 + 地址 + 入参 + 耗时 + 状态码/错误 + 响应体
/// 用分隔线包裹，每条请求独立成块；仅在 debug 模式输出
void logRequest({
  required String? method,
  required String? url,
  required Object? params,
  required Duration duration,
  int? statusCode,
  Object? error,
  String? responseBody,
  String? note,
}) {
  if (!kDebugMode) return;
  final sb = StringBuffer();
  sb.writeln(logDivider);
  if (note != null && note.isNotEmpty) {
    sb.writeln('📝 备注: $note');
  }
  sb.writeln('🌐 [HTTP] ${method ?? '?'} ${url ?? ''}');
  final paramStr = describeParams(params);
  if (paramStr.isNotEmpty) sb.writeln('   入参: $paramStr');
  sb.write('   耗时: ${duration.inMilliseconds}ms');
  if (statusCode != null) sb.write(' | 状态码: $statusCode');
  if (error != null) sb.write(' | 错误: $error');
  sb.writeln();
  if (responseBody != null && responseBody.isNotEmpty) {
    sb.writeln('   响应: ${truncate(responseBody)}');
  }
  sb.writeln(logDivider);
  // [临时] 调试补签 400 时恢复打印；定位后请重新注释本行
  debugPrint(sb.toString());
}
