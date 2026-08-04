import '../config.dart';
import 'storage_service.dart';

/// 存储服务便捷方法（从 StorageService 抽出的薄封装层）
/// 仅依赖 StorageService 的公开 API（uploadFile / deleteFile）与 AppConfig，
/// 行为与原类内实现逐字节一致。
extension StorageServiceConvenience on StorageService {
  /// 上传头像
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
  Future<String> uploadImage(String folder, String fileName, List<int> bytes,
      {String? contentType}) async {
    final path = '$folder/$fileName';
    return await uploadFile(
      bucket: AppConfig.imagesBucket,
      path: path,
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );
  }

  /// 上传心情日记图片
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
