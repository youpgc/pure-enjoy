import 'package:uuid/uuid.dart';

import 'package:pure_enjoy/core/utils/event_bus.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../features/profile/services/point_service.dart';
import '../models/game_item_model.dart';

/// 游戏道具商城服务（单例 + setState，与积分模块一致，禁 Riverpod）。
///
/// 职责：
/// - 查询某游戏（可指定模式）的已启用道具目录；
/// - 查询当前用户持有库存；
/// - 购买（扣积分写 `point_records.type='game_spend'` + 入库 `user_game_items`）；
/// - 游戏内消耗（扣减库存）。
class GameItemService {
  static GameItemService? _instance;
  GameItemService._();
  static GameItemService get instance {
    _instance ??= GameItemService._();
    return _instance!;
  }

  /// 查询道具目录：返回该游戏已启用的道具。
  ///
  /// [mode] 非空时仅返回「通用道具(mode='')」或「匹配该模式的道具」；
  /// [mode] 为 null 时返回该游戏全部已启用道具（商城页用）。
  Future<List<GameItemModel>> fetchItems({
    required String gameCode,
    String? mode,
  }) async {
    try {
      final filters = <String, String>{
        'game_code': 'eq.$gameCode',
        'enabled': 'eq.true',
      };
      final result = await ApiClient.get(
        'game_items',
        filters: filters,
        order: 'sort_order.asc',
        limit: null,
      );
      if (!result.isSuccess || result.data == null) return <GameItemModel>[];
      final items = result.data!
          .map((j) => GameItemModel.fromJson(j))
          .where((it) => mode == null || it.mode.isEmpty || it.mode == mode)
          .toList();
      return items;
    } catch (e) {
      return <GameItemModel>[];
    }
  }

  /// 查询当前用户持有库存，返回 `item_id -> owned` 映射。
  Future<Map<String, int>> fetchInventory() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return <String, int>{};
    try {
      final result = await ApiClient.get(
        'user_game_items',
        filters: {'user_id': 'eq.$userId'},
        columns: 'id,item_id,owned',
        limit: null,
      );
      final map = <String, int>{};
      if (result.isSuccess && result.data != null) {
        for (final row in result.data!) {
          final itemId = row['item_id'] as String? ?? '';
          final owned = (row['owned'] as num?)?.toInt() ?? 0;
          if (itemId.isNotEmpty) map[itemId] = owned;
        }
      }
      return map;
    } catch (e) {
      return <String, int>{};
    }
  }

  /// 购买道具：扣积分（写 game_spend 流水）+ 入库（owned+1）。
  ///
  /// 失败回退：入库失败则回退积分，保证不丢分。返回标准结果。
  Future<Map<String, dynamic>> purchase(GameItemModel item) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      return {'success': false, 'message': '未登录'};
    }
    try {
      final available = await PointService.instance.getAvailablePoints();
      if (available < item.pointCost) {
        return {
          'success': false,
          'message': '积分不足，需 ${item.pointCost} 积分',
        };
      }

      // 1) 消费积分（game_spend 闭环，自动重算回写 users 展示列）
      await PointService.instance.updatePointsStats(
        delta: -item.pointCost,
        type: 'game_spend',
        remark: '购买道具:${item.name}',
      );

      // 2) 入库 owned+1（先查后 upsert，复用 user_items 模式）
      final ok = await _upsertOwned(item.id, 1);
      if (!ok) {
        await PointService.instance.updatePointsStats(
          delta: item.pointCost,
          type: 'earn',
          remark: '购买道具回退:${item.name}',
        );
        return {'success': false, 'message': '购买失败，已退回积分'};
      }

      EventBus.instance.fire(EventType.pointsUpdated);
      final inv = await fetchInventory();
      final owned = inv[item.id] ?? 0;
      return {
        'success': true,
        'message': '购买成功，获得 1 张${item.name}',
        'owned': owned,
      };
    } catch (e) {
      return {'success': false, 'message': '购买失败，请稍后重试'};
    }
  }

  /// 游戏内消耗道具：扣减库存 1 张。返回成功与否（库存不足返回 false）。
  Future<bool> consumeItem(String itemId, {int qty = 1}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final result = await ApiClient.get(
        'user_game_items',
        filters: {
          'user_id': 'eq.$userId',
          'item_id': 'eq.$itemId',
        },
        columns: 'id,owned',
        limit: 1,
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final row = result.data![0];
        final id = row['id'] as String;
        final q = (row['owned'] as num?)?.toInt() ?? 0;
        final newQ = q - qty;
        if (newQ < 0) return false;
        final upd = await ApiClient.patchByFilter(
          'user_game_items',
          filters: {'id': 'eq.$id'},
          body: {'owned': newQ, 'updated_at': nowIso},
        );
        return upd.isSuccess;
      }
      return false; // 无库存行即视为不足
    } catch (e) {
      return false;
    }
  }

  /// 入库 upsert（owned +delta）。首次购买插入新行；已存在按 id PATCH。
  Future<bool> _upsertOwned(String itemId, int delta) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return false;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final result = await ApiClient.get(
        'user_game_items',
        filters: {
          'user_id': 'eq.$userId',
          'item_id': 'eq.$itemId',
        },
        columns: 'id,owned',
        limit: 1,
      );
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final row = result.data![0];
        final id = row['id'] as String;
        final q = (row['owned'] as num?)?.toInt() ?? 0;
        final newQ = q + delta;
        final upd = await ApiClient.patchByFilter(
          'user_game_items',
          filters: {'id': 'eq.$id'},
          body: {'owned': newQ, 'updated_at': nowIso},
        );
        return upd.isSuccess;
      } else if (delta > 0) {
        final ins = await ApiClient.post('user_game_items', {
          'id': const Uuid().v4(),
          'user_id': userId,
          'item_id': itemId,
          'owned': delta,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        return ins.isSuccess;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
