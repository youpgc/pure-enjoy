import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/gutendex_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart' as app_widgets;
import '../models/public_domain_book_model.dart';
import 'public_domain_reader_screen.dart';

/// 经典公版书列表页面
class PublicDomainListScreen extends StatefulWidget {
  const PublicDomainListScreen({super.key});

  @override
  State<PublicDomainListScreen> createState() => _PublicDomainListScreenState();
}

class _PublicDomainListScreenState extends State<PublicDomainListScreen> {
  List<PublicDomainBookModel> _books = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasMore = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBooks(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadBooks();
    }
  }

  Future<void> _loadBooks({bool refresh = false}) async {
    if (_isLoadingMore) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await GutendexService.instance.getBooks(
        page: _currentPage,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        languages: 'zh',
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _books = response.results;
            _isLoading = false;
          } else {
            _books.addAll(response.results);
          }
          _hasMore = response.hasNext;
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onSearchSubmitted(String value) async {
    setState(() {
      _searchQuery = value.trim();
      _books.clear();
      _isLoading = true;
    });
    await _loadBooks(refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchSubmitted('');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('经典公版书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBooks(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书名或作者...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: _onSearchSubmitted,
            ),
          ),

          // 说明文字
          if (_searchQuery.isEmpty && _books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '数据来自古登堡计划（Project Gutenberg），版权已过期，完全免费',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 错误提示
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: app_widgets.ErrorWidget(
                message: '加载失败: $_error',
                onRetry: () => _loadBooks(refresh: true),
              ),
            ),

          // 列表
          Expanded(
            child: _isLoading && _books.isEmpty
                ? const app_widgets.LoadingWidget()
                : _books.isEmpty && !_isLoading
                    ? RefreshIndicator(
                        onRefresh: () => _loadBooks(refresh: true),
                        child: CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: app_widgets.EmptyWidget(
                                message: _searchQuery.isEmpty
                                    ? '暂无公版书籍'
                                    : '未找到相关书籍',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _books.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _books.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: app_widgets.LoadingWidget()),
                            );
                          }
                          return _BookCard(
                            book: _books[index],
                            onTap: () => _openReader(_books[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openReader(PublicDomainBookModel book) {
    if (book.textUrl == null && book.htmlUrl == null) {
      app_widgets.showSnackBar(context, '该书暂无可读格式');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicDomainReaderScreen(book: book),
      ),
    );
  }
}

/// 书籍卡片
class _BookCard extends StatelessWidget {
  final PublicDomainBookModel book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面或占位
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        width: 80,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
                      )
                    : _buildPlaceholder(colorScheme),
              ),
              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.authorNames,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: book.tags
                          .map((tag) => Chip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.download_outlined,
                            size: 14, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${book.downloadCount} 次下载',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                        const Spacer(),
                        if (book.languages.contains('zh'))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '中文',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryOrange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 110,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.book_outlined,
        color: colorScheme.outline,
        size: 32,
      ),
    );
  }
}
