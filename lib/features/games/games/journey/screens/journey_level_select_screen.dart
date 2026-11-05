import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import 'journey_battle_screen.dart';

/// S3 关卡选择页（八十一难）。
///
/// 取经路线按区域分段展示；解锁口径：关卡号 ≤ 最远关卡+1（顺序推进制），
/// 已通关可重复挑战；挑战进入对局。
class JourneyLevelSelectScreen extends StatefulWidget {
  const JourneyLevelSelectScreen({super.key});

  @override
  State<JourneyLevelSelectScreen> createState() =>
      _JourneyLevelSelectScreenState();
}

class _JourneyLevelSelectScreenState extends State<JourneyLevelSelectScreen> {
  JourneyConfigSnapshot? _config;
  JourneyProgressModel _progress = const JourneyProgressModel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = JourneyProgressService.instance;
    await Future.wait<void>(<Future<void>>[
      JourneyConfigService.instance.fetch(),
      progress.ensureLoaded(),
    ]);
    if (!mounted) return;
    setState(() {
      _config = JourneyConfigService.instance.cached;
      _progress = progress.state;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const JourneyPageScaffold(
        title: '八十一难',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    return JourneyPageScaffold(
      title: '八十一难',
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: config.regions.length,
        itemBuilder: (ctx, i) {
          final region = config.regions[i];
          final levels = config.levelsOfRegion(region.code);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _regionColor(region),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(region.name, style: JourneyTheme.title),
                  const SizedBox(width: 8),
                  Text('共 ${levels.length} 难', style: JourneyTheme.faint),
                ],
              ),
              const SizedBox(height: 8),
              ...levels.map(_buildLevelCard),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Color _regionColor(JourneyRegionModel region) {
    final hex = region.themeColor.replaceAll('#', '');
    if (hex.length != 7) return JourneyTheme.gold;
    return Color(int.parse('FF$hex', radix: 16));
  }

  Widget _buildLevelCard(JourneyLevelModel level) {
    final farthest = _progress.farthestLevelNo;
    final cleared = level.levelNo <= farthest;
    final unlocked = level.levelNo <= farthest + 1;
    final kindLabel = switch (level.kind) {
      'story' => '叙事',
      'boss' => '妖王${level.bossFights > 1 ? ' ×${level.bossFights}' : ''}',
      'trial' => '试炼',
      'node' => '节点',
      _ => '战斗',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: JourneyCard(
        locked: !unlocked,
        onTap: unlocked ? () => _challenge(level) : null,
        child: Row(
          children: <Widget>[
            // 关号徽标
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cleared
                    ? JourneyTheme.gold.withValues(alpha: 0.18)
                    : JourneyTheme.panelRaised,
                shape: BoxShape.circle,
                border: Border.all(
                  color: cleared ? JourneyTheme.gold : JourneyTheme.panelStroke,
                ),
              ),
              child: cleared
                  ? const Icon(Icons.check,
                      color: JourneyTheme.gold, size: 20)
                  : Text(
                      '${level.levelNo}',
                      style: JourneyTheme.title.copyWith(
                        color: unlocked
                            ? JourneyTheme.textPrimary
                            : JourneyTheme.textFaint,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(level.title, style: JourneyTheme.title),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? '第 ${level.levelNo} 难 · $kindLabel'
                        : '通关前置难关后解锁',
                    style: unlocked ? JourneyTheme.caption : JourneyTheme.faint,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 挑战按钮留出与卡片内容、卡片边缘的间距
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: unlocked
                  ? JourneyButton(
                      text: cleared ? '重挑战' : '挑战',
                      secondary: cleared,
                      onTap: () => _challenge(level),
                    )
                  : null,
            ),
            if (!unlocked)
              const Icon(Icons.lock, color: JourneyTheme.locked, size: 18),
          ],
        ),
      ),
    );
  }

  void _challenge(JourneyLevelModel level) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyBattleScreen(level: level),
      ),
    );
  }
}
