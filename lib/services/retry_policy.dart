import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './cancel_token.dart';
import './http_logger.dart';

/// 统一重试执行器：超时 / 取消 / 401 刷新 / 指数退避。
/// 从 [HttpClient._requestWithRetry] 抽离（治理 §1.5.5 膨胀防御）。
///
/// [onUnauthorized] 在收到 401 且 [handle401]=true 时调用，
/// 返回 true 表示刷新成功可重试当前请求；返回 false 则清空凭证并抛 [HttpException]。
/// 行为与原内联实现逐字节等价（默认 maxRetries=3、默认超时 30s 与 [HttpClientConfig] 一致）。
Future<http.Response> requestWithRetry(
  Future<http.Response> Function() request, {
  int maxRetries = 3,
  Duration? timeout,
  CancelToken? cancelToken,
  bool handle401 = true,
  String? logMethod,
  String? logUrl,
  Object? logParams,
  String? logNote,
  required Future<bool> Function() onUnauthorized,
}) async {
  http.Response? response;
  Exception? lastError;
  final requestTimeout = timeout ?? const Duration(seconds: 30);
  final sw = Stopwatch()..start();

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    // 请求前检查是否已取消
    if (cancelToken?.isCancelled == true) {
      sw.stop();
      logRequest(
        method: logMethod,
        url: logUrl,
        params: logParams,
        duration: sw.elapsed,
        error: '请求已取消',
        note: logNote,
      );
      throw RequestCancelledException();
    }

    try {
      response = await request().timeout(requestTimeout);

      // 响应后检查是否已取消（防止旧响应覆盖新数据）
      if (cancelToken?.isCancelled == true) {
        sw.stop();
        logRequest(
          method: logMethod,
          url: logUrl,
          params: logParams,
          duration: sw.elapsed,
          error: '请求已取消',
          note: logNote,
        );
        throw RequestCancelledException();
      }

      // 处理 401：尝试刷新 Token，失败才清空
      if (response.statusCode == 401) {
        if (!handle401) {
          // 调用方自行处理 401（如认证端点需返回错误响应而非抛异常）
          sw.stop();
          logRequest(
            method: logMethod,
            url: logUrl,
            params: logParams,
            duration: sw.elapsed,
            statusCode: response.statusCode,
            responseBody: response.body,
            note: logNote,
          );
          return response;
        }
        final refreshed = await onUnauthorized();
        if (refreshed) {
          continue; // Token 已刷新，重试当前请求
        }
        sw.stop();
        logRequest(
          method: logMethod,
          url: logUrl,
          params: logParams,
          duration: sw.elapsed,
          statusCode: 401,
          error: '401 未授权',
          note: logNote,
        );
        throw const HttpException('401_UNAUTHORIZED');
      }

      sw.stop();
      logRequest(
        method: logMethod,
        url: logUrl,
        params: logParams,
        duration: sw.elapsed,
        statusCode: response.statusCode,
        responseBody: response.body,
        note: logNote,
      );
      return response;
    } on RequestCancelledException {
      rethrow; // 取消异常不重试，直接抛出
    } on SocketException catch (e) {
      lastError = e;
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    } on HttpException catch (e) {
      lastError = e;
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    } catch (e) {
      lastError = e is Exception ? e : Exception(e.toString());
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
  }

  sw.stop();
  logRequest(
    method: logMethod,
    url: logUrl,
    params: logParams,
    duration: sw.elapsed,
    statusCode: response?.statusCode,
    error: lastError,
    responseBody: response?.body,
    note: logNote,
  );
  throw lastError ?? Exception('请求失败，已重试 $maxRetries 次');
}
