import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/novel_comment_model.dart';

/// 单条评论组件
class CommentItem extends StatelessWidget {
  final NovelCommentModel comment;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final bool isReply;

  const CommentItem({
    super.key,
    required this.comment,
    this.onReply,
    this.onLike,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = _formatTime(comment.createdAt);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isReply ? 8 : 12,
      ),
      decoration: isReply
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: comment.userAvatar != null
                ? CachedNetworkImageProvider(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? Text(
                    comment.displayName.characters.first,
                    style: TextStyle(
                      fontSize: isReply ? 12 : 14,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // 内容区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称 + 时间
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: TextStyle(
                        fontSize: isReply ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (comment.rating != null && !isReply) ...[
                      const SizedBox(width: 6),
                      _RatingStars(rating: comment.rating!, size: 12),
                    ],
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 回复目标
                if (comment.replyToNickname != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '回复 @${comment.replyToNickname}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                // 评论内容
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: isReply ? 13 : 14,
                    color: theme.colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                if (!isReply) ...[
                  const SizedBox(height: 8),
                  // 点赞和回复按钮
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.thumb_up_outlined,
                        count: comment.likeCount,
                        onTap: onLike,
                      ),
                      const SizedBox(width: 16),
                      _ActionButton(
                        icon: Icons.reply,
                        label: '回复',
                        onTap: onReply,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}-${time.day}';
  }
}

/// 评分星星
class _RatingStars extends StatelessWidget {
  final int rating;
  final double size;

  const _RatingStars({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: size,
          color: Colors.amber,
        );
      }),
    );
  }
}

/// 操作按钮（点赞/回复）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final String? label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.count,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            if (count != null && count! > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
