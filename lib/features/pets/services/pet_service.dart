import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../models/pet_models.dart';
import 'pet_cache.dart';

/// 宠物系统服务（单例 + setState 双轨，禁 Riverpod / supabase_flutter）
///
/// 职责（B2 骨架范围）：
/// - [isPetEnabled]：pet_config 总开关查询（轻量 GET，无副作用，供三处入口门控）；
/// - [fetchSummary]：rpc_pet_summary 总览（含惰性初始化 + 离线衰减补算，SWR 缓存）；
/// - [invalidateSummary]：写操作后使总览缓存失效（B4 起各写 RPC 接入）。
///
/// 注意：rpc_pet_summary 首次调用会按 pet_config 配置幂等发放初始包
/// （Gate 确认点⑥：默认进入即发放），属预期行为；门控查询走 pet_config
/// 轻量读取，避免未进入宠物系统的用户被提前初始化。
class PetService {
  static PetService? _instance;
  PetService._();
  static PetService get instance {
    _instance ??= PetService._();
    return _instance!;
  }

  /// 总开关缓存新鲜度：入口门控属低变配置，1 分钟内视为新鲜
  static const Duration _gateTtl = Duration(minutes: 1);

  /// 查询宠物系统总开关（pet_config.pet_enabled，带短缓存）。
  ///
  /// 未登录返回 false（三处入口全部隐藏）；查询失败按关闭处理（兜底不崩溃）。
  Future<bool> isPetEnabled({bool forceRefresh = false}) async {
    if (SupabaseService.instance.currentUserId == null) return false;
    final (data, _) = await gateConfig(forceRefresh: forceRefresh);
    return data?['pet_enabled'] as bool? ?? false;
  }

  /// 门控配置读取（pet_config 三列一次取回，SWR 共享 keyGate 缓存）：
  /// `pet_enabled` 总开关 / `render3d_enabled` 3D 系统开关 / `asset_manifest`
  /// 资源包清单。旧缓存缺新列时返回 map 中无对应键，调用方按缺省兜底。
  ///
  /// 降级路径：若 3D 增量列尚未迁移（asset SQL 未执行），PostgREST 对整条
  /// select 报 42703 → 回退为只查 `pet_enabled`，保证总开关不受增量列缺失
  /// 拖垮（此时 3D 开关按缺省关闭，符合分层开关语义）。
  Future<(Map<String, dynamic>?, bool)> gateConfig({
    bool forceRefresh = false,
    Duration? ttl,
  }) async {
    try {
      return await PetCache.getMap(
        PetCache.keyGate,
        _fetchGateConfig,
        ttl: ttl ?? _gateTtl,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PetService] 门控查询失败: $e');
      return (null, false);
    }
  }

  /// 门控配置拉取器（三列优先，失败降级单列）
  Future<ApiResponse> _fetchGateConfig() async {
    final full = await ApiClient.get(
      'pet_config',
      select: 'pet_enabled,render3d_enabled,asset_manifest',
      limit: 1,
      note: 'pet_config 门控/3D 开关/资源清单查询',
    );
    if (full.isSuccess) return full;
    if (kDebugMode) {
      debugPrint('[PetService] 三列门控查询失败，降级仅查 pet_enabled: '
          '${full.errorMessage}');
    }
    return ApiClient.get(
      'pet_config',
      select: 'pet_enabled',
      limit: 1,
      note: 'pet_config 门控降级查询（仅总开关）',
    );
  }

  /// 3D 渲染系统开关（pet_config.render3d_enabled；未配置按关闭兜底，
  /// 与用户开关、资源包就绪态三者与运算决定 effective_3d）。
  Future<bool> isRender3dSystemEnabled({bool forceRefresh = false}) async {
    if (SupabaseService.instance.currentUserId == null) return false;
    final (data, _) = await gateConfig(forceRefresh: forceRefresh);
    return data?['render3d_enabled'] as bool? ?? false;
  }

  /// 拉取宠物总览（rpc_pet_summary；SWR：缓存秒开 + 静默刷新）。
  ///
  /// 返回 null 表示未登录 / 请求失败 / 功能关闭，调用方按隐藏处理。
  Future<PetSummaryModel?> fetchSummary({bool forceRefresh = false}) async {
    if (SupabaseService.instance.currentUserId == null) return null;
    try {
      final (data, _) = await PetCache.getMap(
        PetCache.keySummary,
        () => ApiClient.rpc('rpc_pet_summary', note: 'rpc_pet_summary 总览'),
        forceRefresh: forceRefresh,
      );
      if (data == null) return null;
      final summary = PetSummaryModel.fromJson(data);
      // 总开关关闭时即便缓存有数据也按隐藏处理（兜底，防旧缓存穿透）
      if (!summary.petEnabled) return null;
      return summary;
    } catch (e) {
      if (kDebugMode) debugPrint('[PetService] 总览拉取失败: $e');
      return null;
    }
  }

  /// 使总览缓存失效（喂养/购买/丢弃等写操作成功后调用，B4 起接入）
  Future<void> invalidateSummary() => PetCache.invalidate(PetCache.keySummary);
}
