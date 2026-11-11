import 'package:flutter/foundation.dart';

import '../../../../../services/api_client.dart';
import '../../../../../services/supabase_service.dart';

/// 西行·击杀图鉴数据服务：终局分类型击杀上报（RPC 原子累加，防多端
/// 读改写覆盖）+ 图鉴击杀数据读取。妖怪与妖王共用（monster_code 关联
/// journey_monsters.code，妖王 ai_tier='boss'）；击杀≥1 即解锁图鉴条目。
abstract final class JourneyKillStatsService {
  /// 上报一局分类型击杀（[kills] = monster_code → 次数）。每局终局只报
  /// 一次；失败静默（best-effort，不影响对局结算主链路）。
  static Future<void> report(Map<String, int> kills) async {
    if (kills.isEmpty) return;
    if (AuthService.instance.currentUserId == null) return;
    final result = await ApiClient.rpc(
      'report_journey_kill_stats',
      params: <String, dynamic>{
        'p_kills': <String, dynamic>{
          for (final e in kills.entries) e.key: e.value
        },
      },
      note: 'journey:report_kill_stats',
    );
    if (!result.isSuccess) {
      debugPrint('[JourneyKillStats] 击杀上报失败: ${result.errorMessage}');
    }
  }

  /// 拉取当前用户全量击杀统计（monster_code → 累计击杀数）；
  /// 行级权限由 journey_kill_stats owner 策略限定为本人，失败返回空表。
  static Future<Map<String, int>> fetchKills() async {
    try {
      final result = await ApiClient.get(
        'journey_kill_stats',
        select: 'monster_code,kills',
        note: 'journey:kill_stats',
      );
      if (!result.isSuccess) return const <String, int>{};
      final rows = result.data ?? const <Map<String, dynamic>>[];
      return <String, int>{
        for (final row in rows)
          if (row['monster_code'] is String)
            row['monster_code'] as String: (row['kills'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('journey 击杀统计拉取异常: $e');
      return const <String, int>{};
    }
  }
}
