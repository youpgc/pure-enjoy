/// 游戏道具目录项（对应 Supabase `game_items`）。
class GameItemModel {
  final String id;
  final String gameCode;
  final String mode;
  final String itemType;
  final String name;
  final String? description;
  final int pointCost;
  final int perGameLimit;
  final bool enabled;
  final int sortOrder;

  const GameItemModel({
    required this.id,
    required this.gameCode,
    required this.mode,
    required this.itemType,
    required this.name,
    this.description,
    required this.pointCost,
    required this.perGameLimit,
    required this.enabled,
    required this.sortOrder,
  });

  factory GameItemModel.fromJson(Map<String, dynamic> json) {
    return GameItemModel(
      id: json['id'] ?? '',
      gameCode: json['game_code'] ?? '',
      mode: json['mode'] ?? '',
      itemType: json['item_type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] as String?,
      pointCost: (json['point_cost'] as num?)?.toInt() ?? 0,
      perGameLimit: (json['per_game_limit'] as num?)?.toInt() ?? 1,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'game_code': gameCode,
        'mode': mode,
        'item_type': itemType,
        'name': name,
        if (description != null) 'description': description,
        'point_cost': pointCost,
        'per_game_limit': perGameLimit,
        'enabled': enabled,
        'sort_order': sortOrder,
      };
}

/// 用户持有道具库存（对应 Supabase `user_game_items`）。
class UserGameItemModel {
  final String id;
  final String userId;
  final String itemId;
  final int owned;

  const UserGameItemModel({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.owned,
  });

  factory UserGameItemModel.fromJson(Map<String, dynamic> json) {
    return UserGameItemModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      itemId: json['item_id'] ?? '',
      owned: (json['owned'] as num?)?.toInt() ?? 0,
    );
  }
}
