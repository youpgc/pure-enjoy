import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'supabase_service.dart';

/// 存储文件对象
class FileObject {
  final String name;
  final String? id;
  final int? createdAt;
  final int? updatedAt;
  final int? lastAccessedAt;
  final Map<String, dynamic>? metadata;

  FileObject({
    required this.name,
    this.id,
    this.createdAt,
    this.updatedAt,
    this.lastAccessedAt,
    this.metadata,
  });

  factory FileObject.fromJson(Map<String, dynamic> json) {
    return FileObject(
      name: json['name'] ?? '',
      id: json['id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      lastAccessedAt: json['last_accessed_at'],
      metadata: json['metadata'],
    );
  }
}

/// 存储异常
class StorageException implements Exception {
  final String message;
  final String? error;
  final String? statusCode;

  StorageException(this.message, {this.error, this.statusCode});

  @override
  String toString() => 'StorageException: $message';
}

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
    final authService = AuthService.instance;
    return {
      'apikey': _anonKey,
      'Authorization': 'Bearer ${authService.isAuthenticated ? authService.authHeaders['Authorization']?.replaceFirst('Bearer ', '') : _anonKey}',
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

      final response = await request.send();
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
      debugPrint('上传文件失败: $e');
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
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'expiresIn': expiresIn}),
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
      debugPrint('获取签名 URL 失败: $e');
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
      final response = await http.delete(uri, headers: _headers);

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
      debugPrint('删除文件失败: $e');
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
      final response = await http.delete(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'prefixes': paths}),
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
      debugPrint('删除多个文件失败: $e');
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
      final response = await http.get(uri, headers: _headers);

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
      debugPrint('列出文件失败: $e');
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
      final response = await http.get(uri, headers: _headers);

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
      debugPrint('下载文件失败: $e');
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
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bucketId': bucket,
          'sourceKey': sourcePath,
          'destinationKey': destinationPath,
        }),
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
      debugPrint('移动文件失败: $e');
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
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bucketId': bucket,
          'sourceKey': sourcePath,
          'destinationKey': destinationPath,
        }),
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
      debugPrint('复制文件失败: $e');
      rethrow;
    }
  }

  // ==================== 便捷方法 ====================

  /// 上传头像
  ///
  /// [userId] - 用户 ID
  /// [bytes] - 图片字节数据
  /// [contentType] - 图片类型，默认 image/jpeg
  Future<String> uploadAvatar(String userId, List<int> bytes, {String? contentType}) async {
    final path = 'avatars/$userId.jpg';
    return await uploadFile(
      bucket: AppConfig.avatarsBucket,
      path: path,
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
      upsert: true,
    );
  }

  /// 上传图片
  ///
  /// [folder] - 文件夹名称
  /// [fileName] - 文件名
  /// [bytes] - 图片字节数据
  /// [contentType] - 图片类型，默认 image/jpeg
  Future<String> uploadImage(String folder, String fileName, List<int> bytes, {String? contentType}) async {
    final path = '$folder/$fileName';
    return await uploadFile(
      bucket: AppConfig.imagesBucket,
      path: path,
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );
  }

  /// 上传心情日记图片
  ///
  /// [userId] - 用户 ID
  /// [diaryId] - 日记 ID
  /// [fileName] - 文件名
  /// [bytes] - 图片字节数据
  Future<String> uploadMoodDiaryImage(
    String userId,
    String diaryId,
    String fileName,
    List<int> bytes,
  ) async {
    final path = 'mood_diaries/$userId/$diaryId/$fileName';
    return await uploadFile(
      bucket: AppConfig.imagesBucket,
      path: path,
      bytes: bytes,
      contentType: 'image/jpeg',
    );
  }

  /// 上传笔记附件
  ///
  /// [userId] - 用户 ID
  /// [noteId] - 笔记 ID
  /// [fileName] - 文件名
  /// [bytes] - 文件字节数据
  /// [contentType] - 文件类型
  Future<String> uploadNoteAttachment(
    String userId,
    String noteId,
    String fileName,
    List<int> bytes, {
    String? contentType,
  }) async {
    final path = 'notes/$userId/$noteId/$fileName';
    return await uploadFile(
      bucket: AppConfig.imagesBucket,
      path: path,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// 删除头像
  Future<void> deleteAvatar(String userId) async {
    final path = 'avatars/$userId.jpg';
    await deleteFile(AppConfig.avatarsBucket, path);
  }

  /// 删除心情日记图片
  Future<void> deleteMoodDiaryImage(String userId, String diaryId, String fileName) async {
    final path = 'mood_diaries/$userId/$diaryId/$fileName';
    await deleteFile(AppConfig.imagesBucket, path);
  }

  /// 删除笔记附件
  Future<void> deleteNoteAttachment(String userId, String noteId, String fileName) async {
    final path = 'notes/$userId/$noteId/$fileName';
    await deleteFile(AppConfig.imagesBucket, path);
  }
}
