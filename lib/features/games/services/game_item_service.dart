import 'package:flutter/foundation.dart';

import 'package:pure_enjoy/core/utils/event_bus.dart';
import '../../../services/backend_api.dart';
import '../../../services/error_reporter.dart';
import '../../../features/profile/services/point_service.dart';
import '../models/game_item_model.dart';

/// 游戏道具商城服务（单例 + setState，与积分模块一致，禁 Riverpod）。
///
/// change-server：数据面走自建后端 `/games/items/**`——目录+库存同源
/// （`/items/mine` 全启用道具含持有数），购买/消耗为服务端原子操作
/// （扣积分/扣库存与流水同事务，无客户端补偿回退路径）。
class GameItemService {
  static GameItemService? _instance;
  GameItemService._();
  static GameItemService get instance {
    _instance ??= GameItemService._();
    return _instance!;
  }

  /// 目录+库存合并拉取：`item_id -> 行数据`（全启用道具，owned 无记录为 0）。
  Future<List<Map<String, dynamic>>> _fetchMineRows() async {
    final result = await BackendApi.get('/games/items/mine');
    if (!result.success) {
      debugPrint('[GameItemService] 道具目录/库存查询失败：${result.error}');
      ErrorReporter.reportMessage(
        '道具目录/库存查询失败：${result.error}',
        module: 'games',
        level: 'warning',
      );
      return <Map<String, dynamic>>[];
    }
    return [
      for (final row in result.list)
        if (row is Map<String, dynamic>) row,
    ];
  }

  /// 查询道具目录：返回该游戏已启用的道具。
  ///
  /// [mode] 非空时仅返回「通用道具(mode='')」或「匹配该模式的道具」；
  /// [mode] 为 null 时返回该游戏全部已启用道具（商城页用）。
  /// 服务端已按 game_code+sort_order 排序，过滤保持原序。
  Future<List<GameItemModel>> fetchItems({
    required String gameCode,
    String? mode,
  }) async {
    try {
      final rows = await _fetchMineRows();
      return [
        for (final row in rows)
          if (row['game_code']?.toString() == gameCode)
            GameItemModel.fromJson(<String, dynamic>{
              ...row,
              'id': row['item_id'],
              'enabled': true,
            }),
      ]
          .where((it) => mode == null || it.mode.isEmpty || it.mode == mode)
          .toList();
    } catch (e) {
      return <GameItemModel>[];
    }
  }

  /// 查询当前用户持有库存，返回 `item_id -> owned` 映射。
  Future<Map<String, int>> fetchInventory() async {
    try {
      final rows = await _fetchMineRows();
      return <String, int>{
        for (final row in rows)
          if (row['item_id'] != null)
            row['item_id'].toString(): (row['owned'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      return <String, int>{};
    }
  }

  /// 购买道具：服务端按 point_cost 扣积分并入库（同事务原子）。
  ///
  /// 客户端仅做余额预检提升体验，最终以服务端校验为准；失败原因直接
  /// 透出后端文案（积分不足等）。返回标准结果。
  Future<Map<String, dynamic>> purchase(GameItemModel item) async {
    try {
      final available = await PointService.instance.getAvailablePoints();
      if (available < item.pointCost) {
        return {
          'success': false,
          'message': '积分不足，需 ${item.pointCost} 积分',
        };
      }
      // 幂等键：同一动作重试同键，服务端按 claim_key 去重防双扣
      final requestId = 'pur_${DateTime.now().microsecondsSinceEpoch}';
      final result = await BackendApi
          .post('/games/items/${item.id}/purchase?quantity=1&requestId=$requestId');
      if (!result.success) {
        final message = result.error;
        ErrorReporter.reportMessage(
          '道具购买失败：$message（item=${item.id}）',
          module: 'games',
        );
        return {'success': false, 'message': message};
      }
      EventBus.instance.fire(EventType.pointsUpdated);
      final owned =
          ((result.data is Map<String, dynamic> ? result.data['owned'] : null)
                  as num?)
              ?.toInt() ??
              0;
      return {
        'success': true,
        'message': '购买成功，获得 1 张${item.name}',
        'owned': owned,
      };
    } catch (e) {
      return {'success': false, 'message': '购买失败，请稍后重试'};
    }
  }

  /// 游戏内消耗道具：扣减库存（服务端条件更新保证并发不为负）。
  /// 返回成功与否（库存不足/异常返回 false）。[dryRun]=true 仅预检不扣。
  /// 后端单次扣 1 张，[qty]>1 时按次串行调用（任一失败即止）。
  Future<bool> consumeItem(String itemId, {int qty = 1, bool dryRun = false}) async {
    try {
      for (var i = 0; i < qty; i++) {
        final result = await BackendApi
            .post('/games/items/$itemId/consume?dryRun=$dryRun');
        if (!result.success) {
          debugPrint(
              '[GameItemService] 道具消耗失败：${result.error}（item=$itemId）');
          return false;
        }
        final data = result.data;
        if (data is Map<String, dynamic> && data['can_consume'] != true) {
          return false;
        }
      }
      return true;
    } catch (e) {
      // 错误上报（2026-09-11）：道具消耗异常会导致玩家扣不到/白扣券
      ErrorReporter.reportMessage(
        '道具消耗异常：$e（item=$itemId）',
        module: 'games',
      );
      return false;
    }
  }
}
