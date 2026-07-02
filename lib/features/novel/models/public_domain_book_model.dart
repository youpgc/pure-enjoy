/// 公版书籍模型（Gutendex API）
class PublicDomainBookModel {
  final int id;
  final String title;
  final List<PublicDomainAuthor> authors;
  final List<String> subjects;
  final List<String> bookshelves;
  final List<String> languages;
  final bool copyright;
  final String mediaType;
  final Map<String, String> formats;
  final int downloadCount;

  PublicDomainBookModel({
    required this.id,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.bookshelves,
    required this.languages,
    required this.copyright,
    required this.mediaType,
    required this.formats,
    required this.downloadCount,
  });

  factory PublicDomainBookModel.fromJson(Map<String, dynamic> json) {
    return PublicDomainBookModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '未知书名',
      authors: (json['authors'] as List? ?? [])
          .map((a) => PublicDomainAuthor.fromJson(a as Map<String, dynamic>))
          .toList(),
      subjects: (json['subjects'] as List? ?? []).cast<String>(),
      bookshelves: (json['bookshelves'] as List? ?? []).cast<String>(),
      languages: (json['languages'] as List? ?? []).cast<String>(),
      copyright: json['copyright'] as bool? ?? false,
      mediaType: json['media_type'] as String? ?? 'Text',
      formats: (json['formats'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
      downloadCount: json['download_count'] as int? ?? 0,
    );
  }

  /// 获取纯文本下载链接（优先 UTF-8）
  String? get textUrl {
    return formats['text/plain; charset=utf-8'] ??
        formats['text/plain'] ??
        formats['text/plain; charset=us-ascii'];
  }

  /// 获取 HTML 下载链接
  String? get htmlUrl {
    return formats['text/html'];
  }

  /// 获取 EPUB 下载链接
  String? get epubUrl {
    return formats['application/epub+zip'];
  }

  /// 获取作者名字符串
  String get authorNames {
    if (authors.isEmpty) return '佚名';
    return authors.map((a) => a.name).join(', ');
  }

  /// 获取封面图（如果有）
  String? get coverUrl {
    return formats['image/jpeg'];
  }

  /// 获取分类标签（取前 3 个主题）
  List<String> get tags {
    return subjects.take(3).toList();
  }
}

/// 作者信息
class PublicDomainAuthor {
  final String name;
  final int? birthYear;
  final int? deathYear;

  PublicDomainAuthor({
    required this.name,
    this.birthYear,
    this.deathYear,
  });

  factory PublicDomainAuthor.fromJson(Map<String, dynamic> json) {
    return PublicDomainAuthor(
      name: json['name'] as String? ?? '佚名',
      birthYear: json['birth_year'] as int?,
      deathYear: json['death_year'] as int?,
    );
  }
}

/// Gutendex 分页响应
class GutendexResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<PublicDomainBookModel> results;

  GutendexResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory GutendexResponse.fromJson(Map<String, dynamic> json) {
    return GutendexResponse(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: (json['results'] as List? ?? [])
          .map((e) => PublicDomainBookModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasNext => next != null && next!.isNotEmpty;
}
