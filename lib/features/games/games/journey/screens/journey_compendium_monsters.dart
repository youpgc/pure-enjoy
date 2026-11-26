import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../battle/journey_sprites.dart';
import '../models/journey_models.dart';
import '../services/journey_seed.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';

import 'journey_compendium_state.dart';

/// 妖怪图鉴独立页：journey_monsters 远端配置优先，空回落内置种子池；
/// 击杀≥1 解锁（头像彩色+累计击杀数），未解锁灰度剪影。
class JourneyMonsterCompendiumScreen extends StatefulWidget {
  const JourneyMonsterCompendiumScreen({super.key});

  @override
  State<JourneyMonsterCompendiumScreen> createState() =>
      _JourneyMonsterCompendiumScreenState();
}

class _JourneyMonsterCompendiumScreenState
    extends State<JourneyMonsterCompendiumScreen>
    with JourneyCompendiumState<JourneyMonsterCompendiumScreen> {
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return JourneyPageScaffold(
        title: '妖怪图鉴',
        body: JourneyLoadError(onRetry: retry),
      );
    }
    final snapshot = config;
    if (snapshot == null) {
      return const JourneyPageScaffold(
        title: '妖怪图鉴',
        body: Center(child: JourneyLoading(label: '西行中…')),
      );
    }
    final monsters = snapshot.monsters.isNotEmpty
        ? snapshot.monsters
        : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
    final sorted = List<JourneyMonsterModel>.from(monsters)
      ..sort((a, b) =>
          ((killStats[b.code] ?? 0) > 0 ? 1 : 0) -
          ((killStats[a.code] ?? 0) > 0 ? 1 : 0));
    return JourneyPageScaffold(
      title: '妖怪图鉴',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _buildMonsterCard(sorted[i]),
      ),
    );
  }

  Widget _buildMonsterCard(JourneyMonsterModel m) {
    final kills = killStats[m.code] ?? 0;
    final unlocked = kills > 0;
    final isBoss = m.aiTier == 'boss';
    final tierLabel = switch (m.aiTier) {
      'boss' => '妖王',
      'elite' => '精英',
      _ => '普通',
    };
    return JourneyCard(
      qualityColor: isBoss ? JourneyTheme.gold : JourneyTheme.panelStroke,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: JourneyTheme.bgDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: unlocked
                    ? (isBoss ? JourneyTheme.gold : JourneyTheme.panelStroke)
                    : JourneyTheme.locked,
                width: 1.2,
              ),
            ),
            child: unlocked
                ? SvgPicture.asset(
                    JourneySprites.monster(m.code),
                    width: 36,
                    height: 36,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.cruelty_free,
                      color: JourneyTheme.gold,
                      size: 22,
                    ),
                  )
                : Opacity(
                    opacity: 0.28,
                    child: SvgPicture.asset(
                      JourneySprites.monster(m.code),
                      width: 36,
                      height: 36,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.help_outline,
                        color: JourneyTheme.locked,
                        size: 22,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        unlocked ? m.name : '？？？',
                        style: JourneyTheme.title,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isBoss
                              ? JourneyTheme.gold
                              : JourneyTheme.panelStroke,
                        ),
                      ),
                      child: Text(
                        tierLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: isBoss
                              ? JourneyTheme.goldSoft
                              : JourneyTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked ? '累计击杀 $kills' : '击败后解锁',
                  style: unlocked
                      ? JourneyTheme.caption.copyWith(color: JourneyTheme.gold)
                      : JourneyTheme.faint,
                ),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.verified, color: JourneyTheme.gold, size: 18)
          else
            const Icon(Icons.lock, color: JourneyTheme.locked, size: 18),
        ],
      ),
    );
  }
}
