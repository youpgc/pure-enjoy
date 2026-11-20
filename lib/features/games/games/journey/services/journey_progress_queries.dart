import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../models/journey_talent_models.dart';
import 'journey_time.dart';

/// 西行·账号数据只读查询：分页拉取流水/对局记录与已解锁成就 code。
/// 全部 best-effort：失败返回 null 或空集合，由调用方保留本地兜底。
class JourneyProgressQueries {
  JourneyProgressQueries._();

  /// 远端 created_at（timestamptz，真 UTC）→ 北京墙钟字符串（值=BJ 墙钟、
  /// 后缀 Z），与本地镜像 journeyBjNow().toIso8601String() 同形态；展示层
  /// DateTime.tryParse 直读即得北京时间，避免远端记录显示成 UTC 少 8 小时。
  static Map<String, dynamic> _withBjCreatedAt(Map<String, dynamic> row) {
    final raw = row['created_at'];
    if (raw == null) return row;
    final utc = DateTime.tryParse(raw.toString());
    if (utc == null) return row;
    return <String, dynamic>{
      ...row,
      'created_at': journeyBjFromUtc(utc).toIso8601String(),
    };
  }

  /// 分页拉取功德流水（journey_merit_records，按时间倒序）。
  /// 返回 null 表示请求失败（调用方保留本地兜底）；空列表表示本页无数据。
  static Future<List<JourneyMeritRecordModel>?> fetchMeritRecordsPage(
    String userId, {
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await ApiClient.get(
        'journey_merit_records',
        filters: <String, String>{'user_id': 'eq.$userId'},
        select:
            'id,delta,balance_after,source_type,ref_type,ref_id,remark,created_at',
        // id 作 tie-breaker：同一 created_at 的多条记录用 offset 翻页
        // 仍需稳定次序，否则页边界可能重复/漏项。
        order: 'created_at.desc,id.desc',
        limit: limit,
        offset: offset,
        note: 'journey:merit_records_page',
      );
      if (!result.isSuccess) return null;
      return (result.data ?? const <Map<String, dynamic>>[])
          .map((row) => JourneyMeritRecordModel.fromJson(_withBjCreatedAt(row)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('journey 功德流水分页拉取异常: $e');
      return null;
    }
  }

  /// 分页拉取西行记录（journey_runs，按时间倒序）。
  /// 不显式 select：type/name 为渐进式加列，全列读取兼容 DDL 前后 schema，
  /// model 读 type 回落 kind、读 name 回落 level_title。
  /// 返回 null 表示请求失败；空列表表示本页无数据。
  static Future<List<JourneyRunRecordModel>?> fetchRunRecordsPage(
    String userId, {
    required int limit,
    required int offset,
  }) async {
    try {
      final result = await ApiClient.get(
        'journey_runs',
        filters: <String, String>{'user_id': 'eq.$userId'},
        // id 作 tie-breaker，保证同时间戳记录翻页次序稳定。
        order: 'created_at.desc,id.desc',
        limit: limit,
        offset: offset,
        note: 'journey:run_records_page',
      );
      if (!result.isSuccess) return null;
      return (result.data ?? const <Map<String, dynamic>>[])
          .map((row) => JourneyRunRecordModel.fromJson(_withBjCreatedAt(row)))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('journey 西行记录分页拉取异常: $e');
      return null;
    }
  }

  /// 拉取本游戏已解锁成就 code（远端 user_game_achievements 为真源）。
  /// 先取 game_achievements 的 id↔code 映射，再查本用户解锁行映射回 code；
  /// 失败/未配置返回空集合，由调用方保留本地缓存不覆盖。
  static Future<Set<String>> fetchUnlockedAchievementCodes(
    String gameId,
    String userId,
  ) async {
    if (gameId.isEmpty) return const <String>{};
    try {
      final defs = await ApiClient.get(
        'game_achievements',
        filters: <String, String>{'game_id': 'eq.$gameId', 'enabled': 'eq.true'},
        select: 'id,code',
        limit: 200,
        note: 'journey:achievement_code_map',
      );
      if (!defs.isSuccess) return const <String>{};
      final idToCode = <String, String>{};
      for (final row in defs.data ?? const <Map<String, dynamic>>[]) {
        final id = row['id'] as String?;
        final code = row['code'] as String?;
        if (id != null && code != null && code.isNotEmpty) idToCode[id] = code;
      }
      if (idToCode.isEmpty) return const <String>{};
      final unlocked = await ApiClient.get(
        'user_game_achievements',
        filters: <String, String>{
          'user_id': 'eq.$userId',
          'achievement_id': 'in.(${idToCode.keys.join(',')})',
        },
        select: 'achievement_id',
        limit: 200,
        note: 'journey:unlocked_achievements',
      );
      if (!unlocked.isSuccess) return const <String>{};
      return <String>{
        for (final row in unlocked.data ?? const <Map<String, dynamic>>[])
          if (row['achievement_id'] is String)
            idToCode[row['achievement_id'] as String] ?? '',
      }..remove('');
    } catch (e) {
      if (kDebugMode) debugPrint('journey 已解锁成就回拉异常: $e');
      return const <String>{};
    }
  }
}
