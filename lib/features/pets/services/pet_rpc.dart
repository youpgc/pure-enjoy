import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/pet_rpc_models.dart';
import 'pet_service.dart';

/// 宠物业务 RPC / 列表查询（B4 交互闭环）
///
/// 约定：
/// - 写操作统一走服务端 RPC（行锁 + 流水同事务），成功后 [PetService.invalidateSummary]
///   失效总览缓存；失败返回错误原文（UI 层经 petRpcErrorText 转中文）；
/// - 列表查询为表直查（RLS 限本人 + 显式 user_id 过滤双保险）；
/// - 返回值统一 `(T?, String?)`：成功数据 + 错误原文。
class PetRpc {
  PetRpc._();

  static String? get _uid => SupabaseService.instance.currentUserId;

  // ============================================================
  // 查询
  // ============================================================

  /// 背包列表（slot 顺序；嵌套取道具目录）
  ///
  /// 堆叠上限以 `pet_items.stack_limit` 为准，缺列时兜底取 [PetService.stackLimitDefault]
  /// （= 后台 `pet_config.stack_limit_default`），不在客户端写死数值。
  static Future<(List<PetBagItemModel>, String?)> fetchBag() async {
    final uid = _uid;
    if (uid == null) return const (<PetBagItemModel>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_bag_items',
        select:
            'id,quantity,slot_index,item:pet_items(id,item_code,name,icon,category,sub_type,effect,stack_limit)',
        filters: {'user_id': 'eq.$uid'},
        order: 'slot_index.asc',
        limit: 200,
        note: 'pet_bag_items 背包列表查询',
      );
      if (!resp.isSuccess) return (const <PetBagItemModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      final stackLimitDefault = PetService.instance.stackLimitDefault;
      return (
        rows
            .map((r) =>
                PetBagItemModel.fromJson(r, stackLimitDefault: stackLimitDefault))
            .toList(),
        null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 背包查询失败: $e');
      return (const <PetBagItemModel>[], e.toString());
    }
  }

  /// 未孵出的蛋列表（unopened / waiting / ready；hatched 已出宠不取）
  ///
  /// P2 起含等待孵化通道：wait 模式蛋须先 rpc_pet_hatch_wait 计时，
  /// 到点置 ready 后再走 rpc_pet_hatch_instant 领取。
  static Future<(List<PetEggModel>, String?)> fetchEggs() async {
    final uid = _uid;
    if (uid == null) return const (<PetEggModel>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_eggs',
        select:
            'id,pool_code,mode,status,ready_at,bag_item_id,item:pet_items(name,item_code)',
        filters: {'user_id': 'eq.$uid', 'status': 'in.(unopened,waiting,ready)'},
        order: 'created_at.asc',
        limit: 100,
        note: 'pet_eggs 未孵出蛋查询',
      );
      if (!resp.isSuccess) return (const <PetEggModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetEggModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 蛋查询失败: $e');
      return (const <PetEggModel>[], e.toString());
    }
  }

  /// 当日任务（北京时区日期惰性对齐；先调 questsDraw 再查询）
  static Future<(List<PetQuestModel>, String?)> fetchTodayQuests() async {
    final uid = _uid;
    if (uid == null) return const (<PetQuestModel>[], '未登录');
    final todayBeijing = DateTimeUtils.todayBeijingKey();
    try {
      final resp = await ApiClient.get(
        'pet_daily_quests',
        select:
            'quest_id,progress,target,reward_claimed,quest:pet_quests(id,condition,rewards)',
        filters: {'user_id': 'eq.$uid', 'assign_date': 'eq.$todayBeijing'},
        limit: 50,
        note: 'pet_daily_quests 当日任务查询',
      );
      if (!resp.isSuccess) return (const <PetQuestModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (
        rows
            .map(PetQuestModel.fromJson)
            .where((q) => q.questId.isNotEmpty)
            .toList(),
        null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 任务查询失败: $e');
      return (const <PetQuestModel>[], e.toString());
    }
  }

  /// 启用中的历险地列表
  static Future<(List<PetSpotModel>, String?)> fetchSpots() async {
    try {
      final resp = await ApiClient.get(
        'pet_adventure_spots',
        select:
            'id,code,name,unlock_conditions,attr_requirements',
        filters: {'enabled': 'eq.true'},
        order: 'sort_order.asc',
        limit: 50,
        note: 'pet_adventure_spots 历险地查询',
      );
      if (!resp.isSuccess) return (const <PetSpotModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetSpotModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 历险地查询失败: $e');
      return (const <PetSpotModel>[], e.toString());
    }
  }

  /// 商城在售道具（扩容阶梯按 step 升序）
  static Future<(List<PetShopItemModel>, String?)> fetchShopItems() async {
    try {
      final resp = await ApiClient.get(
        'pet_items',
        select:
            'id,item_code,name,description,icon,category,sub_type,price_coin,price_points,points_purchasable,ladder_key,ladder_step',
        filters: {'on_shelf': 'eq.true', 'channels': 'in.(shop,both)'},
        order: 'ladder_step.asc.nullslast,price_coin.asc',
        limit: 100,
        note: 'pet_items 商城在售查询',
      );
      if (!resp.isSuccess) {
        return (const <PetShopItemModel>[], resp.errorMessage);
      }
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (
        rows.map(PetShopItemModel.fromJson).toList(),
        null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 商城查询失败: $e');
      return (const <PetShopItemModel>[], e.toString());
    }
  }

  // ============================================================
  // 写操作（RPC）
  // ============================================================

  /// 通用 RPC 调用：成功返回 raw（单对象 jsonb），失败返回错误原文
  static Future<(Map<String, dynamic>?, String?)> _call(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) async {
    final resp = await ApiClient.rpc(fn, params: params, note: note);
    if (!resp.isSuccess) return (null, resp.errorMessage);
    final raw = resp.raw;
    if (raw is Map) {
      return (Map<String, dynamic>.from(raw), null);
    }
    const Map<String, dynamic> empty = {};
    return (empty, null);
  }

  /// 供 P2 分组 [PetRpcP2] 复用的同一套 RPC 调用口径（错误原文 + raw jsonb）
  static Future<(Map<String, dynamic>?, String?)> callRpc(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) =>
      _call(fn, params, note);

  /// 即开孵化 → 成功返回孵化结果
  static Future<(PetHatchResultModel?, String?)> hatchEgg(String eggId) async {
    final (data, err) = await _call('rpc_pet_hatch_instant', {
      'p_egg_id': eggId,
    }, 'rpc_pet_hatch_instant 即开孵化');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (PetHatchResultModel.fromJson(data ?? const {}), null);
  }

  /// 喂养（免费档 p_item_id 传 null）
  static Future<String?> feed(String petId, {String? itemId}) async {
    final (_, err) = await _call('rpc_pet_feed', {
      'p_pet_id': petId,
      'p_item_id': itemId,
    }, 'rpc_pet_feed 喂养');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 互动（抚摸）
  static Future<String?> interact(String petId) async {
    final (_, err) = await _call('rpc_pet_interact', {
      'p_pet_id': petId,
    }, 'rpc_pet_interact 互动');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 使用道具（clean/toy/feed，对在养宠物）
  static Future<String?> useItem(String itemId, String petId) async {
    final (_, err) = await _call('rpc_pet_use_item', {
      'p_item_id': itemId,
      'p_pet_id': petId,
    }, 'rpc_pet_use_item 使用道具');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 商城购买（扩容道具服务端自动转阶梯 RPC）
  /// 返回 'bag_full' 表示容量预检未过（不扣款），UI 引导清理背包
  static Future<(String?, String?)> shopBuy(
    String itemId, {
    int qty = 1,
    String currency = 'coin',
  }) async {
    final (data, err) = await _call('rpc_pet_shop_buy', {
      'p_item_id': itemId,
      'p_qty': qty,
      'p_currency': currency,
    }, 'rpc_pet_shop_buy 商城购买');
    if (err != null) return (null, err);
    final status = data?['status'] as String?;
    if (status == 'bag_full') return ('bag_full', null);
    await PetService.instance.invalidateSummary();
    return ('ok', null);
  }

  /// 抽取/对齐当日任务（幂等，advisory lock 防并发）
  static Future<String?> questsDraw() async {
    final (_, err) = await _call(
        'rpc_pet_daily_quests_draw', {}, 'rpc_pet_daily_quests_draw 任务抽取');
    return err;
  }

  /// 领取任务奖励 → 返回 (gold, points)
  static Future<({int gold, int points})?> questClaim(
    String questId,
  ) async {
    final (data, err) = await _call('rpc_pet_daily_quests_claim', {
      'p_quest_id': questId,
    }, 'rpc_pet_daily_quests_claim 领取任务奖励');
    if (err != null) return null;
    await PetService.instance.invalidateSummary();
    return (
      gold: (data?['gold'] as num?)?.toInt() ?? 0,
      points: (data?['points'] as num?)?.toInt() ?? 0,
    );
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

  /// 背包整理（压缩空洞格位）
  ///
  /// 合并同道具堆叠会改变已用格数，故成功后失效总览缓存。
  static Future<String?> compactBag() async {
    final (_, err) = await _call(
        'rpc_pet_compact_bag', {}, 'rpc_pet_compact_bag 背包整理');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 背包换位/移入空格（服务端 rpc_pet_swap_slot 坐标交换，零 DDL）
  ///
  /// [from]/[to] 均为 slot_index（0 起）；目标为空时退化为移动。
  /// 服务端不合并同道具堆叠（合并由 rpc_pet_compact_bag 负责），
  /// 越界抛 PET_INVALID_SLOT，并发改动抛 PET_BAG_FULL_RACE。
  /// 换位不改变 bagUsed 与容量，故不失效总览缓存。
  static Future<String?> swapSlot(int from, int to) async {
    final (_, err) = await _call('rpc_pet_swap_slot', {
      'p_slot_a': from,
      'p_slot_b': to,
    }, 'rpc_pet_swap_slot 背包换位');
    return err;
  }

  /// 丢弃道具 rows: [{slot_index, quantity}]（按格位定位，rpc_pet_discard_items 契约）
  static Future<String?> discardItems(
    List<Map<String, dynamic>> rows,
  ) async {
    final (_, err) = await _call('rpc_pet_discard_items', {
      'p_rows': rows,
    }, 'rpc_pet_discard_items 丢弃道具');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 积分兑换金币（1 金币 = points_per_gold 积分）
  static Future<String?> exchange(int gold) async {
    final (_, err) = await _call('rpc_pet_exchange', {
      'p_gold': gold,
    }, 'rpc_pet_exchange 积分兑换');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 寄养搬运（[action]：`to_foster` 养育→寄养 / `from_foster` 寄养→养育）
  ///
  /// 服务端 `rpc_pet_foster_move`（feature_pet_foster_20260921.sql，零 DDL）：
  /// 占用量按 status 计数、容量 coalesce 后台初始值，满格抛 PET_FOSTER_FULL /
  /// PET_REARING_FULL；双向重置 last_decay_at（寄养期间不吃离线衰减）。
  static Future<String?> fosterMove(String petId, String action) async {
    final (_, err) = await _call('rpc_pet_foster_move', {
      'p_pet_id': petId,
      'p_action': action,
    }, 'rpc_pet_foster_move 寄养搬运');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 属性加点（升级获得的 pending_attr_points 分配到指定维度；
  /// 一次可分多点，服务端校验余额与维度白名单）
  static Future<String?> allocateAttr(
    String petId, {
    required String attrKey,
    required int points,
  }) async {
    final (_, err) = await _call('rpc_pet_allocate_attr', {
      'p_pet_id': petId,
      'p_attr_key': attrKey,
      'p_points': points,
    }, 'rpc_pet_allocate_attr 属性加点');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// 洗练重掷（消耗 1 洗练点，随机重掷加点属性，总值守恒；
  /// 孵化基础属性不受影响。返回 {before, after, refine_points, attributes} 供演出对比）
  /// 2026-09-20 语义变更：不再消耗 tool_refine 道具（其已转 +1 洗练点补给品，
  /// 走 use_item 通道）；[itemId] 参数保留兼容但服务端忽略
  static Future<(Map<String, dynamic>?, String?)> refineReassign(
    String petId, {
    String? itemId,
  }) async {
    final (data, err) = await _call('rpc_pet_refine_reassign', {
      'p_pet_id': petId,
      'p_item_id': itemId,
    }, 'rpc_pet_refine_reassign 洗练重掷');
    if (err == null) await PetService.instance.invalidateSummary();
    return (data, err);
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
