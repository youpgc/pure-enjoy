import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config.dart';
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

  String get _baseUrl => AppConfig.supabaseUrl;
  String get _anonKey => AppConfig.supabaseAnonKey;

  Map<String, String> get _headers {
    return {
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
    };
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
      final uri = Uri.parse('$_baseUrl/storage/v1/object/$bucket/$path');

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers);
      request.headers['x-upsert'] = upsert.toString();
      if (contentType != null) {
        request.headers['content-type'] = contentType;
      }

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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return getPublicUrl(bucket, path);
      } else {
        throw StorageException(
          '上传文件失败',
          error: responseBody,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('上传文件失败');
      rethrow;
    }
  }

  /// 获取文件公开 URL
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  String getPublicUrl(String bucket, String path) {
    return '$_baseUrl/storage/v1/object/public/$bucket/$path';
  }

  /// 获取签名 URL（私有文件）
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  /// [expiresIn] - URL 过期时间（秒），默认 3600 秒（1小时）
  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/sign/$bucket/$path');
      final response = await HttpClient.instance.post(
        uri.toString(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'expiresIn': expiresIn}),
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final signedUrl = data['signedURL'] as String?;
        if (signedUrl != null) {
          return '$_baseUrl$signedUrl';
        }
        throw StorageException('获取签名 URL 失败: 响应中无 signedURL');
      } else {
        throw StorageException(
          '获取签名 URL 失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('获取签名 URL 失败');
      rethrow;
    }
  }

  /// 删除文件
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  Future<void> deleteFile(String bucket, String path) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/$bucket/$path');
      final response = await HttpClient.instance.delete(
        uri.toString(),
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw StorageException(
          '删除文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('删除文件失败');
      rethrow;
    }
  }

  /// 删除多个文件
  ///
  /// [bucket] - 存储桶名称
  /// [paths] - 文件路径列表
  Future<void> deleteFiles(String bucket, List<String> paths) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/$bucket');
      final response = await HttpClient.instance.delete(
        uri.toString(),
        headers: {'Content-Type': 'application/json'},
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw StorageException(
          '删除多个文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('删除多个文件失败');
      rethrow;
    }
  }

  /// 列出文件
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件夹路径（可选）
  Future<List<FileObject>> listFiles(String bucket, {String? path}) async {
    try {
      final queryParams = <String, String>{};
      if (path != null && path.isNotEmpty) {
        queryParams['prefix'] = path;
      }

      final uri = Uri.parse('$_baseUrl/storage/v1/object/list/$bucket')
          .replace(queryParameters: queryParams);
      final response = await HttpClient.instance.get(
        uri.toString(),
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => FileObject.fromJson(item)).toList();
      } else {
        throw StorageException(
          '列出文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('列出文件失败');
      rethrow;
    }
  }

  /// 下载文件
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  Future<Uint8List> downloadFile(String bucket, String path) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/$bucket/$path');
      final response = await HttpClient.instance.get(
        uri.toString(),
        timeout: RequestTimeout.file,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      } else {
        throw StorageException(
          '下载文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('下载文件失败');
      rethrow;
    }
  }

  /// 移动文件
  ///
  /// [bucket] - 存储桶名称
  /// [sourcePath] - 源文件路径
  /// [destinationPath] - 目标文件路径
  Future<void> moveFile(String bucket, String sourcePath, String destinationPath) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/move');
      final response = await HttpClient.instance.post(
        uri.toString(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bucketId': bucket,
          'sourceKey': sourcePath,
          'destinationKey': destinationPath,
        }),
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw StorageException(
          '移动文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('移动文件失败');
      rethrow;
    }
  }

  /// 复制文件
  ///
  /// [bucket] - 存储桶名称
  /// [sourcePath] - 源文件路径
  /// [destinationPath] - 目标文件路径
  Future<void> copyFile(String bucket, String sourcePath, String destinationPath) async {
    try {
      final uri = Uri.parse('$_baseUrl/storage/v1/object/copy');
      final response = await HttpClient.instance.post(
        uri.toString(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bucketId': bucket,
          'sourceKey': sourcePath,
          'destinationKey': destinationPath,
        }),
        timeout: RequestTimeout.simple,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      } else {
        throw StorageException(
          '复制文件失败',
          error: response.body,
          statusCode: response.statusCode.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('复制文件失败');
      rethrow;
    }
  }

}
