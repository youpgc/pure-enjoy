import 'package:flutter/material.dart';

/// {@template comment_input_bar}
/// [NovelCommentsScreen] 的评论输入栏（从超长 _buildInputBar 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。回复条与评分行拆为独立子组件。
/// {@endtemplate}
class CommentInputBar extends StatelessWidget {
  /// {@macro comment_input_bar}
  const CommentInputBar({
    super.key,
    required this.controller,
    required this.isSubmitting,
    required this.replyToNickname,
    required this.selectedRating,
    required this.isReplying,
    required this.onCancelReply,
    required this.onRatingButtonTap,
    required this.onStarTap,
    required this.onRatingClear,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final String? replyToNickname;
  final int? selectedRating;
  final bool isReplying;
  final VoidCallback onCancelReply;
  final VoidCallback onRatingButtonTap;
  final ValueChanged<int> onStarTap;
  final VoidCallback onRatingClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          if (replyToNickname != null)
            CommentReplyBanner(
              replyToNickname: replyToNickname!,
              onCancelReply: onCancelReply,
            ),
          if (!isReplying && selectedRating != null)
            CommentRatingRow(
              selectedRating: selectedRating!,
              onStarTap: onStarTap,
              onRatingClear: onRatingClear,
            ),
          Row(
            children: [
              if (!isReplying)
                IconButton(
                  icon: Icon(
                    selectedRating != null
                        ? Icons.star
                        : Icons.star_outline,
                    color: selectedRating != null
                        ? Colors.amber
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onRatingButtonTap,
                  tooltip: '评分',
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: replyToNickname != null
                        ? '回复 @$replyToNickname...'
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
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.send, color: theme.colorScheme.primary),
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 回复对象提示条
class CommentReplyBanner extends StatelessWidget {
  const CommentReplyBanner({
    super.key,
    required this.replyToNickname,
    required this.onCancelReply,
  });

  final String replyToNickname;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Text('回复 @$replyToNickname',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
        const Spacer(),
        InkWell(
            onTap: onCancelReply,
            child: Icon(Icons.close,
                size: 16, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// 评分选择行
class CommentRatingRow extends StatelessWidget {
  const CommentRatingRow({
    super.key,
    required this.selectedRating,
    required this.onStarTap,
    required this.onRatingClear,
  });

  final int selectedRating;
  final ValueChanged<int> onStarTap;
  final VoidCallback onRatingClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Text('评分: ', style: TextStyle(fontSize: 13)),
        ...List.generate(5, (index) {
          final starIndex = index + 1;
          return GestureDetector(
            onTap: () => onStarTap(starIndex),
            child: Icon(
              starIndex <= selectedRating ? Icons.star : Icons.star_border,
              size: 20,
              color: Colors.amber,
            ),
          );
        }),
        const Spacer(),
        InkWell(
            onTap: onRatingClear,
            child: Text('取消评分',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}
