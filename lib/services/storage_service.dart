/// 本地存储服务
class StorageService {
  static StorageService? _instance;
  
  StorageService._();
  
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }
  
  // 本地文件存储路径映射
  final Map<String, List<int>> _fileCache = {};
  
  /// 上传文件（本地存储）
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    final key = '$bucket/$path';
    _fileCache[key] = bytes;
    return key;
  }
  
  /// 获取文件公开URL
  String getPublicUrl(String bucket, String path) {
    return 'local://$bucket/$path';
  }
  
  /// 获取签名URL（私有文件）
  Future<String> getSignedUrl(String bucket, String path, {int expiresIn = 3600}) async {
    return 'local://$bucket/$path?signed=true&expires=$expiresIn';
  }
  
  /// 删除文件
  Future<void> deleteFile(String bucket, String path) async {
    final key = '$bucket/$path';
    _fileCache.remove(key);
  }
  
  /// 列出文件
  Future<List<String>> listFiles(String bucket, {String? path}) async {
    final prefix = path != null ? '$bucket/$path' : '$bucket/';
    return _fileCache.keys
        .where((key) => key.startsWith(prefix))
        .toList();
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
  
  /// 获取文件数据
  List<int>? getFileData(String bucket, String path) {
    final key = '$bucket/$path';
    return _fileCache[key];
  }
}
