import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';

class BookShelfScreen extends StatefulWidget {
  const BookShelfScreen({super.key});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'user_novels',
        filters: {
          'user_id': 'eq.$_userId',
          'is_collected': 'eq.true',
        },
        order: 'last_read_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _books = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBook(String id) async {
    try {
      final result = await ApiClient.patch(
        'user_novels',
        filters: {'id': 'eq.$id'},
        body: {'is_collected': false},
      );

      if (result.isSuccess) {
        _loadBooks();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('移除失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userId == null
              ? const Center(child: Text('请先登录'))
              : _books.isEmpty
                  ? const Center(child: Text('书架为空'))
                  : ListView.builder(
                      itemCount: _books.length,
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        final novel = book['novel'] as Map<String, dynamic>?;
                        final progress = (book['progress'] as num?)?.toDouble() ?? 0;
                        return Dismissible(
                          key: Key(book['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _removeBook(book['id']),
                          child: ListTile(
                            leading: novel?['cover'] != null
                                ? Image.network(
                                    novel!['cover'] as String,
                                    width: 50,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.book, size: 50),
                            title: Text(novel?['title'] ?? '未知小说'),
                            subtitle: Text('进度: ${(progress * 100).toStringAsFixed(1)}%'),
                            onTap: () {
                              if (novel != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NovelReaderScreen(
                                      novel: NovelModel.fromJson(novel),
                                      startChapter: book['last_chapter'] as int? ?? 1,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
