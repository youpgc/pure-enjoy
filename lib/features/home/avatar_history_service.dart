/// 头像历史记录服务（user_avatars 表）
///
/// 依赖：ApiClient（Supabase REST，anon + RLS）。所有写操作受 RLS 约束，
/// 仅能读写当前登录用户自己的记录（user_id 存业务 ID 文本，如 U...，
/// 由 AuthService.instance.currentUserId 提供；RLS 用 get_user_business_id()
/// 校验，禁用 auth.uid()）。
library;

import '../../services/api_client.dart';
import '../../services/supabase_service.dart';

/// 单条历史头像记录
class AvatarHistoryItem {
  final String id;
  final String avatarUrl;
  final String? styleKey; // type='dicebear' 时非空；'upload' 时为 null
  final String? backgroundColor; // hex 不含 #；null = 透明
  final String? seed; // type='dicebear' 时非空；'upload' 时为 null
  final DateTime createdAt;
  final String type; // 'dicebear' | 'upload'

  const AvatarHistoryItem({
    required this.id,
    required this.avatarUrl,
    required this.styleKey,
    required this.backgroundColor,
    required this.seed,
    required this.createdAt,
    this.type = 'dicebear',
  });

  factory AvatarHistoryItem.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'];
    return AvatarHistoryItem(
      id: json['id'] as String,
      avatarUrl: json['avatar_url'] as String,
      styleKey: json['style_key'] as String?,
      backgroundColor: json['background_color'] as String?,
      seed: json['seed'] as String?,
      type: (json['type'] as String?) ?? 'dicebear',
      createdAt: created is String
          ? DateTime.tryParse(created) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// 复制并替换部分字段（用于本地乐观更新，避免重新拉取）
  AvatarHistoryItem copyWith({
    String? avatarUrl,
    String? backgroundColor,
  }) =>
      AvatarHistoryItem(
        id: id,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        styleKey: styleKey,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        seed: seed,
        createdAt: createdAt,
      );
}

/// 头像历史记录增删改查
class AvatarHistoryService {
  AvatarHistoryService._();

  static String? get _userId => AuthService.instance.currentUserId;

  /// 拉取当前用户的历史头像（按时间倒序，最新在前）
  /// [type] 可选：传 'dicebear' / 'upload' 仅取该类型；不传则返回全部。
  static Future<List<AvatarHistoryItem>> fetch({String? type}) async {
    final uid = _userId;
    if (uid == null) return const [];
    final filters = <String, String>{'user_id': 'eq.$uid'};
    if (type != null) filters['type'] = 'eq.$type';
    final res = await ApiClient.get(
      'user_avatars',
      filters: filters,
      order: 'created_at.desc',
      limit: null,
    );
    if (!res.isSuccess || res.data == null) return const [];
    return res.data!.map((j) => AvatarHistoryItem.fromJson(j)).toList();
  }

  /// 记录一个使用过的头像（仅 DiceBear 预设头像）。
  /// 同一 URL 已存在则仅更新 updated_at（去重）；否则插入。
  /// 返回是否成功。
  static Future<bool> record({
    required String url,
    required String styleKey,
    required String seed,
    String? backgroundColor,
  }) async {
    final uid = _userId;
    if (uid == null) return false;
    // 去重：已存在则 bump updated_at
    final existing = await ApiClient.get(
      'user_avatars',
      filters: {'user_id': 'eq.$uid', 'avatar_url': 'eq.$url'},
      limit: 1,
    );
    if (existing.isSuccess && (existing.data?.isNotEmpty ?? false)) {
      final id = existing.data!.first['id'] as String?;
      if (id != null) {
        await ApiClient.patch(
          'user_avatars',
          {'updated_at': DateTime.now().toUtc().toIso8601String()},
          id: id,
        );
      }
      return true;
    }
    final res = await ApiClient.post('user_avatars', {
      'user_id': uid,
      'type': 'dicebear', // 预设头像；'upload' 为预留入口，待上传功能复用
      'avatar_url': url,
      'style_key': styleKey,
      'background_color': backgroundColor,
      'seed': seed,
    });
    return res.isSuccess;
  }

  /// 记录一个用过的上传头像（type='upload'）。
  /// 同一 URL 已存在则仅更新 updated_at（去重）；否则插入。
  /// 上传头像无风格/种子，仅存 avatar_url。返回是否成功。
  static Future<bool> recordUpload({required String url}) async {
    final uid = _userId;
    if (uid == null) return false;
    // 去重：已存在则 bump updated_at
    final existing = await ApiClient.get(
      'user_avatars',
      filters: {'user_id': 'eq.$uid', 'avatar_url': 'eq.$url'},
      limit: 1,
    );
    if (existing.isSuccess && (existing.data?.isNotEmpty ?? false)) {
      final id = existing.data!.first['id'] as String?;
      if (id != null) {
        await ApiClient.patch(
          'user_avatars',
          {'updated_at': DateTime.now().toUtc().toIso8601String()},
          id: id,
        );
      }
      return true;
    }
    final res = await ApiClient.post('user_avatars', {
      'user_id': uid,
      'type': 'upload',
      'avatar_url': url,
    });
    return res.isSuccess;
  }

  /// 删除某条记录
  static Future<bool> delete(String id) async {
    final res = await ApiClient.delete('user_avatars', id: id);
    return res.isSuccess;
  }
}
