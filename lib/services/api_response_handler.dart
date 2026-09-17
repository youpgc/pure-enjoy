import 'dart:convert';
import './api_response.dart';
import './api_logger.dart';

/// 处理 HTTP 响应（从 ApiClient._handleResponse 抽出，纯函数）
ApiResponse handleApiResponse(dynamic response) {
  if (response == null) {
    return ApiResponse.error('网络请求失败: 无响应', statusCode: 0);
  }
  final statusCode = response.statusCode;

  if (statusCode >= 200 && statusCode < 300) {
    try {
      final body = response.body;
      // PATCH/PUT 带 Prefer: return=representation 时：
      //   200 + 有数据 = 更新成功
      //   204 + 空 body = 无匹配行（RLS 拦截或过滤条件无结果）
      if (body.isEmpty) {
        // 204 No Content：对写操作（PATCH/PUT/DELETE）意味着 0 行被更新
        if (statusCode == 204) {
          return ApiResponse.error('更新失败：未匹配到任何记录', statusCode: statusCode);
        }
        return ApiResponse.success([], statusCode: statusCode);
      }
      final decoded = jsonDecode(body);
      if (decoded is List<dynamic>) {
        // 常规表查询 / 返回集合的 RPC：数组响应
        return ApiResponse.success(
          decoded.cast<Map<String, dynamic>>(),
          statusCode: statusCode,
        );
      }
      // 单对象 / 标量响应（如 grant_game_reward 的 jsonb 标量、聚合 RPC 返回单值）：
      // 承载于 raw，data 置空列表以保持 List 契约不变，避免 '_Map is not List' 转换异常。
      return ApiResponse.success(
        <Map<String, dynamic>>[],
        statusCode: statusCode,
        raw: decoded,
      );
    } catch (e) {
      ApiLogger.error('❌ 响应解析失败', error: e);
      return ApiResponse.error('数据解析异常', statusCode: statusCode);
    }
  } else if (statusCode == 401) {
    return ApiResponse.error('未授权，请重新登录', statusCode: statusCode);
  } else {
    // 4xx/5xx：优先透传服务端 message（PostgREST/RPC 业务错误，如 PET_REARING_FULL、
    // 唯一/外键冲突详情），便于上层 petRpcErrorText 等映射为中文；取不到再降级通用文案。
    var msg = '服务器响应异常 (HTTP $statusCode)';
    if (statusCode == 404) {
      msg = '资源不存在';
    } else if (statusCode == 409) {
      msg = '数据冲突';
    } else if (statusCode == 429) {
      msg = '请求过于频繁，请稍后再试';
    }
    try {
      final body = response.body;
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final m = decoded['message'];
          if (m is String && m.isNotEmpty) msg = m;
        }
      }
    } catch (_) {
      // 非 JSON body，保留通用文案
    }
    if (statusCode >= 500) {
      ApiLogger.error('❌ HTTP 错误 [$statusCode]: ${response.body}');
    }
    return ApiResponse.error(msg, statusCode: statusCode);
  }
}
