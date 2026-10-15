import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import './server_config.dart';
import './http_client.dart';
import './storage_models.dart';

export './storage_models.dart';

/// 存储文件对象与异常已抽到 storage_models.dart（见本文件顶部 export）

/// Supabase 存储服务
class StorageService {
  static StorageService? _instance;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }


  /// 上传文件
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  /// [bytes] - 文件字节数据
  /// [contentType] - 文件内容类型
  /// [upsert] - 是否覆盖已存在的文件
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
    bool upsert = false,
  }) async {
    try {
      final fileBytes = Uint8List.fromList(bytes);
      // B6 尾巴：上传走后端 /files/upload；唯一调用方=头像，category=avatar
      // 走免登录公开读（/files/public/{id}/content），返回即公开 URL
      final uri = Uri.parse('${ServerConfig.baseUrl}/api/v1/files/upload');

      final request = http.MultipartRequest('POST', uri);
      request.fields['category'] = 'avatar';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: path.split('/').last,
        ),
      );

      // 使用 HttpClient 发送，统一注入 headers 和超时保护
      final response = await HttpClient.instance.sendMultipart(request);
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StorageException(
          '上传文件失败',
          error: responseBody,
          statusCode: response.statusCode.toString(),
        );
      }
      final envelope = jsonDecode(responseBody) as Map<String, dynamic>;
      if (envelope['code'] != 200) {
        throw StorageException(
          '上传文件失败',
          error: envelope['message']?.toString() ?? responseBody,
        );
      }
      final meta = envelope['data'] as Map<String, dynamic>? ?? const {};
      final id = meta['id']?.toString();
      if (id == null || id.isEmpty) {
        throw StorageException('上传文件失败', error: '响应缺少文件 id');
      }
      return '${ServerConfig.baseUrl}/api/v1/files/public/$id/content';
    } catch (e) {
      if (kDebugMode) debugPrint('上传文件失败');
      rethrow;
    }
  }






}
