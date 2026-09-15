import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/supabase_service.dart';

/// 累计型成就指标编码（与条件 `{"type":"cumulative","metric":...}` 同一口径）。
///
/// - play：累计游玩局数（每局完成结算 +1，含失败局；放弃局不计）
/// - clear：累计通关次数（通关 +1）
/// - merge：累计合成次数（g2048，当局引擎上报 merges 增量）
/// - clear_blocks：累计消除方块数（消消乐，当局引擎上报 cleared_blocks 增量）
class GameCumulativeMetrics {
  GameCumulativeMetrics._();

  static const String play = 'play';
  static const String clear = 'clear';
  static const String merge = 'merge';
  static const String clearBlocks = 'clear_blocks';

  /// 全部支持指标（判定时取全量，避免逐指标查存储）
  static const List<String> all = <String>[play, clear, merge, clearBlocks];
}

/// 累计型成就计数服务（cumulative 条件判定的数据源）。
///
/// 设计要点：
/// - 终身累计、跨局累加；引擎在结算 values 中携带增量（merges/cleared_blocks），
///   play/clear 由结算流程按局推导，无需引擎改造；
/// - 存储键 `game_cum_<userId>_<gameCode>_<metric>` 天然按用户隔离；
/// - 计数在 reportAndSettle 主流程记录一次（settleGame 失败重试只重跑发放、
///   不重放计数，防重复累加）；
/// - 卸载重装后本地计数从 0 开始：已解锁档位由 claim_key 幂等保护不重发，
///   未解锁档位重新累计即可（可接受的降级，成就一旦解锁终身有效）。
class GameCumulativeService {
  GameCumulativeService._();

  /// 单例
  static final GameCumulativeService instance = GameCumulativeService._();

  static const String _keyPrefix = 'game_cum_';

  /// 内存缓存：key = `<userId>|<gameCode>|<metric>` → 累计值
  final Map<String, int> _cache = <String, int>{};

  /// 记录一局结算的累计增量（在 reportAndSettle 主流程调用，每局至多一次）。
  ///
  /// 未登录不计数（成就发放同样要求登录，口径一致）。
  Future<void> recordSettle({
    required String gameCode,
    required bool cleared,
    required Map<String, num> values,
  }) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    await _migrateLegacyIfNeeded(userId);

    final deltas = <String, int>{
      GameCumulativeMetrics.play: 1,
      if (cleared) GameCumulativeMetrics.clear: 1,
      if (values['merges'] != null)
        GameCumulativeMetrics.merge: values['merges']!.toInt(),
      if (values['cleared_blocks'] != null)
        GameCumulativeMetrics.clearBlocks: values['cleared_blocks']!.toInt(),
    }..removeWhere((_, v) => v == 0);
    if (deltas.isEmpty) return;

    for (final entry in deltas.entries) {
      final total = await _read(userId, gameCode, entry.key) + entry.value;
      await _write(userId, gameCode, entry.key, total);
    }
  }

  /// 读取当前用户在某游戏下的全部累计指标（供结算判定一次取全）。
  Future<Map<String, int>> totalsFor({required String gameCode}) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return const <String, int>{};
    await _migrateLegacyIfNeeded(userId);
    final totals = <String, int>{};
    for (final metric in GameCumulativeMetrics.all) {
      totals[metric] = await _read(userId, gameCode, metric);
    }
    return totals;
  }

  /// 账号切换时清空内存缓存（键含 userId，磁盘数据天然隔离）。
  void resetForAccountSwitch() {
    _cache.clear();
  }

  /// 已完成旧键迁移的新 userId（内存防重；旧键迁后即删，重启重跑天然幂等）
  String? _migratedFor;

  /// 2026-09-14 双 ID 统一的一次性本地键迁移：
  /// 把旧业务 ID（U 前缀）的累计计数并入 auth uuid 键下。
  /// 旧 id 只存在于升级前的持久化会话（SessionManager.legacyBusinessId）；
  /// 升级后重新登录拿不到旧值 → 计数从 0 开始，与「卸载重装」同一降级口径
  /// （已解锁档位由服务端 claim_key 幂等保护，不重发）。
  Future<void> _migrateLegacyIfNeeded(String newUserId) async {
    if (_migratedFor == newUserId) return;
    _migratedFor = newUserId;
    final legacy = AuthService.instance.legacyBusinessId;
    if (legacy == null || legacy == newUserId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldPrefix = '$_keyPrefix${legacy}_';
      final newPrefix = '$_keyPrefix${newUserId}_';
      final legacyKeys =
          prefs.getKeys().where((k) => k.startsWith(oldPrefix)).toList();
      for (final k in legacyKeys) {
        final v = prefs.getInt(k);
        if (v == null) continue;
        final target = '$newPrefix${k.substring(oldPrefix.length)}';
        final existing = prefs.getInt(target) ?? 0;
        // 取 max：保留升级后已产生的新计数，不回退
        if (v > existing) await prefs.setInt(target, v);
        await prefs.remove(k);
      }
      if (legacyKeys.isNotEmpty) {
        _cache.clear();
        debugPrint('[GameCumulativeService] 已迁移 ${legacyKeys.length} 条旧累计'
            '计数（$legacy → $newUserId）');
      }
    } catch (e) {
      debugPrint('[GameCumulativeService] 旧累计计数迁移失败：$e');
    }
  }

  String _cacheKey(String userId, String gameCode, String metric) =>
      '$userId|$gameCode|$metric';

  String _prefKey(String userId, String gameCode, String metric) =>
      '$_keyPrefix${userId}_${gameCode}_$metric';

  Future<int> _read(String userId, String gameCode, String metric) async {
    final ck = _cacheKey(userId, gameCode, metric);
    final cached = _cache[ck];
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_prefKey(userId, gameCode, metric)) ?? 0;
      _cache[ck] = v;
      return v;
    } catch (e) {
      debugPrint('[GameCumulativeService] 读取计数失败：$e');
      return 0;
    }
  }

  Future<void> _write(
    String userId,
    String gameCode,
    String metric,
    int value,
  ) async {
    _cache[_cacheKey(userId, gameCode, metric)] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey(userId, gameCode, metric), value);
    } catch (e) {
      debugPrint('[GameCumulativeService] 写入计数失败：$e');
    }
  }
}
