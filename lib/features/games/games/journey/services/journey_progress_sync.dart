import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/supabase_service.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';

/// 西行·进度远端同步助手（全部 best-effort：失败静默/仅调试输出，不抛出）。
///
/// 承载 journey_merit_records / journey_runs 追加写入、journey_progress
/// 行的拉取与 upsert（PATCH 未命中→POST 补插）与西行成就解锁判定，
/// 使 JourneyProgressService 聚焦本地状态机（单文件 ≤500 行拆分）。
class JourneyProgressSync {
  JourneyProgressSync._();

  /// 功德流水上报（journey_merit_records；未登录跳过）。
  static Future<void> syncMeritRecord(JourneyMeritRecordModel r) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final result = await ApiClient.post(
        'journey_merit_records',
        <String, dynamic>{
          'id': r.id,
          'user_id': userId,
          'delta': r.delta,
          'balance_after': r.balanceAfter,
          'source_type': r.sourceType,
          'ref_type': r.refType,
          'ref_id': r.refId,
          'remark': r.remark,
        },
        returnRepresentation: false,
        note: 'journey:merit_record',
      );
      if (!result.isSuccess && kDebugMode) {
        debugPrint('journey 功德流水同步失败: ${result.errorMessage}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('journey 功德流水同步异常: $e');
    }
  }

