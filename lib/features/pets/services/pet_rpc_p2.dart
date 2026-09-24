import 'package:flutter/foundation.dart';

import '../../../constants/pet.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/pet_p2_breed_models.dart';
import '../models/pet_p2_models.dart';
import '../models/pet_p2_progress_models.dart';
import '../utils/pet_errors.dart';
import 'pet_rpc.dart';
import 'pet_service.dart';

/// 宠物 P2 RPC 与直查（进化/特性洗练/等待孵化/解锁/繁育/成就/周任务/概率公示）
///
/// 后端契约唯一源：`D:\workspace\sql\feature_pet_p2_rpcs_20260923.sql`（2026-09-23 已上线）。
/// 与 [PetRpc] 分文件的原因：P1 侧已 406 行，合并会破 500 行硬底线；
/// 调用口径完全一致——复用 [PetRpc.callRpc]，写成功后统一失效总览缓存。
///
/// 三条易错契约（写死在此，改调用前先看）：
/// 1. 所有 `p_item_id` 都是 **pet_items.id（道具定义 uuid）**，不是背包行 id；
///    数量恒为 1，服务端自行定位本人背包行；
/// 2. 错误一律 `RAISE EXCEPTION '<CODE>'`（PostgREST message 透传，经
///    petRpcErrorText 转文案），**唯一软失败**是 breed_claim 的 `ok:false + status:'bag_full'`；
/// 3. `evolve.items` 是 jsonb **对象**（item-uuid→数量），
///    成就/周任务 claim 的 `items` 是 jsonb **数组**——两者形状不同，不共用解析。
class PetRpcP2 {
  PetRpcP2._();

  static String? get _uid => SupabaseService.instance.currentUserId;

  // ============================================================
  // 直查（配置表 authenticated read；本人资产表 RLS 限本人）
  // ============================================================

