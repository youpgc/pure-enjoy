import 'package:supabase_flutter/supabase_flutter.dart';

/// 存储服务
class StorageService {
  static StorageService? _instance;
  late final SupabaseClient _client;
  
  StorageService._() {
    _client = Supabase.instance.client;
  }
  
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }
  
  /// 上传文件
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    final response = await _client.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(
          contentType: contentType,
        ));
    return response;
  }
  
  /// 获取文件公开URL
  String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
  
  /// 获取签名URL（私有文件）
  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    return await _client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
  }
  
  /// 删除文件
  Future<void> deleteFile(String bucket, String path) async {
    await _client.storage.from(bucket).remove([path]);
  }
  
  /// 列出文件
  Future<List<FileObject>> listFiles(String bucket, {String? path}) async {
    return await _client.storage.from(bucket).list(path: path);
  }
  
  /// 上传头像
  Future<String> uploadAvatar(String userId, List<int> bytes) async {
    final path = 'avatars/$userId.jpg';
    await uploadFile(
      bucket: 'avatars',
      path: path,
      bytes: bytes,
      contentType: 'image/jpeg',
    );
    return getPublicUrl('avatars', path);
  }
  
  /// 上传图片
  Future<String> uploadImage(String folder, String fileName, List<int> bytes, {String? contentType}) async {
    final path = '$folder/$fileName';
    await uploadFile(
      bucket: 'images',
      path: path,
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );
    return getPublicUrl('images', path);
  }
}
