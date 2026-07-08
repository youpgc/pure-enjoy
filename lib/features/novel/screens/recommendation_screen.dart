import 'package:flutter/material.dart' hide ErrorWidget;
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../core/widgets/widgets.dart';
import '../models/novel_model.dart';
import '../services/recommendation_service.dart';
import 'novel_detail_screen.dart';
import '../../../constants/app_constants.dart';

/// 猜你喜欢 - 智能推荐页面
class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<NovelModel> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await RecommendationService().getRecommendations(
        limit: 20,
      );

      if (!mounted) return;
      if (result.isNotEmpty) {
        setState(() {
          _recommendations = result;
          _isLoading = false;
        });
      } else {
        // 冷启动或无数据时，加载热门小说
        await _loadFallbackNovels();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载推荐失败';
        _isLoading = false;
      });
    }
  }

  /// 冷启动回退：加载热门小说
  Future<void> _loadFallbackNovels() async {
    try {
      final result = await ApiClient.get(
        'novels',
        filters: {'status': 'eq.$novelStatusCompleted'},
        order: 'read_count.desc',
        limit: 20,
      );
      if (!mounted) return;
      if (result.isSuccess && result.data != null) {
        final novels = result.data!
            .map((json) => NovelModel.fromJson(json))
            .toList();
        setState(() {
          _recommendations = novels;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 标记不感兴趣
  Future<void> _markNotInterested(NovelModel novel) async {
    if (_userId == null) {
      showSnackBar(context, '请先登录');
      return;
    }

    try {
      await RecommendationService().markNotInterested(novel.id);
      if (!mounted) return;
      setState(() {
        _recommendations.removeWhere((n) => n.id == novel.id);
      });
      showSnackBar(context, '已减少此类推荐');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, '操作失败');
    }
  }

  /// 打开小说详情
  void _openNovelDetail(NovelModel novel) {
    // 记录点击反馈
    if (_userId != null) {
      RecommendationService().recordFeedback(
        novelId: novel.id,
        feedbackType: RecommendationFeedbackType.click,
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
    ).then((_) {
      // 返回后刷新
      if (mounted) _loadRecommendations();
    });
  }

  /// 构建推荐原因标签
  Widget _buildReasonChip(NovelModel novel) {
    // 根据小说属性生成推荐原因
    String reason;
    Color color;
    if (novel.status == novelStatusCompleted) {
      reason = '已完结';
      color = Colors.green;
    } else if ((novel.readCount ?? 0) > 1000) {
      reason = '热门';
      color = Colors.orange;
    } else if (novel.rating != null && novel.rating! >= 4.5) {
      reason = '高分';
      color = Colors.amber;
    } else {
      reason = '猜你喜欢';
      color = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        reason,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('猜你喜欢'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: '刷新推荐',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _errorMessage != null
              ? ErrorWidget(
                  message: _errorMessage!,
                  onRetry: _loadRecommendations,
                )
              : _recommendations.isEmpty
                  ? const EmptyWidget(message: '暂无推荐内容')
                  : RefreshIndicator(
                      onRefresh: _loadRecommendations,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final novel = _recommendations[index];
                          return _RecommendationCard(
                            novel: novel,
                            reasonChip: _buildReasonChip(novel),
                            onTap: () => _openNovelDetail(novel),
                            onNotInterested: () => _markNotInterested(novel),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// 推荐卡片组件
class _RecommendationCard extends StatelessWidget {
  final NovelModel novel;
  final Widget reasonChip;
  final VoidCallback onTap;
  final VoidCallback onNotInterested;

  const _RecommendationCard({
    required this.novel,
    required this.reasonChip,
    required this.onTap,
    required this.onNotInterested,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          // 长按显示不感兴趣选项
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('不感兴趣'),
                    subtitle: Text('减少「${novel.category ?? '此类'}」推荐'),
                    onTap: () {
                      Navigator.pop(context);
                      onNotInterested();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.visibility_off),
                    title: const Text('屏蔽此小说'),
                    onTap: () {
                      Navigator.pop(context);
                      onNotInterested();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    title: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: novel.cover != null
                    ? Image.network(
                        novel.cover!,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            novel.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        reasonChip,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author ?? '佚名',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      novel.description ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (novel.category != null)
                          Text(
                            novel.category!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                        const Spacer(),
                        if (novel.rating != null) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            novel.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
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
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.book, size: 32, color: colorScheme.onSurfaceVariant),
    );
  }
}