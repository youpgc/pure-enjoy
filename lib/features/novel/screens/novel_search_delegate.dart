import 'package:flutter/material.dart';
import '../widgets/novel_list_item.dart';

/// 小说搜索代理
class NovelSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> novels;
  final Set<String> addedNovelIds;
  final Set<String> addingNovelIds;
  final Future<void> Function(String) onAdd;

  NovelSearchDelegate({
    required this.novels,
    required this.addedNovelIds,
    required this.addingNovelIds,
    required this.onAdd,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          close(context, '');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入小说名称或作者搜索'));
    }

    final searchQuery = query.toLowerCase();
    final results = novels.where((novel) {
      final title = (novel['title'] as String? ?? '').toLowerCase();
      final author = (novel['author'] as String? ?? '').toLowerCase();
      return title.contains(searchQuery) || author.contains(searchQuery);
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('未找到相关小说'));
    }

    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final novel = results[index];
        final novelId = novel['id'].toString();
        final isAdded = addedNovelIds.contains(novelId);
        final isAdding = addingNovelIds.contains(novelId);

        return NovelListItem(
          novel: novel,
          colorScheme: colorScheme,
          isAdded: isAdded,
          isAdding: isAdding,
          onAdd: () {
            onAdd(novelId);
            // 刷新搜索结果以更新状态
            showSearch(
              context: context,
              delegate: NovelSearchDelegate(
                novels: novels,
                addedNovelIds: addedNovelIds,
                addingNovelIds: addingNovelIds,
                onAdd: onAdd,
              ),
            );
          },
        );
      },
    );
  }
}
