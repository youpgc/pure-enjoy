import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/error_reporter.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
import '../models/pet_dex_models.dart';
import '../models/pet_rpc_models.dart';
import '../utils/pet_dict.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_home_budget.dart';
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
            'id,quantity,slot_index,item:pet_items(id,item_code,name,description,icon,category,sub_type,effect,stack_limit)',
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
      if (kDebugMode) debugPrint('[PetRpc] 背包查询失败');
      return (const <PetBagItemModel>[], kPetLocalError);
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
            'id,pool_code,mode,status,ready_at,bag_item_id,item:pet_items(name,item_code,icon)',
        filters: {'user_id': 'eq.$uid', 'status': 'in.(unopened,waiting,ready)'},
        order: 'created_at.asc',
        limit: 100,
        note: 'pet_eggs 未孵出蛋查询',
      );
      if (!resp.isSuccess) return (const <PetEggModel>[], resp.errorMessage);
      final rows = resp.data ?? const <Map<String, dynamic>>[];
      return (rows.map(PetEggModel.fromJson).toList(), null);
    } catch (e) {
      if (kDebugMode) debugPrint('[PetRpc] 蛋查询失败');
      return (const <PetEggModel>[], kPetLocalError);
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
        filters: {
          'user_id': 'eq.$uid',
          'assign_date': 'eq.$todayBeijing',
          // ★ 只认 daily 任务：周任务复用本表（assign_date=周一），不过滤 type
          //   时周一「每日」页签会串显周任务（与服务端抽取判定同步修复，P1-1）
          'quest.type': 'eq.daily',
        },
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
      if (kDebugMode) debugPrint('[PetRpc] 任务查询失败');
      return (const <PetQuestModel>[], kPetLocalError);
    }
  }

  /// 启用中的历险地列表
  /// 幸运抽奖（服务端 rpc_pet_lottery_draw：双限购闸+扣金币+复用孵化全链）
  static Future<(Map<String, dynamic>?, String?)> lotteryDraw() async =>
      callRpc('rpc_pet_lottery_draw', const {},
          'rpc_pet_lottery_draw 幸运抽奖');

  /// 收藏兑换（服务端 rpc_pet_collection_exchange：配方校验+满包预检+扣料入包；
  /// 配方来自 reserved.collection_exchange，返回 bag_full 状态走腾位流程）
  static Future<(Map<String, dynamic>?, String?)> collectionExchange(
          String fromCode, String toCode) async =>
      callRpc('rpc_pet_collection_exchange',
          {'p_from_code': fromCode, 'p_to_code': toCode},
          'rpc_pet_collection_exchange 收藏兑换');

  /// 历险产出公示（概率/保底展示的判定同源数据）：30 地 drop_table 原始行
  /// （含 long_only 独占掉落）。仅展示；概率判定仍在服务端 RPC（铁律 1）
  /// 道具名映射（item_code → pet_items.name，服务端真源）——
  /// 概率公示等读 jsonb 掉落表的场景用它取中文名；kLongDropNames 仅兜底
  static Future<Map<String, String>> fetchItemNames() async {
    try {
      final resp = await ApiClient.get(
        'pet_items',
        select: 'item_code,name',
        limit: 500,
        note: 'pet_items 道具名映射',
      );
      if (!resp.isSuccess) return const {};
      return {
        for (final r in (resp.data ?? const <Map<String, dynamic>>[]))
          if (r['item_code'] is String && r['name'] is String)
            r['item_code'] as String: r['name'] as String,
      };
    } catch (_) {
      if (kDebugMode) debugPrint('[PetRpc] 道具名映射查询失败，回退空表');
      return const {};
    }
  }

  /// 道具图标映射（item_code → pet_items.icon 资源键）——
  /// 签到格子/里程碑奖励图标化展示用；缺图由调用方回退兜底
  static Future<Map<String, String>> fetchItemIcons() async {
    try {
      final resp = await ApiClient.get(
        'pet_items',
        select: 'item_code,icon',
        limit: 500,
        note: 'pet_items 道具图标映射',
      );
      if (!resp.isSuccess) return const {};
      return {
        for (final r in (resp.data ?? const <Map<String, dynamic>>[]))
          if (r['item_code'] is String && r['icon'] is String)
            r['item_code'] as String: r['icon'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// 宠物字典（pet_dict_items：家系/商城子类型/时间线事件，20261030 沉淀）——
  /// 一次拉全填充 [PetDict] 缓存；失败静默（消费点走端内兜底，同场景名模式）。
  /// rpc 返回单 jsonb 对象（非数组），承载于 resp.raw（resp.data 为空列表）
  static Future<void> fetchDicts() async {
    try {
      final resp = await ApiClient.rpc('rpc_pet_dicts');
      if (resp.isSuccess) PetDict.fill(resp.raw);
    } catch (_) {
      if (kDebugMode) debugPrint('[PetRpc] 字典拉取失败，走端内兜底');
    }
  }

  // ============================================================
  // 写操作（RPC）
  // ============================================================

  /// 通用 RPC 调用：成功返回 raw（单对象 jsonb），失败返回错误原文
  ///
  /// 错误日志埋点（2026-11-03）：失败分两类——
  ///   ① 业务拒绝（服务端 raise 的 PET_* 错误码，App 侧转用户文案）→ 不上报，
  ///      属正常交互语义，入错误日志只会刷屏；
  ///   ② 其余（网络失败/解析异常/服务端真异常如约束违约）→ 入错误日志
  ///      （error_logs.module='pets'），后台「系统设置→错误日志」可查。
  ///      5xx 与 4xx 非 PET_* 记 error（后者多为服务端真 bug，如 23502），
  ///      网络层失败记 warning（离线常态，不制造告警噪音）。
  static Future<(Map<String, dynamic>?, String?)> _call(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) async {
    final resp = await ApiClient.rpc(fn, params: params, note: note);
    if (!resp.isSuccess) {
      final msg = resp.errorMessage ?? '';
      // 「请求已取消」= 用户离开页面的正常取消，不入日志；PET_* 业务拒绝同理
      if (!msg.startsWith('PET_') && msg != '请求已取消') {
        final code = resp.statusCode ?? 0;
        ErrorReporter.reportMessage(
          'RPC $fn 失败(HTTP ${resp.statusCode ?? '-'}): $msg',
          module: 'pets',
          // HTTP 层失败（4xx 真异常/5xx）记 error；网络层失败（0/无状态码）记 warning
          level: code >= 400 ? 'error' : 'warning',
          stack: StackTrace.current,
        );
      }
      return (null, resp.errorMessage);
    }
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
  ///
  /// [family] 仅初始蛋自选种属（initial_ssr 池）携带：cat/dog/rabbit/mouse；
  /// 其他蛋不传。服务端校验种属在池配置 initial_choices 内，非法即拒。
  static Future<(PetHatchResultModel?, String?)> hatchEgg(String eggId,
      {String? family}) async {
    final (data, err) = await _call('rpc_pet_hatch_instant', {
      'p_egg_id': eggId,
      if (family != null && family.isNotEmpty) 'p_family': family,
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
    if (err == null) {
      // 成功即记录本地冷却锚点(吸收服务端/客户端时钟差,20261021)。
      // 仅免费档记:道具档(口粮)服务端不写 last_feed_at、不占免费冷却,
      // 记了锚点会把免费档锁进整段假冷却(20261021 审查 P1)
      if (itemId == null) PetActionBudget.noteActionAnchor(petId, 'feed');
      await PetService.instance.invalidateSummary();
    }
    return err;
  }

  /// 互动（抚摸）
  static Future<String?> interact(String petId) async {
    final (_, err) = await _call('rpc_pet_interact', {
      'p_pet_id': petId,
    }, 'rpc_pet_interact 互动');
    if (err == null) {
      PetActionBudget.noteActionAnchor(petId, 'interact');
      await PetService.instance.invalidateSummary();
    }
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

  /// 抽取/对齐当日任务（幂等，advisory lock 防并发）
  static Future<String?> questsDraw() async {
    final (_, err) = await _call(
        'rpc_pet_daily_quests_draw', {}, 'rpc_pet_daily_quests_draw 任务抽取');
    return err;
  }

  /// 领取任务奖励 → 返回 (奖励?, 服务端错误码)
  ///
  /// 错误码必须带回调用方：只返回可空奖励会让「今日已领 / 任务未完成」等
  /// 服务端语义在页面层退化成一句「领取失败，请稍后重试」。
  static Future<(({int gold, int points})?, String?)> questClaim(
    String questId,
  ) async {
    final (data, err) = await _call('rpc_pet_daily_quests_claim', {
      'p_quest_id': questId,
    }, 'rpc_pet_daily_quests_claim 领取任务奖励');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (
      (
        gold: (data?['gold'] as num?)?.toInt() ?? 0,
        points: (data?['points'] as num?)?.toInt() ?? 0,
      ),
      null,
    );
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

    /// 批量喂养（§6.3 高级食盆解锁）：逐宠分流（免费优先/额度尽口粮/冷却跳过）。
  /// 未解锁返回 PET_BATCH_FEED_LOCKED 错误。成功后失效 summary。
  static Future<(Map<String, dynamic>?, String?)> feedAll() async {
    final (data, err) = await _call('rpc_pet_feed_all', {}, 'rpc_pet_feed_all 批量喂养');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (data, null);
  }

  /// 宠物排序保存（寄养仓库拖拽；服务端 sort_order 落库，summary 按序返回）
  static Future<String?> reorder(List<({String petId, int sortOrder})> orders) async {
    final (_, err) = await _call('rpc_pet_reorder', {
      'p_orders': [
        for (final o in orders) {'pet_id': o.petId, 'sort_order': o.sortOrder},
      ],
    }, 'rpc_pet_reorder 宠物排序');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

    /// 图鉴总览（只读；owned=历史拥有过含已放生，范围=enabled 形态）
  static Future<(PetDexModel?, String?)> fetchDex() async {
    final (data, err) = await _call('rpc_pet_dex', {}, 'rpc_pet_dex 图鉴总览');
    if (err != null) return (null, err);
    return (PetDexModel.fromJson(data ?? const {}), null);
  }

  /// 放生（软删除：status='released'，时间线归档保留；补偿=等级×单价×评级倍率）。
  /// 成功后失效 summary（宠物离场）。
  static Future<(({int gold})?, String?)> release(String petId) async {
    final (data, err) = await _call('rpc_pet_release', {
      'p_pet_id': petId,
    }, 'rpc_pet_release 放生');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    final gold = (data?['gold'] as num?)?.toInt() ?? 0;
    return ((gold: gold), null);
  }

    /// 昵称修改（更名卡口径：每宠首次免费，此后消耗更名卡×1；敏感词在
  /// 调用方预检，服务端做长度/同名校验）。成功后失效 summary（昵称变化）。
  static Future<String?> rename(String petId, String nickname) async {
    final (_, err) = await _call('rpc_pet_rename', {
      'p_pet_id': petId,
      'p_nickname': nickname,
    }, 'rpc_pet_rename 昵称修改');
    if (err == null) await PetService.instance.invalidateSummary();
    return err;
  }

  /// ---------- 宠物签到（宠物模块独享签到体系） ----------

  /// 月度签到状态：奖励表快照（整月，惰性生成后全员统一）+ 已签/补签日期 +
  /// 里程碑（含已领阈值）+ 衪签限额/持卡数。仅公示与预览，不发任何奖励。
  static Future<(PetCheckinStatusModel?, String?)> fetchCheckinStatus(
      int year, int month) async {
    final (data, err) = await _call('rpc_pet_checkin_status', {
      'p_year': year,
      'p_month': month,
    }, 'rpc_pet_checkin_status 月度签到状态');
    if (err != null) return (null, err);
    return (PetCheckinStatusModel.fromJson(data ?? const {}), null);
  }

  /// 签到 / 补签。[makeupDate] 非空且非今日 = 补签：消耗 1 张补签卡并发目标日
  /// 奖励（每自然月上限 4 次，服务端校验）；里程碑达标自动连带发放。
  /// 成功后失效 summary（金币变化）。
  static Future<(PetCheckinSignResultModel?, String?)> checkinSign(
      {DateTime? makeupDate}) async {
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final (data, err) = await _call('rpc_pet_checkin_sign', {
      if (makeupDate != null) 'p_makeup_date': key(makeupDate),
    }, 'rpc_pet_checkin_sign 签到');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (PetCheckinSignResultModel.fromJson(data ?? const {}), null);
  }
}
