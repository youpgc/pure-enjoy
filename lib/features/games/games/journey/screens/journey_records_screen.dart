import 'package:flutter/material.dart';

import '../models/journey_talent_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';

/// 西行履历（三页拆分，hub 独立入口）：功德流水 / 对局记录 / 成就
/// （本地流水，新的在前，上限 50）。共享格式化与来源标签。

/// 功德来源中文标签（未知类型回落「其他」）。
const Map<String, String> _kSourceLabels = <String, String>{
  'run_settle': '对局结算',
  'talent_spend': '天赋点亮',
  'character_unlock': '角色解锁',
  'revive_spend': '还魂复活',
};

/// 时间：yyyy-MM-dd HH:mm（北京墙钟口径，禁止设备时区）。
/// 记录 createdAt 由 journeyBjNow() 落盘（isUtc 标记=BJ 墙钟字段），
/// 直读字段即为北京时间；旧数据为设备 +08 墙钟，直读同样正确。
String _fmtDate(DateTime? t) {
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 时长：mm:ss。
String _fmtDuration(int ms) {
  final total = ms <= 0 ? 0 : ms ~/ 1000;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 来源小标签（面板底 + 鎏金描边，口径同功德胶囊）。
Widget _sourceTag(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: JourneyTheme.panelRaised,
      border: Border.all(color: JourneyTheme.goldDeep),
    ),
    child: Text(label, style: JourneyTheme.faint),
  );
}

// ---- 功德流水页 ----