  /// 对局记录上报（journey_runs；未登录跳过）。
  static Future<void> syncRunRecord(JourneyRunRecordModel r) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    try {
      final result = await ApiClient.post(
        'journey_runs',
        <String, dynamic>{
          'id': r.id,
          'user_id': userId,
          'level_no': r.levelNo,
          'kills': r.kills,
          'merit_gained': r.meritGained,
          'duration_ms': r.durationMs,
          'cleared': r.cleared,
        },
        returnRepresentation: false,
        note: 'journey:run_record',
      );
      if (!result.isSuccess && kDebugMode) {
        debugPrint('journey 对局记录同步失败: ${result.errorMessage}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('journey 对局记录同步异常: $e');
    }
  }

  /// 拉取用户进度行（journey_progress；失败/无行返回 null）。
  static Future<Map<String, dynamic>?> fetchProgressRow(String userId) async {
    try {
      final result = await ApiClient.get(
        'journey_progress',
        filters: <String, String>{'user_id': 'eq.$userId'},
        limit: 1,
        note: 'journey:progress',
      );
      if (!result.isSuccess) return null;
      final rows = result.data ?? const <Map<String, dynamic>>[];
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
      if (kDebugMode) debugPrint('journey 进度拉取异常: $e');
      return null;
    }
  }

  /// 进度行 upsert：ApiClient.post 不支持 upsert 头（Prefer
  /// resolution=merge-duplicates），先 PATCH 过滤更新（PostgREST 未命中
  /// 行返回 404），失败再 POST 补插；失败静默。
  static Future<void> upsertProgressRow(
    String userId,
    Map<String, dynamic> row,
  ) async {
    try {
      final patched = await ApiClient.patchByFilter(
        'journey_progress',
        filters: <String, String>{'user_id': 'eq.$userId'},
        body: row,
        note: 'journey:progress',
      );
      // PostgREST PATCH 零行命中仍返回 200+空数组（非 404）：以命中行数
      // 为准，未命中才 POST 补插——否则首行永远无法创建，上行同步静默失效
      final patchedRows = patched.data ?? const <Map<String, dynamic>>[];
      if (patched.isSuccess && patchedRows.isNotEmpty) return;
      final inserted = await ApiClient.post(
        'journey_progress',
        row,
        returnRepresentation: false,
        note: 'journey:progress',
      );
      if (!inserted.isSuccess && kDebugMode) {
        debugPrint('journey 进度同步失败: ${inserted.errorMessage}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('journey 进度同步异常: $e');
    }
  }

  /// 西行成就解锁判定（game_achievements，game_id 过滤 + enabled）。
  ///
  /// condition.type：level_cleared=远端 value≤最远关 / total_kills=≤累计
  /// 击杀 / merit_earned=≤累计获得功德（本地流水正 delta 求和）/
  /// revived=≤本局还魂次数（[revivedCount]）。满足且未解锁则 best-effort
  /// 写 user_game_achievements，返回本次新解锁 code 列表；单次拉取失败
  /// 静默返回空。
  static Future<List<String>> evaluateAchievements({
    required JourneyProgressModel state,
    required String gameId,
    required String userId,
    int revivedCount = 0,
  }) async {
    if (gameId.isEmpty) return const <String>[];
    try {
      final defs = await ApiClient.get(
        'game_achievements',
        filters: <String, String>{'game_id': 'eq.$gameId', 'enabled': 'eq.true'},
        select: 'id,code,condition',
        limit: 100,
        note: 'journey:achievements',
      );
      if (!defs.isSuccess) return const <String>[];
      final defRows = defs.data ?? const <Map<String, dynamic>>[];
      if (defRows.isEmpty) return const <String>[];
      // 已解锁集合（远端记录；本地缓存 code 由调用方合并）
      final ids = <String>[
        for (final row in defRows)
          if (row['id'] is String) row['id'] as String,
      ];
      final unlockedRes = await ApiClient.get(
        'user_game_achievements',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'achievement_id': 'in.(${ids.join(',')})',
        },
        select: 'achievement_id',
        limit: 100,
        note: 'journey:unlocked_achievements',
      );
      if (!unlockedRes.isSuccess) return const <String>[];
      final unlockedIds = <String>{
        for (final row in unlockedRes.data ?? const <Map<String, dynamic>>[])
          if (row['achievement_id'] is String) row['achievement_id'] as String,
      };
      // 累计获得功德（流水上限 50 条，口径近似，达标值远高于上限）
      final meritEarned = state.meritRecords.fold<int>(
          0, (sum, r) => r.delta > 0 ? sum + r.delta : sum);
      final newly = <String>[];
      for (final row in defRows) {
        final id = row['id'] as String? ?? '';
        final code = row['code'] as String? ?? '';
        final condition = (row['condition'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        final value = (condition['value'] as num?)?.toInt() ?? 0;
        final satisfied = switch (condition['type']?.toString()) {
          'level_cleared' => value <= state.farthestLevelNo,
          'total_kills' => value <= state.totalKills,
          'merit_earned' => value <= meritEarned,
          'revived' => value <= revivedCount,
          _ => false,
        };
        if (!satisfied || id.isEmpty || code.isEmpty) continue;
        if (unlockedIds.contains(id) ||
            state.unlockedAchievements.contains(code)) {
          continue; // 已解锁（远端或本地已记），幂等跳过
        }
        final posted = await ApiClient.post(
          'user_game_achievements',
          <String, dynamic>{'user_id': userId, 'achievement_id': id},
          returnRepresentation: false,
          note: 'journey:achievement_unlock',
        );
        if (posted.isSuccess) newly.add(code);
      }
      return newly;
    } catch (e) {
      if (kDebugMode) debugPrint('journey 成就判定异常: $e');
      return const <String>[];
    }
  }

  /// 西行成就定义行（game_achievements 轻量视图）内存缓存：
  /// 图鉴解锁条件 / 记录页成就 Tab 共用，进程内一次拉取。
  static List<JourneyAchievementDef>? _achievementDefsCache;

  /// 拉取成就定义行（code/name/description/condition；带内存缓存）。
  /// 失败/未配置 gameId 返回空表（展示层回落编码显示）。
  static Future<List<JourneyAchievementDef>> fetchAchievements(
    String gameId,
  ) async {
    if (gameId.isEmpty) return const <JourneyAchievementDef>[];
    final cached = _achievementDefsCache;
    if (cached != null) return cached;
    try {
      final result = await ApiClient.get(
        'game_achievements',
        filters: <String, String>{'game_id': 'eq.$gameId', 'enabled': 'eq.true'},
        select: 'code,name,description,condition',
        limit: 100,
        note: 'journey:achievement_defs',
      );
      if (!result.isSuccess) return const <JourneyAchievementDef>[];
      final rows = result.data ?? const <Map<String, dynamic>>[];
      final defs = <JourneyAchievementDef>[
        for (final row in rows) JourneyAchievementDef.fromJson(row),
      ];
      _achievementDefsCache = defs;
      return defs;
    } catch (e) {
      if (kDebugMode) debugPrint('journey 成就定义拉取异常: $e');
      return const <JourneyAchievementDef>[];
    }
  }
}

/// 西行成就定义行（game_achievements 轻量只读模型）：
/// 图鉴解锁条件展示与记录页成就 Tab 共用。
class JourneyAchievementDef {
  final String code;
  final String name;
  final String description;
  final String conditionType;
  final int conditionValue;

  const JourneyAchievementDef({
    required this.code,
    this.name = '',
    this.description = '',
    this.conditionType = '',
    this.conditionValue = 0,
  });

  factory JourneyAchievementDef.fromJson(Map<String, dynamic> json) {
    final condition = (json['condition'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return JourneyAchievementDef(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      conditionType: condition['type']?.toString() ?? '',
      conditionValue: (condition['value'] as num?)?.toInt() ?? 0,
    );
  }
}
