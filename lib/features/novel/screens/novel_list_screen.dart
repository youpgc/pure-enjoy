import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/novel_model.dart';
import 'novel_detail_screen.dart';

class NovelListScreen extends StatefulWidget {
  const NovelListScreen({super.key});

  @override
  State<NovelListScreen> createState() => _NovelListScreenState();
}

class _NovelListScreenState extends State<NovelListScreen> {
  List<NovelModel> _novels = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadNovels();
  }

  Future<void> _loadNovels() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiClient.get(
        'novels',
        order: 'created_at.desc',
        limit: 500,
      );

      if (result.isSuccess) {
        setState(() {
          _novels = result.data!
              .map((json) => NovelModel.fromJson(json))
              .toList();
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
        title: const Text('小说列表'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _novels.isEmpty
              ? const Center(child: Text('暂无小说'))
              : ListView.builder(
                  itemCount: _novels.length,
                  itemBuilder: (context, index) {
                    final novel = _novels[index];
                    return ListTile(
                      leading: novel.cover != null
                          ? Image.network(
                              novel.cover!,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.book, size: 50),
                      title: Text(novel.title),
                      subtitle: Text(novel.author ?? '未知作者'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NovelDetailScreen(novel: novel),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
