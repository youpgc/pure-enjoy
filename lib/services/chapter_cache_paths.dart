import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 章节缓存磁盘路径工具（从 ChapterCacheService 抽出，无实例状态依赖）
String chapterCacheFileName(String chapterId) => '${chapterId.replaceAll('-', '')}.txt';

/// 获取应用级缓存根目录
Future<Directory> chapterCacheRootDir() async {
  final appDir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${appDir.path}/chapter_cache');
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  return cacheDir;
}

/// 获取指定小说的缓存目录
Future<Directory> chapterCacheDir(String novelId) async {
  final root = await chapterCacheRootDir();
  final novelDir = Directory('${root.path}/$novelId');
  if (!await novelDir.exists()) {
    await novelDir.create(recursive: true);
  }
  return novelDir;
}