/// 功德流水页：append-only 流水列表（来源标签 + 增减额 + 余额快照）。
class JourneyMeritRecordsScreen extends StatelessWidget {
  const JourneyMeritRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 订阅进度服务：页面停留期间新流水实时刷新
    return ListenableBuilder(
      listenable: JourneyProgressService.instance,
      builder: (context, _) {
        // 直达记录页时补一次读档：进度服务有加载守卫，完成后通知刷新
        JourneyProgressService.instance.ensureLoaded();
        final records =
            JourneyProgressService.instance.state.meritRecords;
        return JourneyPageScaffold(
          title: '功德流水',
          body: records.isEmpty
              ? const Center(
                  child: Text('暂无功德流水', style: JourneyTheme.faint))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, int index) {
                    final r = records[index];
                    final positive = r.delta >= 0;
                    return JourneyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _sourceTag(
                                  _kSourceLabels[r.sourceType] ?? '其他'),
                              const SizedBox(width: 8),
                              Text(
                                positive ? '+${r.delta}' : '${r.delta}',
                                style: JourneyTheme.title.copyWith(
                                  color: positive
                                      ? JourneyTheme.gold
                                      : JourneyTheme.cinnabar,
                                ),
                              ),
                              const Spacer(),
                              Text('余额 ${r.balanceAfter}',
                                  style: JourneyTheme.caption),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  r.remark,
                                  style: JourneyTheme.faint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(_fmtDate(r.createdAt),
                                  style: JourneyTheme.faint),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ---- 对局记录页 ----

/// 对局记录页：一场对局一条（难别/模式 + 击杀/时长 + 功德入账）。
class JourneyRunRecordsScreen extends StatelessWidget {
  const JourneyRunRecordsScreen({super.key});

  /// 对局记录标题：优先 levelTitle（「第 N 难 · 关卡名称」，battle 结算
  /// 入参拼接）；旧记录为空按 levelNo 兜底；非主线按 kind 映射模式名
  /// （endless=无尽妖潮 / daily=西行游历）。
  String _runTitle(JourneyRunRecordModel r) {
    if (r.levelTitle.isNotEmpty) return r.levelTitle;
    if (r.levelNo > 0) return '第 ${r.levelNo} 难';
    switch (r.kind) {
      case 'endless':
        return '无尽妖潮';
      case 'daily':
        return '西行游历';
      default:
        return '模式对局';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 订阅进度服务：页面停留期间新对局记录实时刷新
    return ListenableBuilder(
      listenable: JourneyProgressService.instance,
      builder: (context, _) {
        // 直达记录页时补一次读档：进度服务有加载守卫，完成后通知刷新
        JourneyProgressService.instance.ensureLoaded();
        final records = JourneyProgressService.instance.state.runRecords;
        return JourneyPageScaffold(
          title: '对局记录',
          body: records.isEmpty
              ? const Center(
                  child: Text('暂无对局记录', style: JourneyTheme.faint))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, int index) {
                    final r = records[index];
                    return JourneyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(_runTitle(r), style: JourneyTheme.body),
                              const SizedBox(width: 8),
                              Text(
                                r.cleared ? '通关 ✓' : '未竟',
                                style: JourneyTheme.caption.copyWith(
                                  color: r.cleared
                                      ? JourneyTheme.gold
                                      : JourneyTheme.textFaint,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '+${r.meritGained}',
                                style: JourneyTheme.title
                                    .copyWith(color: JourneyTheme.gold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Text(
                                '击杀 ${r.kills} · ${_fmtDuration(r.durationMs)}',
                                style: JourneyTheme.caption,
                              ),
                              const Spacer(),
                              Text(_fmtDate(r.createdAt),
                                  style: JourneyTheme.faint),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ---- 成就页 ----

/// 成就页：已解锁点亮金标，未解锁灰显（解锁时间省略口径）。
class JourneyAchievementsScreen extends StatefulWidget {
  const JourneyAchievementsScreen({super.key});

  @override
  State<JourneyAchievementsScreen> createState() =>
      _JourneyAchievementsScreenState();
}

class _JourneyAchievementsScreenState extends State<JourneyAchievementsScreen> {
  /// 成就定义行（节点10）：gameId 拉取 game_achievements（内存缓存）。
  List<JourneyAchievementDef> _achievements = const <JourneyAchievementDef>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载失败标记：异常时由错误态接管，避免永久停在 loading。
  bool _loadFailed = false;

  Future<void> _load() async {
    try {
      await JourneyProgressService.instance.ensureLoaded();
      // 成就定义（节点10）：gameId 未配置/拉取失败展示空态
      await JourneyConfigService.instance
          .ensure(JourneyConfigScope.achievements);
      final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
      final defs = await JourneyProgressSync.fetchAchievements(gameId);
      if (!mounted) return;
      setState(() {
        _achievements = defs;
        _loadFailed = false;
      });
    } catch (e, st) {
      reportJourneyLoadError(e, st);
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  void _retry() {
    setState(() {
      _loadFailed = false;
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return JourneyPageScaffold(
        title: '成就',
        body: JourneyLoadError(onRetry: _retry),
      );
    }
    if (_loading) {
      return const JourneyPageScaffold(
        title: '成就',
        body: Center(child: JourneyLoading(label: '加载中…')),
      );
    }
    final unlocked = JourneyProgressService.instance.state.unlockedAchievements;
    return JourneyPageScaffold(
      title: '成就',
      body: _achievements.isEmpty
          ? const Center(child: Text('暂无成就数据', style: JourneyTheme.faint))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, int index) {
                final a = _achievements[index];
                final lit = unlocked.contains(a.code);
                return JourneyCard(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        lit ? Icons.emoji_events : Icons.emoji_events_outlined,
                        color: lit ? JourneyTheme.gold : JourneyTheme.textFaint,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              a.name.isEmpty ? a.code : a.name,
                              style: JourneyTheme.body.copyWith(
                                color: lit
                                    ? JourneyTheme.textPrimary
                                    : JourneyTheme.textFaint,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.description.isEmpty ? a.code : a.description,
                              style: JourneyTheme.faint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lit ? '已点亮' : '未点亮',
                        style: JourneyTheme.caption.copyWith(
                          color: lit ? JourneyTheme.gold : JourneyTheme.textFaint,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
