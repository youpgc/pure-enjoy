import '../../../services/api_client.dart';

/// 公告模型
///
/// 字段与后台 Announcements.tsx / announcements 表对齐：
/// id, title, content, type(system/activity/maintenance),
/// priority(high/medium/low), is_published, publish_at, expire_at, created_at
class Announcement {
  final String id;
  final String title;
  final String content;
  final String type;
  final String priority;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? expireAt;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.type = 'system',
    this.priority = 'medium',
    this.isPublished = false,
    this.publishAt,
    this.expireAt,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v == null || v is! String || v.isEmpty) return null;
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }

    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      priority: json['priority']?.toString() ?? 'medium',
      isPublished: json['is_published'] == true,
      publishAt: parse(json['publish_at']),
      expireAt: parse(json['expire_at']),
      createdAt: parse(json['created_at']) ?? DateTime.now(),
    );
  }

  /// 类型展示标签（对齐后台 ANNOUNCEMENT_TYPE_MAP）
  String get typeLabel {
    switch (type) {
      case 'activity':
        return '活动';
      case 'maintenance':
        return '维护';
      default:
        return '系统';
    }
  }

  /// 优先级排序权重：高(0) > 中(1) > 低(2)
  int get priorityRank {
    switch (priority) {
      case 'high':
        return 0;
      case 'low':
        return 2;
      default:
        return 1;
    }
  }
}

/// 公告服务
///
/// 闭环：后台 Announcements.tsx 发布 → announcements 表；App 端此处拉取生效公告。
class AnnouncementService {
  /// 拉取当前生效公告：
  /// 已发布(is_published=true) + 已过发布时间(publish_at<=now) + 未过期(expire_at 为空或 >=now)
  static Future<List<Announcement>> fetchActive({int limit = 50}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final result = await ApiClient.get(
        'announcements',
        filters: {
          'is_published': 'eq.true',
          'publish_at': 'lte.$now',
          'or': '(expire_at.is.null,expire_at.gte.$now)',
        },
        order: 'created_at.desc',
        limit: limit,
      );
      if (!result.isSuccess || result.data == null) return [];
      final list = result.data as List;
      final items = list
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      // 高优先级置顶（同优先级内按创建时间倒序）
      items.sort((a, b) {
        final r = a.priorityRank.compareTo(b.priorityRank);
        return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
      });
      return items;
    } catch (e) {
      return [];
    }
  }
}
