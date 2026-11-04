import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/pet_rpc_models.dart';
import '../utils/pet_errors.dart';
import 'pet_rpc.dart';
import 'pet_service.dart';

/// 宠物 RPC 商城/背包域（在售道具/购买/扩容记录/背包整理/换位/丢弃/兑换）
///
/// 与 [PetRpc] 分文件的原因：主类超 500 行硬底线，按域拆分；
/// 调用口径完全一致——复用 [PetRpc.callRpc]（错误原文 + raw jsonb）。
/// 自 pet_rpc.dart 拆出，调用方由 PetRpc.xxx 改为 PetRpcShop.xxx。
class PetRpcShop {
  PetRpcShop._();

  static String? get _uid => SupabaseService.instance.currentUserId;

  /// RPC 调用口径（复用 [PetRpc.callRpc]：错误原文 + raw jsonb）
  static Future<(Map<String, dynamic>?, String?)> _call(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) =>
      PetRpc.callRpc(fn, params, note);


  /// 扩容阶梯已购记录(本人;商城「只展示当前可购档」的过滤依据)
  static Future<(List<Map<String, dynamic>>, String?)> fetchExpansionRecords() async {
    final uid = _uid;
    if (uid == null) return (const <Map<String, dynamic>>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_expansion_records',
        select: 'ladder_key,step',
        filters: {'user_id': 'eq.$uid'},
        // desc 取最大已购步(超 limit 截掉的才是低 step 旧记录;
        // asc 会在超 50 条时把已购档当可购档展示)
        order: 'step.desc',
        limit: 50,
        note: 'pet_expansion_records 扩容已购查询',
      );
      if (!resp.isSuccess) return (const <Map<String, dynamic>>[], resp.errorMessage);
      return (resp.data ?? const <Map<String, dynamic>>[], null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 扩容已购查询失败');
      return (const <Map<String, dynamic>>[], kPetLocalError);
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
      if (kDebugMode) debugPrint('[PetRpc] 商城查询失败');
      return (const <PetShopItemModel>[], kPetLocalError);
    }
  }

  /// 商城购买（扩容道具服务端自动转阶梯 RPC）
  ///
  /// 返回 (结果, err)。结果为 [PetShopBuyResultModel.isBagFull] 时表示容量
  /// 预检未过、**未扣款**，腾位选项（下一级扩容道具 / 容量占用）在结果里——
  /// UI 据此走「扩容后重试 / 清理背包」引导（需求 §5.4，扣款前决策）。
  static Future<(PetShopBuyResultModel?, String?)> shopBuy(
    String itemId, {
    int qty = 1,
    // p_currency 服务端支持 'points' 通道，但积分购买入口未实装
    // 线上全部在架道具 price_points=null / points_purchasable=false
    // points 分支实际不可达，维持恒 'coin'。
    String currency = 'coin',
  }) async {
    final (data, err) = await _call('rpc_pet_shop_buy', {
      'p_item_id': itemId,
      'p_qty': qty,
      'p_currency': currency,
    }, 'rpc_pet_shop_buy 商城购买');
    if (err != null) return (null, err);
    if (data == null) return (null, kPetLocalError);
    final result = PetShopBuyResultModel.fromJson(data);
    // 满格未扣款：总览无变化，不失效缓存（与原行为一致）
    if (!result.isBagFull) await PetService.instance.invalidateSummary();
    return (result, null);
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
  /// 服务端不合并同道具堆叠（合并由 rpc_pet_compact_bag 负责）
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
}
