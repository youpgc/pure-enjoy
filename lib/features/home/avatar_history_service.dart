/// 头像历史记录服务（change-server：改走后端 /users/me/avatars 端点）
///
/// 后端按登录态归属，主体 ID 一律取自服务端会话，客户端不再传 user_id。
/// 后端 VO 不含 created_at，AvatarHistoryItem.createdAt 统一回退为当前时间
/// （仅用于展示排序兜底，列表顺序以后端返回为准）。
library;

import '../../services/backend_api.dart';
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

  /// 拉取当前用户的历史头像（后端按时间倒序，最新在前）
  /// [type] 可选：传 'dicebear' / 'upload' 仅取该类型；不传则返回全部。
  static Future<List<AvatarHistoryItem>> fetch({String? type}) async {
    if (_userId == null) return const [];
    final res = await BackendApi.get('/users/me/avatars');
    if (!res.success || res.list.isEmpty) return const [];
    final items = res.list
        .map((j) => AvatarHistoryItem.fromJson(j as Map<String, dynamic>))
        .toList();
    if (type != null) {
      return items.where((it) => it.type == type).toList();
    }
    return items;
  }

  /// 记录一个使用过的头像（仅 DiceBear 预设头像）。
  /// 同一 URL 已存在则跳过（去重）；否则插入。
  /// 返回是否成功。
  static Future<bool> record({
    required String url,
    required String styleKey,
    required String seed,
    String? backgroundColor,
  }) =>
      _recordRaw(
        url: url,
        body: {
          'type': 'dicebear',
          'avatar_url': url,
          'style_key': styleKey,
          'background_color': backgroundColor,
          'seed': seed,
        },
      );

  /// 记录一个用过的上传头像（type='upload'）。
  /// 同一 URL 已存在则跳过（去重）；否则插入。
  /// 上传头像无风格/种子，仅存 avatar_url。返回是否成功。
  static Future<bool> recordUpload({required String url}) => _recordRaw(
        url: url,
        body: {'type': 'upload', 'avatar_url': url},
      );

  /// 去重写入：同 URL 已存在直接成功；否则插入新记录。
  static Future<bool> _recordRaw({
    required String url,
    required Map<String, dynamic> body,
  }) async {
    if (_userId == null) return false;
    try {
      // 去重：按 URL 查重（后端列表为本人全量）
      final existing = await BackendApi.get('/users/me/avatars');
      if (existing.success &&
          existing.list.any((j) =>
              (j as Map<String, dynamic>)['avatar_url'] == url)) {
        return true;
      }
      final res = await BackendApi.post('/users/me/avatars', body: body);
      return res.success;
    } catch (_) {
      return false;
    }
  }

  /// 删除某条记录
  static Future<bool> delete(String id) async {
    final res = await BackendApi.delete('/users/me/avatars/$id');
    return res.success;
  }
}
