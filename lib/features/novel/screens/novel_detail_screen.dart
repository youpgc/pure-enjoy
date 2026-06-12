import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/novel_model.dart';
import 'novel_reader_screen.dart';

class NovelDetailScreen extends StatefulWidget {
  final NovelModel novel;

  const NovelDetailScreen({
    super.key,
    required this.novel,
  });

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final result = await ApiClient.get(
        'novel_chapters',
        filters: {'novel_id': 'eq.${widget.novel.id}'},
        order: 'chapter_num.asc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _chapters = result.data!;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.novel.cover != null)
                          Center(
                            child: Image.network(
                              widget.novel.cover!,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          widget.novel.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '作者: ${widget.novel.author ?? '未知'}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.novel.description ?? '暂无简介',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _chapters.isNotEmpty
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NovelReaderScreen(
                                        novel: widget.novel,
                                        startChapter: 1,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('开始阅读'),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '章节列表',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chapter = _chapters[index];
                      return ListTile(
                        title: Text(chapter['title'] ?? '第 ${index + 1} 章'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NovelReaderScreen(
                                novel: widget.novel,
                                startChapter: chapter['chapter_num'] ?? 1,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: _chapters.length,
                  ),
                ),
              ],
            ),
    );
  }
}
