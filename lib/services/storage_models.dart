/// 存储文件对象（从 storage_service.dart 抽出）
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

/// 存储异常（从 storage_service.dart 抽出）
class StorageException implements Exception {
  final String message;
  final String? error;
  final String? statusCode;

  StorageException(this.message, {this.error, this.statusCode});

  @override
  String toString() => 'StorageException: $message';
}
