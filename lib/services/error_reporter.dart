import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';
import 'http_client.dart';
import 'supabase_config.dart';

/// 全局客户端错误上报。
///
/// 在 [main] 中尽早调用 [ErrorReporter.init] 接管 Flutter 未处理异常与平台错误，
/// 统一上报到后台 [error_logs]（source = 'app'），供排障观测。
/// 上报为 fire-and-forget，失败不影响主流程。
class ErrorReporter {
  static String? _cachedAppVersion;

  static Future<String> get _appVersion async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = info.version;
    } catch (_) {
      _cachedAppVersion = 'unknown';
    }
    return _cachedAppVersion!;
  }

  /// 在 WidgetsFlutterBinding.ensureInitialized() 之后调用，接管全局异常。
  static void init() {
    FlutterError.onError = (details) {
      report(details.exception, details.stack, module: 'flutter');
    };
    // 捕获异步/平台层未处理错误（如原生回调异常）
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, module: 'platform');
      return true;
    };
  }

  /// 上报一次客户端错误（fire-and-forget）
  static void report(
    Object error,
    StackTrace? stack, {
    String module = 'app',
    String level = 'error',
  }) {
    _doReport(error, stack, module, level).catchError((_) {});
  }

  static Future<void> _doReport(
    Object error,
    StackTrace? stack,
    String module,
    String level,
  ) async {
    final version = await _appVersion;
    await HttpClient.instance.rawRequest(
      '${SupabaseConfig.url}/rest/v1/rpc/report_client_error',
      method: 'POST',
      headers: SupabaseConfig.headers,
      body: {
        'p_level': level,
        'p_module': module,
        'p_message': error.toString(),
        'p_detail': {'stack_trace': stack?.toString()},
        'p_source': 'app',
        'p_app_version': version,
      },
      timeout: RequestTimeout.simple,
    );
  }
}
