import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';

/// S6 法宝图鉴页（功德+达成条件混合解锁口径的展示层）。
///
/// 图鉴=入池资格：未解锁法宝局内三选一不出现；达成条件对应
/// game_achievements 对局成就（随 SQL 种子生效）。
class JourneyCompendiumScreen extends StatefulWidget {
  const JourneyCompendiumScreen({super.key});

  @override
  State<JourneyCompendiumScreen> createState() =>
      _JourneyCompendiumScreenState();
}

class _JourneyCompendiumScreenState extends State<JourneyCompendiumScreen> {
  JourneyConfigSnapshot? _config;
  String _tab = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await JourneyConfigService.instance.fetch();
    if (!mounted) return;
    setState(() {
      _config = JourneyConfigService.instance.cached;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const JourneyPageScaffold(
        title: '法宝图鉴',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    final tabs = <String, String>{
      'active': '主动法宝',
      'passive': '被动加持',
      'effect': '特效触发',
    };
    final list =
        config.weapons.where((w) => w.category == _tab).toList();
    return JourneyPageScaffold(
      title: '法宝图鉴',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: tabs.entries
                  .map((e) => _tabChip(e.key, e.value))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _buildWeaponCard(list[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final selected = _tab == key;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => setState(() => _tab = key),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? JourneyTheme.gold.withValues(alpha: 0.18)
                  : JourneyTheme.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? JourneyTheme.gold : JourneyTheme.panelStroke,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? JourneyTheme.goldSoft
                    : JourneyTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeaponCard(JourneyWeaponModel w) {
    final qualityIdx = w.isActive ? 3 : (w.isPassive ? 2 : 1);
    final quality =
        JourneyTheme.qualityColors[qualityIdx.clamp(0, 3)];
    return JourneyCard(
      qualityColor: quality,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: quality.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: quality, width: 1.2),
            ),
            child: SvgPicture.asset(
              'assets/games/journey/weapon_${w.code}.svg',
              width: 36,
              height: 36,
              errorBuilder: (_, __, ___) => Icon(
                switch (w.category) {
                  'active' => Icons.flash_on,
                  'passive' => Icons.shield,
                  _ => Icons.bolt,
                },
                color: quality,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(w.name, style: JourneyTheme.title),
                const SizedBox(height: 2),
                Text(w.desc, style: JourneyTheme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
