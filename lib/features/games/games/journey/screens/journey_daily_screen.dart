import 'package:flutter/material.dart';

import '../../../../../utils/cache_helper.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_time.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import 'journey_battle_screen.dart';
import '../widgets/journey_busy.dart';

/// S3-2 每日游历·地图选择页（hub「每日游历」入口直达）。
///
/// 地图列表由后台 journey_daily_maps 配置，用户每日任选其一；进入即计次
/// （写当日 gate，主动放弃同样占次）；远端就绪但列表为空=后台全部禁用，
/// 显示「今日暂无游历」；仅离线兜底快照回落内置种子。
class JourneyDailyScreen extends StatefulWidget {
  const JourneyDailyScreen({super.key});

  @override
  State<JourneyDailyScreen> createState() => _JourneyDailyScreenState();
}

class _JourneyDailyScreenState extends State<JourneyDailyScreen> {
  JourneyConfigSnapshot? _config;

  /// 每日游历 gate：今日（北京日期）已进图则整页置为已游历态。
  bool _dailyPlayed = false;

  /// 启程进行中：连点只写一次当日 gate、只入栈一个对局页。
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载失败标记：异常时由错误态接管，避免永久停在 loading。
  bool _loadFailed = false;

  Future<void> _load() async {
    try {
      await JourneyConfigService.instance.ensure(JourneyConfigScope.daily);
      final gate = await CacheHelper.instance.loadMap('journey_daily_v1');
      if (!mounted) return;
      setState(() {
        _config = JourneyConfigService.instance.cached;
        _dailyPlayed = gate?['date'] == journeyBjDateKey();
        _loadFailed = false;
      });
    } catch (e, st) {
      reportJourneyLoadError(e, st);
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _retry() {
    setState(() => _loadFailed = false);
    _load();
  }

  Color _mapColor(JourneyDailyMapModel m) {
    final hex = m.themeColor.replaceAll('#', '');
    if (hex.length != 7) return JourneyTheme.gold;
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return JourneyPageScaffold(
        title: '西行游历',
        body: JourneyLoadError(onRetry: _retry),
      );
    }
    final config = _config;
    if (config == null) {
      return const JourneyPageScaffold(
        title: '西行游历',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    final maps = config.dailyMapList();
    return JourneyPageScaffold(
      title: '西行游历',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const JourneyPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.map, color: JourneyTheme.gold, size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('今日任选一图', style: JourneyTheme.titleLg),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  '沿途铜钱雨不断，按你节奏随时点「功成」结算入账。',
                  style: JourneyTheme.body,
                ),
                SizedBox(height: 8),
                Text(
                  '· 每日限一次，启程即计次（中途放弃同样占次）\n'
                  '· 结算功德照常入账（不推进主线进度）',
                  style: JourneyTheme.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_dailyPlayed)
            const JourneyPanel(
              child: Text(
                '今日已游历 · 明日再来',
                style: JourneyTheme.body,
              ),
            )
          else if (maps.isEmpty)
            const JourneyPanel(
              child: Text(
                '今日暂无游历地图 · 明日再来',
                style: JourneyTheme.body,
              ),
            )
          else
            for (final m in maps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: JourneyCard(
                  onTap: () => _startDaily(m),
                  child: Row(
                    children: <Widget>[
                      // 地图主题色徽标
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _mapColor(m).withValues(alpha: 0.22),
                          border: Border.all(color: _mapColor(m), width: 1.2),
                        ),
                        child: const Icon(Icons.landscape,
                            color: JourneyTheme.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(m.name, style: JourneyTheme.title),
                            if (m.desc.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(m.desc, style: JourneyTheme.caption),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      JourneyButton(text: '启 程', onTap: () => _startDaily(m)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _startDaily(JourneyDailyMapModel map) async {
    if (_dailyPlayed || _starting || !mounted) return;
    _starting = true;
    try {
      // 进入即计次：先写当日 gate 再进对局（主动放弃同样占次）
      await JourneyBusy.run(
        context,
        () => CacheHelper.instance.saveMap('journey_daily_v1',
            <String, dynamic>{'date': journeyBjDateKey()}),
        label: '准备游历…',
      );
      if (!mounted) return;
      setState(() => _dailyPlayed = true);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JourneyBattleScreen(
            level: JourneyLevelModel(
              levelNo: 0,
              title: '游历·${map.name}',
              regionCode: map.code,
              kind: 'daily',
              bossFights: 0,
              durationTargetSec:
                  map.durationTargetSec > 0 ? map.durationTargetSec : 300,
            ),
          ),
        ),
      );
    } finally {
      _starting = false;
    }
  }
}
