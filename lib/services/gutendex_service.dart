import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../features/novel/models/public_domain_book_model.dart';

/// Gutendex API 服务
/// 古登堡计划公版书籍接口，无需认证，完全免费
/// 文档：https://gutendex.com/
class GutendexService {
  static const String _baseUrl = 'https://gutendex.com';
  static const String _booksEndpoint = '/books/';

  static final GutendexService _instance = GutendexService._internal();
  factory GutendexService() => _instance;
  GutendexService._internal();

  static GutendexService get instance => _instance;

  /// 获取书籍列表（支持分页）
  /// [page] 页码，从 1 开始
  /// [search] 搜索关键词（书名/作者）
  /// [languages] 语言过滤，如 'zh' 或 'en,zh'
  /// [topic] 主题过滤
  Future<GutendexResponse> getBooks({
    int page = 1,
    String? search,
    String? languages,
    String? topic,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (languages != null && languages.isNotEmpty) {
      queryParams['languages'] = languages;
    }
    if (topic != null && topic.isNotEmpty) {
      queryParams['topic'] = topic;
    }

    final uri = Uri.parse('$_baseUrl$_booksEndpoint').replace(
      queryParameters: queryParams,
    );

    if (kDebugMode) {
      debugPrint('📚 Gutendex API: $uri');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return GutendexResponse.fromJson(json);
    } else {
      throw Exception('Gutendex API 请求失败: HTTP ${response.statusCode}');
    }
  }

  /// 获取单本书详情
  Future<PublicDomainBookModel> getBook(int id) async {
    final uri = Uri.parse('$_baseUrl$_booksEndpoint$id/');

    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PublicDomainBookModel.fromJson(json);
    } else {
      throw Exception('获取书籍详情失败: HTTP ${response.statusCode}');
    }
  }

  /// 搜索书籍
  Future<GutendexResponse> searchBooks(String query, {int page = 1}) async {
    return getBooks(page: page, search: query);
  }

  /// 获取中文书籍
  Future<GutendexResponse> getChineseBooks({int page = 1}) async {
    return getBooks(page: page, languages: 'zh');
  }

  /// 获取热门书籍（按下载量排序，取前 32 本）
  Future<List<PublicDomainBookModel>> getPopularBooks() async {
    final response = await getBooks(page: 1);
    // 按下载量排序
    final books = response.results;
    books.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
    return books.take(32).toList();
  }

  /// 下载纯文本内容
  /// 返回 UTF-8 编码的文本内容
  Future<String> downloadText(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(minutes: 2),
    );
    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('下载文本失败: HTTP ${response.statusCode}');
    }
  }
}
