import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';

/// S4 取经队伍（角色选择/图鉴）。
///
/// 初始=唐僧；其余按通关关卡进度+功德定价解锁；点选角色切换出战。
class JourneyCharacterScreen extends StatefulWidget {
  const JourneyCharacterScreen({super.key});

  @override
  State<JourneyCharacterScreen> createState() => _JourneyCharacterScreenState();
}

class _JourneyCharacterScreenState extends State<JourneyCharacterScreen> {
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
        title: '取经队伍',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    return JourneyPageScaffold(
      title: '取经队伍',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: config.characters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final c = config.characters[i];
          return _buildCharacterCard(c);
        },
      ),
    );
  }

  Widget _buildCharacterCard(JourneyCharacterModel c) {
    final progress = JourneyProgressService.instance;
    final unlocked = _progress.characterUnlocked(c.code);
    final selected = progress.selectedCharacterCode == c.code;
    final progressMet = _progress.farthestLevelNo >= c.unlockLevelNo;
    final meritMet = _progress.meritBalance >= c.unlockMeritCost;
    final canUnlock = !unlocked && progressMet && meritMet;

    return JourneyCard(
      locked: !unlocked,
      onTap: unlocked
          ? () async {
              // 走服务层：持久化出战选择（直接写字段会在重启后丢失）
              await progress.selectCharacter(c.code);
              if (mounted) setState(() {});
            }
          : (canUnlock ? () => _unlock(c) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 立绘占位徽章
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? JourneyTheme.gold.withValues(alpha: 0.2)
                  : JourneyTheme.panelRaised,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? JourneyTheme.gold : JourneyTheme.panelStroke,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Text(
              c.name.characters.first,
              style: JourneyTheme.titleLg.copyWith(
                color: unlocked
                    ? JourneyTheme.goldSoft
                    : JourneyTheme.textFaint,
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
                    Text(c.name, style: JourneyTheme.title),
                    const SizedBox(width: 8),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: JourneyTheme.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('出战',
                            style: TextStyle(
                                fontSize: 10,
                                color: JourneyTheme.goldSoft)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('光环「${c.auraName}」· ${c.auraDesc}',
                    style: JourneyTheme.caption),
                const SizedBox(height: 4),
                Text('初始血量 ${c.baseHp} · 专属法宝 ${_weaponName(c.weaponCode)}',
                    style: JourneyTheme.faint),
              ],
            ),
          ),
          _buildTail(c, unlocked, progressMet, meritMet),
        ],
      ),
    );
  }

  Widget _buildTail(
    JourneyCharacterModel c,
    bool unlocked,
    bool progressMet,
    bool meritMet,
  ) {
    if (unlocked) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Icon(Icons.lock, color: JourneyTheme.locked, size: 16),
        const SizedBox(height: 4),
        Text(
          progressMet
              ? '功德 ${c.unlockMeritCost}'
              : '通关第 ${c.unlockLevelNo} 难',
          style: JourneyTheme.faint,
        ),
        if (progressMet && !meritMet)
          Text('功德不足', style: JourneyTheme.faint.copyWith(
              color: JourneyTheme.danger)),
      ],
    );
  }

  String _weaponName(String code) {
    final w = _config?.weaponOf(code);
    return w?.name ?? code;
  }

  Future<void> _unlock(JourneyCharacterModel c) async {
    final progress = JourneyProgressService.instance;
    final ok =
        await progress.unlockCharacter(c.code, meritCost: c.unlockMeritCost);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${c.name} 已加入取经队伍' : '功德不足，无法请 ${c.name} 上路'),
        backgroundColor: ok ? null : JourneyTheme.danger,
      ),
    );
  }
}
