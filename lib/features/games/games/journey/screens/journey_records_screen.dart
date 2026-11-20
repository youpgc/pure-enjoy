import 'package:flutter/material.dart';

import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';

/// 西行履历·成就页：已解锁点亮金标，未解锁灰显。

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
      // 进度读档与配置拉取无依赖，并行缩短首屏；二者完成后才需 gameId。
      await Future.wait(<Future<void>>[
        JourneyProgressService.instance.ensureLoaded(),
        JourneyConfigService.instance
            .ensure(JourneyConfigScope.achievements)
            .then((_) {}),
      ]);
      final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
      // 清缓存后本地成就态丢失：统一回拉远端已解锁态并补齐新达成项，
      // 与图鉴页口径一致。
      await JourneyProgressService.instance.refreshAchievementState();
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
