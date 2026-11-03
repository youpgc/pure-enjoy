import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/pet_rpc_models.dart';
import '../utils/pet_errors.dart';
import 'pet_rpc.dart';
import 'pet_service.dart';

/// 宠物 RPC 历险域（历险地/隐藏点/解锁/结算/救援/匹配/概率公示）
///
/// 与 [PetRpc] 分文件的原因：主类超 500 行硬底线，按域拆分；
/// 调用口径完全一致——复用 [PetRpc.callRpc]（错误原文 + raw jsonb）。
/// 自 pet_rpc.dart 拆出（20261103），调用方由 PetRpc.xxx 改为 PetRpcAdventure.xxx。
class PetRpcAdventure {
  PetRpcAdventure._();

  static String? get _uid => SupabaseService.instance.currentUserId;

  /// RPC 调用口径（复用 [PetRpc.callRpc]：错误原文 + raw jsonb）
  static Future<(Map<String, dynamic>?, String?)> _call(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) =>
      PetRpc.callRpc(fn, params, note);


  /// 已解锁的隐秘境 code 集（pet_user_features 键 spot_hidden:<code>）
  static Future<Set<String>> fetchUnlockedHiddenSpots() async {
    final uid = _uid;
    if (uid == null) return const <String>{};
    try {
      final resp = await ApiClient.get(
        'pet_user_features',
        select: 'feature_key',
        filters: {'user_id': 'eq.$uid', 'feature_key': 'like.spot_hidden.*'},
        limit: 100,
        note: 'pet_user_features 隐秘境解锁集',
      );
      if (!resp.isSuccess) return const <String>{};
      return (resp.data ?? const <Map<String, dynamic>>[])
          .map((r) => (r['feature_key'] as String? ?? '')
              .replaceFirst('spot_hidden:', ''))
          .where((c) => c.isNotEmpty)
          .toSet();
    } catch (_) {
      if (kDebugMode) debugPrint('[PetRpc] 隐秘境解锁集查询失败，回退空集');
      return const <String>{};
    }
  }

  /// 已开通功能键集（pet_user_features 全量）。
  ///
  /// 消费方：商城解锁类道具「购买后不再展示」（20261030 定版：unlock 类
  /// 限购 1 次，已购在包或功能已开通即隐藏）；查询失败回退空集不拦截商城，
  /// 购买时服务端限购/已解锁校验仍兜底。
  static Future<Set<String>> fetchUnlockedFeatures() async {
    final uid = _uid;
    if (uid == null) return const <String>{};
    try {
      final resp = await ApiClient.get(
        'pet_user_features',
        select: 'feature_key',
        filters: {'user_id': 'eq.$uid'},
        limit: 100,
        note: 'pet_user_features 已开通功能集',
      );
      if (!resp.isSuccess) return const <String>{};
      return (resp.data ?? const <Map<String, dynamic>>[])
          .map((r) => r['feature_key'] as String? ?? '')
          .where((k) => k.isNotEmpty)
          .toSet();
    } catch (_) {
      if (kDebugMode) debugPrint('[PetRpc] 已开通功能集查询失败，回退空集');
      return const <String>{};
    }
  }

  /// 罗盘解锁隐秘境（消耗 1 个星辰罗盘；服务端 rpc_pet_spot_hidden_unlock）
  static Future<String?> unlockHiddenSpot(String spotCode) async {
    final (_, err) = await _call(
      'rpc_pet_spot_hidden_unlock',
      {'p_spot_code': spotCode},
      'rpc_pet_spot_hidden_unlock 罗盘解锁隐秘境',
    );
    if (err != null) return err;
    await PetService.instance.invalidateSummary();
    return null;
  }

  static Future<(List<PetSpotModel>, String?)> fetchSpots() async {
    try {
      final resp = await ApiClient.get(
        'pet_adventure_spots',
        select:
            'id,code,name,unlock_conditions,attr_requirements,hidden',
        filters: {'enabled': 'eq.true'},
        order: 'sort_order.asc',
        limit: 100,
        note: 'pet_adventure_spots 历险地查询',
      );
      if (!resp.isSuccess) return (const <PetSpotModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetSpotModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 历险地查询失败');
      return (const <PetSpotModel>[], kPetLocalError);
    }
  }

  /// 游历档位配置（pet_config.adventure_tiers：[{tier,minutes,label}]）——
  /// 公示页档位名/时长与此同源；查询失败返回空（调用方回落端内文案）
  static Future<List<Map<String, dynamic>>> fetchAdventureTiers() async {
    try {
      final resp = await ApiClient.get(
        'pet_config',
        select: 'adventure_tiers',
        limit: 1,
        note: 'pet_config 游历档位配置',
      );
      final row = resp.data?.isNotEmpty == true ? resp.data!.first : null;
      final raw = row?['adventure_tiers'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      if (kDebugMode) debugPrint('[PetRpc] 游历档位配置查询失败，回退端内文案');
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<(List<Map<String, dynamic>>, String?)> fetchAdventureOdds() async {
    try {
      final resp = await ApiClient.get(
        'pet_adventure_spots',
        select: 'code,name,drop_table',
        filters: {'enabled': 'eq.true'},
        order: 'sort_order.asc',
        limit: 100,
        note: 'pet_adventure_spots 历险产出公示查询',
      );
      if (!resp.isSuccess) return (const <Map<String, dynamic>>[], resp.errorMessage);
      return (resp.data ?? const <Map<String, dynamic>>[], null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 历险产出公示查询失败');
      return (const <Map<String, dynamic>>[], kPetLocalError);
    }
  }

  /// 出发历险
  static Future<String?> adventureStart({
    required String petId,
    required String spotId,
    required String tier,
  }) async {
    final (_, err) = await _call('rpc_pet_adventure_start', {
      'p_pet_id': petId,
      'p_spot_id': spotId,
      'p_tier': tier,
    }, 'rpc_pet_adventure_start 出发历险');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 领取历险结果
  /// 返回 status: claimed（含 gold/exp/result_type）或 awaiting_rescue（遇险）
  static Future<(Map<String, dynamic>?, String?)> adventureClaim(
    String adventureId,
  ) async {
    final (data, err) = await _call('rpc_pet_adventure_claim', {
      'p_adventure_id': adventureId,
    }, 'rpc_pet_adventure_claim 领取历险结果');
    if (err == null) await PetService.instance.invalidateSummary();
    return (data, err);
  }

  /// 召回（进行中历险主动中断，无奖励）
  static Future<String?> adventureRecall(String adventureId) async {
    final (_, err) = await _call('rpc_pet_adventure_recall', {
      'p_adventure_id': adventureId,
    }, 'rpc_pet_adventure_recall 召回');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 救助（self=救援道具 / npc=超时兜底）
  static Future<String?> adventureRescue(
    String adventureId, {
    String? itemId,
  }) async {
    final (_, err) = await _call('rpc_pet_adventure_rescue', {
      'p_adventure_id': adventureId,
      'p_item_id': itemId,
    }, 'rpc_pet_adventure_rescue 救助');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 为你匹配（推荐制）：返回等级达标的候选历险地（含 attr_requirements），
  /// 其中一个带 recommended=true 标记；服务端同时校验饱食/心情/健康门槛，
  /// 不达标时返回错误（调用方可静默降级为无推荐）
  static Future<(Map<String, dynamic>?, String?)> adventureMatch(
    String petId,
  ) async {
    return _call('rpc_pet_adventure_match', {
      'p_pet_id': petId,
    }, 'rpc_pet_adventure_match 历险地匹配');
  }
}