  /// 本人宠物明细（补总览未下发的 species_id / 进化链 / 特性三块）
  static Future<(List<PetPetDetailModel>, String?)> fetchPetDetails() async {
    final uid = _uid;
    if (uid == null) return const (<PetPetDetailModel>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_pets',
        select:
            'id,show_no,stage,level,intimacy,gender,status,trait_id,'
            'species:pet_species(id,species_code,name_cn,family,rarity_code,evolution_chain_id,enabled),'
            'trait:pet_traits(id,code,name)',
        filters: {'user_id': 'eq.$uid'},
        order: 'created_at.asc',
        limit: 50,
        note: 'pet_pets 宠物明细查询（进化/特性）',
      );
      if (!resp.isSuccess) return (const <PetPetDetailModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetPetDetailModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] 宠物明细查询失败: $e');
      return (const <PetPetDetailModel>[], kPetLocalError);
    }
  }

  /// 某链下一阶段的候选形态（[stage] 传「目标阶」，即当前 stage+1）
  static Future<(List<PetEvoStageOptionModel>, String?)> fetchEvoOptions(
    String chainId,
    int stage,
  ) async {
    if (chainId.isEmpty) return (const <PetEvoStageOptionModel>[], null);
    try {
      final resp = await ApiClient.get(
        'pet_evo_stages',
        select:
            'stage,branch_key,branch_weight,pick_mode,conditions,'
            'species:pet_species(id,species_code,name_cn,rarity_code,enabled)',
        filters: {'chain_id': 'eq.$chainId', 'stage': 'eq.$stage'},
        order: 'branch_weight.desc',
        limit: 20,
        note: 'pet_evo_stages 进化候选查询',
      );
      if (!resp.isSuccess) {
        return (const <PetEvoStageOptionModel>[], resp.errorMessage);
      }
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetEvoStageOptionModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] 进化候选查询失败: $e');
      return (const <PetEvoStageOptionModel>[], kPetLocalError);
    }
  }

  /// 本人繁育单据（亲代名由调用方用 fetchPetDetails 的结果回填，避免双嵌同名表）
  static Future<(List<PetBreedOrderModel>, String?)> fetchBreedOrders() async {
    final uid = _uid;
    if (uid == null) return const (<PetBreedOrderModel>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_breed_logs',
        select: 'id,pet_a_id,pet_b_id,started_at,ready_at,status,egg_id',
        filters: {'user_id': 'eq.$uid'},
        order: 'started_at.desc',
        limit: 30,
        note: 'pet_breed_logs 繁育单据查询',
      );
      if (!resp.isSuccess) return (const <PetBreedOrderModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetBreedOrderModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] 繁育单据查询失败: $e');
      return (const <PetBreedOrderModel>[], kPetLocalError);
    }
  }

  /// 本人已开通功能（决定繁育入口是否可用；未解锁时 UI 引导商城买「繁育巢穴」）
  static Future<(List<PetFeatureModel>, String?)> fetchUnlockedFeatures() async {
    final uid = _uid;
    if (uid == null) return const (<PetFeatureModel>[], '未登录');
    try {
      final resp = await ApiClient.get(
        'pet_user_features',
        select: 'feature_key,unlocked_at',
        filters: {'user_id': 'eq.$uid'},
        limit: 20,
        note: 'pet_user_features 功能开通查询',
      );
      if (!resp.isSuccess) return (const <PetFeatureModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetFeatureModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] 功能开通查询失败: $e');
      return (const <PetFeatureModel>[], kPetLocalError);
    }
  }

  /// 已发布蛋池概率（取每个 pool_code 的最高 config_version，与服务端判定同源）
  ///
  /// 公示页只读此结果，客户端**不做任何概率推算**；未发布的池一律不展示。
  static Future<(List<PetEggOddsModel>, String?)> fetchPublishedEggOdds() async {
    try {
      final resp = await ApiClient.get(
        'pet_egg_pools',
        select: 'pool_code,config_version,weights',
        filters: {'published': 'eq.true'},
        order: 'pool_code.asc,config_version.desc',
        limit: 100,
        note: 'pet_egg_pools 概率公示查询',
      );
      if (!resp.isSuccess) return (const <PetEggOddsModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      // 已按版本降序，同池只保留首个（=最高版本）
      final seen = <String>{};
      final odds = <PetEggOddsModel>[];
      for (final r in rows) {
        final model = PetEggOddsModel.fromJson(r);
        if (model.poolCode.isEmpty || !seen.add(model.poolCode)) continue;
        odds.add(model);
      }
      return (odds, null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] 概率公示查询失败: $e');
      return (const <PetEggOddsModel>[], kPetLocalError);
    }
  }

  /// P2 门槛参数（pet_config.reserved：加速金币、亲密度门槛、孕期、手续费）
  ///
  /// 只读 GET、无副作用；总览 config 快照里没有 reserved，故单独取一次。
  static Future<(PetReservedModel, String?)> fetchReserved() async {
    try {
      final resp = await ApiClient.get(
        'pet_config',
        select: 'reserved',
        limit: 1,
        note: 'pet_config P2 门槛查询',
      );
      if (!resp.isSuccess) return (const PetReservedModel({}), resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (
        PetReservedModel.fromJson(rows.isEmpty ? const {} : rows.first),
        null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpcP2] P2 门槛查询失败: $e');
      return (const PetReservedModel({}), kPetLocalError);
    }
  }

  // ============================================================
  // 写操作（RPC）
  // ============================================================
  /// 进化（[targetSpeciesId] 仅多分支阶段需要显式传，单分支留空由服务端直取）
  static Future<(PetEvolveResultModel?, String?)> evolve(
    String petId, {
    String? targetSpeciesId,
  }) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_evolve', {
      'p_pet_id': petId,
      'p_species_id': targetSpeciesId,
    }, 'rpc_pet_evolve 进化');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (PetEvolveResultModel.fromJson(data ?? const {}), null);
  }

  /// 特性洗练（[itemId] = trait_wash 道具的 pet_items.id；结果不可回退）
  static Future<(PetWashTraitResultModel?, String?)> washTrait(
    String petId,
    String itemId,
  ) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_wash_trait', {
      'p_pet_id': petId,
      'p_item_id': itemId,
    }, 'rpc_pet_wash_trait 特性洗练');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    return (
      PetWashTraitResultModel(
        petId: raw['pet_id'] as String? ?? petId,
        traitId: raw['trait_id'] as String?,
        traitCode: raw['trait_code'] as String?,
        traitName: raw['trait_name'] as String?,
        oldTraitCode: raw['old_trait_code'] as String?,
        changed: raw['changed'] as bool? ?? false,
      ),
      null,
    );
  }

  /// 让一枚 wait 模式的蛋进入等待孵化（幂等：已在等待/已可领取时直接回当前状态）
  static Future<(PetHatchWaitResultModel?, String?)> hatchWait(String eggId) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_hatch_wait', {
      'p_egg_id': eggId,
    }, 'rpc_pet_hatch_wait 进入等待孵化');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (PetHatchWaitResultModel.fromJson(data ?? const {}), null);
  }

  /// 加速等待中的蛋（[mode]=item 需传 [itemId]；gold 花 pet_config 的 {hatch,accel_gold}）
  static Future<(PetHatchWaitResultModel?, String?)> hatchAccelerate(
    String eggId, {
    PetAccelMode mode = PetAccelMode.item,
    String? itemId,
  }) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_hatch_accelerate', {
      'p_egg_id': eggId,
      'p_mode': mode.code,
      'p_item_id': itemId,
    }, 'rpc_pet_hatch_accelerate 孵化加速');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (PetHatchWaitResultModel.fromJson(data ?? const {}), null);
  }

  /// 使用解锁道具（feature_key 由道具 effect 决定，客户端不传）
  static Future<(PetUnlockResultModel?, String?)> unlockFeature(String itemId) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_unlock_feature', {
      'p_item_id': itemId,
    }, 'rpc_pet_unlock_feature 功能解锁');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    return (
      PetUnlockResultModel(
        featureKey: raw['feature_key'] as String? ?? '',
        itemCode: raw['item_code'] as String? ?? '',
      ),
      null,
    );
  }

  /// 结配（同体系、异性、双亲均在养且亲密度达标、无进行中单据）
  static Future<(PetBreedStartResultModel?, String?)> breedStart(
    String petAId,
    String petBId,
  ) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_breed_start', {
      'p_pet_a_id': petAId,
      'p_pet_b_id': petBId,
    }, 'rpc_pet_breed_start 结配');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    return (
      PetBreedStartResultModel(
        logId: raw['log_id'] as String? ?? '',
        readyAt: DateTime.tryParse(raw['ready_at'] as String? ?? ''),
        gestationHours: (raw['gestation_hours'] as num?)?.toInt() ?? 0,
        feeGold: (raw['fee_gold'] as num?)?.toInt() ?? 0,
        nextBreedAt: DateTime.tryParse(raw['next_breed_at'] as String? ?? ''),
      ),
      null,
    );
  }

  /// 领取繁育产蛋；背包满时返回 `bagFull=true` 的软失败结果（不是错误，
  /// 亲代已释放且单据停在 ready——清包后重调即可，服务端幂等不回退）
  static Future<(PetBreedClaimResultModel?, String?)> breedClaim(String logId) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_breed_claim', {
      'p_log_id': logId,
    }, 'rpc_pet_breed_claim 领取产蛋');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    final bagFull = (raw['ok'] as bool?) != true;
    return (
      PetBreedClaimResultModel(
        logId: raw['log_id'] as String? ?? logId,
        eggId: raw['egg_id'] as String?,
        eggItemId: raw['egg_item_id'] as String?,
        eggName: raw['egg_name'] as String? ?? '宠物蛋',
        poolCode: raw['pool_code'] as String? ?? '',
        rarity: raw['rarity'] as String? ?? '',
        nextBreedAt: DateTime.tryParse(raw['next_breed_at'] as String? ?? ''),
        bagFull: bagFull,
        capacity: (raw['capacity'] as num?)?.toInt() ?? 0,
        used: (raw['used'] as num?)?.toInt() ?? 0,
      ),
      null,
    );
  }

  /// 成就进度对齐（幂等、进度单调不回退；无错误分支）
  static Future<(List<PetAchievementModel>, String?)> achievementCheck() async {
    final (data, err) = await PetRpc.callRpc(
        'rpc_pet_achievement_check', {}, 'rpc_pet_achievement_check 成就对齐');
    if (err != null) return (const <PetAchievementModel>[], err);
    final rows = (data?['achievements'] as List?) ?? const [];
    return (
      rows
          .whereType<Map>()
          .map((e) => PetAchievementModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      null,
    );
  }

  /// 领取成就奖励（bag_full 走 PET_BAG_FULL_CLAIM_RETRY 异常，整事务回滚）
  static Future<(PetAchClaimResultModel?, String?)> achievementClaim(
    String achievementId,
  ) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_achievement_claim', {
      'p_achievement_id': achievementId,
    }, 'rpc_pet_achievement_claim 领取成就');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    return (
      PetAchClaimResultModel(
        code: raw['code'] as String? ?? '',
        title: raw['title'] as String? ?? '',
        gold: (raw['gold'] as num?)?.toInt() ?? 0,
        points: (raw['points'] as num?)?.toInt() ?? 0,
        items: PetRewardItemModel.parseList(raw['items']),
      ),
      null,
    );
  }

  /// 抽取/对齐本周任务（惰性、幂等）→ 返回 (任务列表, 周锚点日期)
  static Future<(List<PetWeeklyQuestModel>, String?, String?)> weeklyQuestsDraw() async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_weekly_quests_draw', {},
        'rpc_pet_weekly_quests_draw 周任务抽取');
    if (err != null) return (const <PetWeeklyQuestModel>[], null, err);
    final rows = (data?['quests'] as List?) ?? const [];
    final quests = rows
        .whereType<Map>()
        .map((e) => PetWeeklyQuestModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (quests, data?['week_start'] as String?, null);
  }

  /// 领取周任务奖励（[questId] = pet_quests.id，**不是**实例行 id）
  static Future<(PetWeeklyClaimResultModel?, String?)> weeklyQuestClaim(
    String questId,
  ) async {
    final (data, err) = await PetRpc.callRpc('rpc_pet_weekly_quests_claim', {
      'p_quest_id': questId,
    }, 'rpc_pet_weekly_quests_claim 领取周任务');
    if (err != null) return (null, err);
    final raw = data ?? const <String, dynamic>{};
    await PetService.instance.invalidateSummary();
    return (
      PetWeeklyClaimResultModel(
        gold: (raw['gold'] as num?)?.toInt() ?? 0,
        points: (raw['points'] as num?)?.toInt() ?? 0,
        items: PetRewardItemModel.parseList(raw['items']),
      ),
      null,
    );
  }
}
