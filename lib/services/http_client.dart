import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// 请求超时配置
class RequestTimeout {
  static const Duration simple = Duration(seconds: 10);   // 简单查询
  static const Duration list = Duration(seconds: 20);     // 列表查询
  static const Duration file = Duration(seconds: 60);     // 文件操作
  static const Duration download = Duration(seconds: 120); // 下载
}

/// 统一 HTTP 客户端
/// 使用共享 http.Client 实现连接复用 (Keep-Alive)
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();

  static HttpClient get instance => _instance;

  /// 共享 HTTP Client（连接复用）
  final http.Client _client = http.Client();

  /// 当前用户 ID（登录后设置）
  String? _userId;

  /// 设置用户 ID（登录后调用）
  void setUserId(String? userId) {
    _userId = userId;
    debugPrint('🔐 HttpClient userId set: $userId');
  }

  /// 获取当前用户 ID
  String? get userId => _userId;

  /// 构建统一 headers
  Map<String, String> _buildHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': 'sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6',
      'Prefer': 'return=representation',
    };
    // 注入 x-user-id（登录后）
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      headers['x-user-id'] = uid;
    } else {
      // 未登录时传默认值，让服务端不处理权限直接走逻辑
      headers['x-user-id'] = 'anonymous';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// GET 请求
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client
        .get(Uri.parse(url), headers: _buildHeaders(extra: headers))
        .timeout(timeout ?? RequestTimeout.simple);
    return response;
  }

  /// POST 请求
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: _buildHeaders(extra: headers),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(timeout ?? RequestTimeout.simple);
    return response;
  }

  /// PATCH 请求
  Future<http.Response> patch(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final response = await _client
        .patch(
          Uri.parse(url),
          headers: _buildHeaders(extra: headers),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(timeout ?? RequestTimeout.simple);
    return response;
  }

  /// DELETE 请求
  Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client
        .delete(Uri.parse(url), headers: _buildHeaders(extra: headers))
        .timeout(timeout ?? RequestTimeout.simple);
    return response;
  }

  /// 发送 http.Request（用于流式下载等）
  Future<http.StreamedResponse> send(http.Request request) async {
    // 注入 headers
    final built = _buildHeaders();
    built.forEach((key, value) {
      if (!request.headers.containsKey(key)) {
        request.headers[key] = value;
      }
    });
    return await _client.send(request).timeout(RequestTimeout.download);
  }

  /// 发送 MultipartRequest（用于文件上传）
  Future<http.StreamedResponse> sendMultipart(http.MultipartRequest request) async {
    // 注入 headers
    final built = _buildHeaders();
    built.forEach((key, value) {
      if (!request.headers.containsKey(key)) {
        request.headers[key] = value;
      }
    });
    return await _client.send(request).timeout(RequestTimeout.file);
  }

  /// 关闭客户端
  void close() {
    _client.close();
  }
}
