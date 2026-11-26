import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/supabase_service.dart';
import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import 'journey_progress_queries.dart';

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

  /// 西行记录上报（journey_runs；未登录跳过）。
  /// type/name 为渐进式加列：DDL 未执行时整行写入报未知列，逐个剔除后
  /// 重试，保证基础对局记录不被可选字段拖垮。
  static const List<String> _optionalRunColumns = <String>['type', 'name'];

  static Future<void> syncRunRecord(JourneyRunRecordModel r) async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) return;
    final body = <String, dynamic>{
      'id': r.id,
      'user_id': userId,
      'level_no': r.levelNo,
      'kills': r.kills,
      'merit_gained': r.meritGained,
      'duration_ms': r.durationMs,
      'cleared': r.cleared,
      // type 为模式真源（后续新增模式沿用该字段）；name 按 type 带名称。
      'type': r.kind,
      'name': r.levelTitle,
      if (r.runDetail != null) 'run_detail': r.runDetail,
    };
    try {
      if (await _postRunOnce(body)) return;
      final bare = Map<String, dynamic>.from(body);
      for (final column in _optionalRunColumns) {
        if (!bare.containsKey(column)) continue;
        bare.remove(column);
        if (await _postRunOnce(bare)) return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('journey 西行记录同步异常: $e');
    }
  }

  /// 单次西行记录写入；返回是否成功（失败仅调试输出）。
  static Future<bool> _postRunOnce(Map<String, dynamic> body) async {
    final result = await ApiClient.post(
      'journey_runs',
      body,
      returnRepresentation: false,
      note: 'journey:run_record',
    );
    if (!result.isSuccess && kDebugMode) {
      debugPrint('journey 西行记录同步失败: ${result.errorMessage}');
    }
    return result.isSuccess;
  }

  /// 分页拉取功德流水（journey_merit_records，按时间倒序）。
  static Future<List<JourneyMeritRecordModel>?> fetchMeritRecordsPage(
    String userId, {
    required int limit,
    required int offset,
  }) =>
      JourneyProgressQueries.fetchMeritRecordsPage(
        userId,
        limit: limit,
        offset: offset,
      );

  /// 指定妖王击杀数（journey_kill_stats.kills）：boss_killed 解锁条件真源。
  /// 失败/无行返回 0（条件不满足，不误发放解锁）。
  static Future<int> fetchBossKills(String userId, String monsterCode) async {
    if (userId.isEmpty || monsterCode.isEmpty) return 0;
    try {
      final result = await ApiClient.get(
        'journey_kill_stats',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'monster_code': 'eq.$monsterCode',
        },
        select: 'kills',
        limit: 1,
        note: 'journey:boss_kills',
      );
      if (!result.isSuccess) return 0;
      final rows = result.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) return 0;
      return (rows.first['kills'] as num?)?.toInt() ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('journey 妖王击杀数拉取异常: $e');
      return 0;
    }
  }

  /// 分页拉取西行记录（journey_runs，按时间倒序）。
  static Future<List<JourneyRunRecordModel>?> fetchRunRecordsPage(
    String userId, {
    required int limit,
    required int offset,
  }) =>
      JourneyProgressQueries.fetchRunRecordsPage(
        userId,
        limit: limit,
        offset: offset,
      );

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
  /// 渐进式加列的可选字段：DDL 未执行时整行 upsert 会报未知列，
  /// 逐个剔除后重试，保证功德/天赋等主进度不被可选字段拖垮。
  static const List<String> _optionalProgressColumns = <String>[
    'last_daily_date',
    'total_merit_earned',
    'unlocked_entries',
  ];

  static Future<void> upsertProgressRow(
    String userId,
    Map<String, dynamic> row,
  ) async {
    try {
      if (await _upsertOnce(userId, row)) return;
      final bare = Map<String, dynamic>.from(row);
      for (final column in _optionalProgressColumns) {
        if (!bare.containsKey(column)) continue;
        bare.remove(column);
        if (await _upsertOnce(userId, bare)) return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('journey 进度同步异常: $e');
    }
  }

  /// 单次进度行 upsert（PATCH 过滤更新，未命中再 POST 补插）；返回是否成功。
  static Future<bool> _upsertOnce(
    String userId,
    Map<String, dynamic> row,
  ) async {
    final patched = await ApiClient.patchByFilter(
      'journey_progress',
      filters: <String, String>{'user_id': 'eq.$userId'},
      body: row,
      note: 'journey:progress',
    );
    // PostgREST PATCH 零行命中仍返回 200+空数组（非 404）：以命中行数
    // 为准，未命中才 POST 补插——否则首行永远无法创建，上行同步静默失效
    final patchedRows = patched.data ?? const <Map<String, dynamic>>[];
    if (patched.isSuccess && patchedRows.isNotEmpty) return true;
    final inserted = await ApiClient.post(
      'journey_progress',
      row,
      returnRepresentation: false,
      note: 'journey:progress',
    );
    if (!inserted.isSuccess && kDebugMode) {
      debugPrint('journey 进度同步失败: ${inserted.errorMessage}');
    }
    return inserted.isSuccess;
  }

  /// 西行成就解锁判定（game_achievements，game_id 过滤 + enabled）。
  ///
  /// condition.type：level_cleared=远端 value≤最远关 / total_kills=≤累计
  /// 击杀 / merit_earned=≤累计获得功德（进度行 total_merit_earned 真源）/
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
        // 与 fetchUnlockedAchievementCodes 的成就上限同口径（200）。
        limit: 200,
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
        limit: 200,
        note: 'journey:unlocked_achievements',
      );
      if (!unlockedRes.isSuccess) return const <String>[];
      final unlockedIds = <String>{
        for (final row in unlockedRes.data ?? const <Map<String, dynamic>>[])
          if (row['achievement_id'] is String) row['achievement_id'] as String,
      };
      // 累计获得功德：进度行累计列（服务端真源，清缓存/分页不影响）
      final meritEarned = state.totalMeritEarned;
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

  /// 拉取本游戏已解锁成就 code（远端 user_game_achievements 为真源）。
  static Future<Set<String>> fetchUnlockedAchievementCodes(
    String gameId,
    String userId,
  ) =>
      JourneyProgressQueries.fetchUnlockedAchievementCodes(gameId, userId);

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
        limit: 200,
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
