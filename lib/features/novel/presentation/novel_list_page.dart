import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage_service.dart';
import '../../../services/sync_service.dart';
import '../data/novel_model.dart';
import 'novel_reader_page.dart';

/// 小说列表页面
class NovelListPage extends ConsumerStatefulWidget {
  const NovelListPage({super.key});

  @override
  ConsumerState<NovelListPage> createState() => _NovelListPageState();
}

class _NovelListPageState extends ConsumerState<NovelListPage> {
  List<NovelModel> _novels = [];
  int _selectedTab = 0; // 0: 书架, 1: 发现

  @override
  void initState() {
    super.initState();
    _loadNovels();
  }

  void _loadNovels() {
    final box = StorageService().novelBox;
    setState(() {
      _novels = box.values.toList()
        ..sort((a, b) {
          // 最近阅读的排在前面
          if (a.lastReadAt != null && b.lastReadAt != null) {
            return b.lastReadAt!.compareTo(a.lastReadAt!);
          }
          if (a.lastReadAt != null) return -1;
          if (b.lastReadAt != null) return 1;
          return b.addedAt.compareTo(a.addedAt);
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小说'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '书架',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTab == 0
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '发现',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTab == 1
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildBookshelf() : _buildDiscovery(),
    );
  }

  Widget _buildBookshelf() {
    if (_novels.isEmpty) {
      return _buildEmptyBookshelf();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: _novels.length,
      itemBuilder: (context, index) {
        final novel = _novels[index];
        return _buildNovelCard(novel);
      },
    );
  }

  Widget _buildEmptyBookshelf() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '书架是空的',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '切换到"发现"页面添加小说',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelCard(NovelModel novel) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovelReaderPage(novel: novel),
          ),
        ).then((_) => _loadNovels());
      },
      onLongPress: () => _showNovelOptions(novel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: novel.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        novel.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                      ),
                    )
                  : _buildPlaceholderCover(),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            novel.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 作者/进度
          Text(
            novel.lastReadAt != null
                ? '已读 ${(novel.progress * 100).toInt()}%'
                : novel.author,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Center(
      child: Icon(
        Icons.book,
        size: 40,
        color: AppTheme.primaryColor.withOpacity(0.5),
      ),
    );
  }

  Widget _buildDiscovery() {
    // 示例小说列表（实际应从API获取）
    final sampleNovels = [
      {'title': '斗破苍穹', 'author': '天蚕土豆'},
      {'title': '凡人修仙传', 'author': '忘语'},
      {'title': '完美世界', 'author': '辰东'},
      {'title': '遮天', 'author': '辰东'},
      {'title': '雪中悍刀行', 'author': '烽火戏诸侯'},
      {'title': '诡秘之主', 'author': '爱潜水的乌贼'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sampleNovels.length,
      itemBuilder: (context, index) {
        final novel = sampleNovels[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.book,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            title: Text(novel['title']!),
            subtitle: Text(novel['author']!),
            trailing: ElevatedButton(
              onPressed: () => _addSampleNovel(novel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('添加'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addSampleNovel(Map<String, String> novel) async {
    final newNovel = NovelModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: novel['title']!,
      author: novel['author']!,
      source: 'sample',
      sourceId: novel['title']!,
      addedAt: DateTime.now(),
    );
    await StorageService().novelBox.put(newNovel.id, newNovel);
    SyncService().uploadNovel(newNovel); // 同步到云端
    _loadNovels();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加《${novel['title']}》到书架')),
      );
    }
  }

  void _showNovelOptions(NovelModel novel) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('详情'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 显示详情
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('从书架移除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await StorageService().novelBox.delete(novel.id);
                SyncService().deleteRemote('novels', novel.id); // 从云端删除
                _loadNovels();
              },
            ),
          ],
        ),
      ),
    );
  }
}
