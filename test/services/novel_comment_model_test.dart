import 'package:flutter_test/flutter_test.dart';
import 'package:pure_enjoy/features/novel/models/novel_comment_model.dart';

void main() {
  group('NovelCommentModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'comment-001',
        'novel_id': 'novel-001',
        'user_id': 'user-001',
        'user_nickname': '测试用户',
        'user_avatar': 'https://example.com/avatar.jpg',
        'content': '这是一条测试评论',
        'rating': 4,
        'parent_id': null,
        'reply_to_user_id': null,
        'reply_to_nickname': null,
        'like_count': 5,
        'created_at': '2026-06-20T10:30:00.000Z',
        'updated_at': null,
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.id, 'comment-001');
      expect(comment.novelId, 'novel-001');
      expect(comment.userId, 'user-001');
      expect(comment.userNickname, '测试用户');
      expect(comment.userAvatar, 'https://example.com/avatar.jpg');
      expect(comment.content, '这是一条测试评论');
      expect(comment.rating, 4);
      expect(comment.parentId, isNull);
      expect(comment.replyToUserId, isNull);
      expect(comment.replyToNickname, isNull);
      expect(comment.likeCount, 5);
      expect(comment.createdAt, isNotNull);
      expect(comment.updatedAt, isNull);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'comment-002',
        'novel_id': 'novel-001',
        'user_id': 'user-001',
        'content': '无评分评论',
        'rating': null,
        'parent_id': null,
        'like_count': 0,
        'created_at': '2026-06-20T10:30:00.000Z',
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.rating, isNull);
      expect(comment.parentId, isNull);
      expect(comment.userNickname, isNull);
      expect(comment.userAvatar, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.id, '');
      expect(comment.novelId, '');
      expect(comment.userId, '');
      expect(comment.content, '');
      expect(comment.likeCount, 0);
    });

    test('isReply returns false for root comments', () {
      final json = {
        'id': 'comment-003',
        'novel_id': 'novel-001',
        'user_id': 'user-001',
        'content': '根评论',
        'parent_id': null,
        'like_count': 0,
        'created_at': '2026-06-20T10:30:00.000Z',
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.isReply, false);
    });

    test('isReply returns true for reply comments', () {
      final json = {
        'id': 'comment-004',
        'novel_id': 'novel-001',
        'user_id': 'user-002',
        'content': '回复评论',
        'parent_id': 'comment-003',
        'reply_to_user_id': 'user-001',
        'reply_to_nickname': '测试用户',
        'like_count': 0,
        'created_at': '2026-06-20T11:00:00.000Z',
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.isReply, true);
      expect(comment.parentId, 'comment-003');
      expect(comment.replyToNickname, '测试用户');
    });

    test('displayName returns userNickname when available', () {
      final json = {
        'id': 'comment-005',
        'novel_id': 'novel-001',
        'user_id': 'user-001',
        'user_nickname': '小明',
        'content': '测试',
        'like_count': 0,
        'created_at': '2026-06-20T10:30:00.000Z',
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.displayName, '小明');
    });

    test('displayName returns anonymous when no nickname', () {
      final json = {
        'id': 'comment-006',
        'novel_id': 'novel-001',
        'user_id': 'user-001',
        'content': '测试',
        'like_count': 0,
        'created_at': '2026-06-20T10:30:00.000Z',
      };

      final comment = NovelCommentModel.fromJson(json);

      expect(comment.displayName, '匿名用户');
    });
  });
}
