import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../services/session_manager.dart';
import '../../../config.dart';
import '../models/novel_comment_model.dart';
import '../widgets/comment_item.dart';

/// 小说评论列表页面
class NovelCommentsScreen extends StatefulWidget {
  final String novelId;
  final String novelTitle;

  const NovelCommentsScreen({
    super.key,
    required this.novelId,
    required this.novelTitle,
  });

  @override
  State<NovelCommentsScreen> createState() => _NovelCommentsScreenState();
}

class _NovelCommentsScreenState extends State<NovelCommentsScreen> {
  final List<NovelCommentModel> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 10;

  final TextEditingController _inputController = TextEditingController();
  bool _isSubmitting = false;
  int? _selectedRating;
  String? _replyToCommentId;
  String? _replyToUserId;
  String? _replyToNickname;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      _comments.clear();
    }
    setState(() => _isLoading = _page == 0);
    try {
      final result = await ApiClient.get(
        AppConfig.novelCommentsTable,
        filters: {
          'novel_id': 'eq.${widget.novelId}',
          'parent_id': 'is.null',
        },
        columns:
            'id,novel_id,user_id,user_nickname,user_avatar,content,rating,parent_id,reply_to_user_id,reply_to_nickname,like_count,created_at,updated_at',
        order: 'created_at.desc',
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (result.isSuccess && result.data != null) {
        final newComments = result.data!
            .map((json) => NovelCommentModel.fromJson(json))
            .toList();
        if (!mounted) return;
        setState(() {
          if (refresh) _comments.clear();
          _comments.addAll(newComments);
          _hasMore = newComments.length >= _pageSize;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载评论失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载评论失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    await _loadComments();
    setState(() => _isLoadingMore = false);
  }

  Future<void> _submitComment() async {
    if (_isSubmitting) return;
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final userId = AuthService.instance.currentUserId ?? '';
      final nickname = SessionManager.instance.currentUserNickname;
      final comment = NovelCommentModel(
        id: const Uuid().v4(),
        novelId: widget.novelId,
        userId: userId,
        userNickname: nickname,
        content: content,
        rating: _replyToCommentId == null ? _selectedRating : null,
        parentId: _replyToCommentId,
        replyToUserId: _replyToUserId,
        replyToNickname: _replyToNickname,
        createdAt: DateTime.now(),
      );
      final result =
          await ApiClient.post(AppConfig.novelCommentsTable, comment.toJson());
      if (result.isSuccess) {
        _inputController.clear();
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _selectedRating = null;
          _replyToCommentId = null;
          _replyToUserId = null;
          _replyToNickname = null;
        });
        if (_replyToCommentId == null) await _loadComments(refresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('评论成功')));
        }
      } else {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('评论失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('评论失败: $e')));
      }
    }
  }

  void _setReplyTarget(NovelCommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToUserId = comment.userId;
      _replyToNickname = comment.displayName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserId = null;
      _replyToNickname = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('评论 (${_comments.length})')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('暂无评论，快来发表第一条评论吧',
                                style: TextStyle(
                                    color:
                                        theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadComments(refresh: true),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels >=
                                notification.metrics.maxScrollExtent - 200) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount:
                                _comments.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _comments.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  ),
                                );
                              }
                              final comment = _comments[index];
                              return CommentItem(
                                comment: comment,
                                onReply: () => _setReplyTarget(comment),
                                onLike: () => _likeComment(comment),
                              );
                            },
                          ),
                        ),
                      ),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
      ),
      padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToNickname != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Text('回复 @_replyToNickname',
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.primary)),
                const Spacer(),
                InkWell(
                    onTap: _cancelReply,
                    child: Icon(Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          if (_replyToCommentId == null && _selectedRating != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Text('评分: ', style: TextStyle(fontSize: 13)),
                ...List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedRating = _selectedRating == starIndex
                          ? null
                          : starIndex;
                    }),
                    child: Icon(
                      starIndex <= (_selectedRating ?? 0)
                          ? Icons.star
                          : Icons.star_border,
                      size: 20,
                      color: Colors.amber,
                    ),
                  );
                }),
                const Spacer(),
                InkWell(
                    onTap: () => setState(() => _selectedRating = null),
                    child: Text('取消评分',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant))),
              ]),
            ),
          Row(children: [
            if (_replyToCommentId == null)
              IconButton(
                icon: Icon(
                  _selectedRating != null
                      ? Icons.star
                      : Icons.star_outline,
                  color: _selectedRating != null
                      ? Colors.amber
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() {
                  _selectedRating = _selectedRating == null
                      ? 5
                      : (_selectedRating == 5
                          ? null
                          : (_selectedRating! + 1));
                }),
                tooltip: '评分',
              ),
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: _replyToNickname != null
                      ? '回复 @_replyToNickname...'
                      : '写下你的评论...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  isDense: true,
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.send, color: theme.colorScheme.primary),
              onPressed: _isSubmitting ? null : _submitComment,
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _likeComment(NovelCommentModel comment) async {
    try {
      final result = await ApiClient.patchByFilter(
        AppConfig.novelCommentsTable,
        filters: {'id': 'eq.${comment.id}'},
        body: {'like_count': comment.likeCount + 1},
      );
      if (!result.isSuccess) {
        if (kDebugMode) debugPrint('点赞失败: ${result.error}');
        return;
      }
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          final old = _comments[index];
          _comments[index] = NovelCommentModel(
            id: old.id,
            novelId: old.novelId,
            userId: old.userId,
            userNickname: old.userNickname,
            userAvatar: old.userAvatar,
            content: old.content,
            rating: old.rating,
            parentId: old.parentId,
            replyToUserId: old.replyToUserId,
            replyToNickname: old.replyToNickname,
            likeCount: old.likeCount + 1,
            createdAt: old.createdAt,
            updatedAt: old.updatedAt,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('点赞失败: $e')));
      }
    }
  }
}
