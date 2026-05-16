import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Supabase 存储服务
class StorageService {
  static StorageService? _instance;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  // Supabase 客户端
  SupabaseClient get _client => Supabase.instance.client;

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

      await _client.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: upsert,
            ),
          );

      // 返回文件的公开 URL
      return getPublicUrl(bucket, path);
    } on StorageException catch (e) {
      debugPrint('上传文件失败: ${e.message}');
      rethrow;
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
    try {
      return _client.storage.from(bucket).getPublicUrl(path);
    } on StorageException catch (e) {
      debugPrint('获取公开 URL 失败: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('获取公开 URL 失败: $e');
      rethrow;
    }
  }

  /// 获取签名 URL（私有文件）
  ///
  /// [bucket] - 存储桶名称
  /// [path] - 文件路径
  /// [expiresIn] - URL 过期时间（秒），默认 3600 秒（1小时）
  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    try {
      final response = await _client.storage
          .from(bucket)
          .createSignedUrl(path, expiresIn);
      return response;
    } on StorageException catch (e) {
      debugPrint('获取签名 URL 失败: ${e.message}');
      rethrow;
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
      await _client.storage.from(bucket).remove([path]);
    } on StorageException catch (e) {
      debugPrint('删除文件失败: ${e.message}');
      rethrow;
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
      await _client.storage.from(bucket).remove(paths);
    } on StorageException catch (e) {
      debugPrint('删除多个文件失败: ${e.message}');
      rethrow;
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
      final response = await _client.storage.from(bucket).list(path: path);
      return response;
    } on StorageException catch (e) {
      debugPrint('列出文件失败: ${e.message}');
      rethrow;
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
      final response = await _client.storage.from(bucket).download(path);
      return response;
    } on StorageException catch (e) {
      debugPrint('下载文件失败: ${e.message}');
      rethrow;
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
      await _client.storage.from(bucket).move(sourcePath, destinationPath);
    } on StorageException catch (e) {
      debugPrint('移动文件失败: ${e.message}');
      rethrow;
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
      await _client.storage.from(bucket).copy(sourcePath, destinationPath);
    } on StorageException catch (e) {
      debugPrint('复制文件失败: ${e.message}');
      rethrow;
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
