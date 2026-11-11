import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_busy.dart';

/// S6 法宝图鉴页（节点9 解锁链路）：功德+达成条件混合解锁口径的展示层。
///
/// 图鉴=入池资格：未解锁法宝局内三选一不出现；达成条件对应
/// game_achievements 对局成就（随 SQL 种子生效）。有 relic 配置的法宝
/// 未解锁时展示解锁条件+功德价+「解锁」按钮；无配置法宝默认已解锁。
class JourneyCompendiumScreen extends StatefulWidget {
  const JourneyCompendiumScreen({super.key});

  @override
  State<JourneyCompendiumScreen> createState() =>
      _JourneyCompendiumScreenState();
}

class _JourneyCompendiumScreenState extends State<JourneyCompendiumScreen> {
  JourneyConfigSnapshot? _config;
  Set<String> _unlockedWeapons = const <String>{};
  Set<String> _unlockedAchievements = const <String>{};
  List<JourneyAchievementDef> _achievements = const <JourneyAchievementDef>[];
  String _tab = 'active';
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await JourneyConfigService.instance.fetch();
    final progress = JourneyProgressService.instance;
    await progress.ensureLoaded();
    // 成就判定刷新（best-effort）+ 定义行拉取（解锁条件名/描述展示用）
    await progress.evaluateAchievements();
    final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
    final defs = await JourneyProgressSync.fetchAchievements(gameId);
    _refreshProgress();
    if (!mounted) return;
    setState(() {
      _config = JourneyConfigService.instance.cached;
      _achievements = defs;
    });
  }

  void _refreshProgress() {
    final state = JourneyProgressService.instance.state;
    _unlockedWeapons = state.unlockedWeapons;
    _unlockedAchievements = state.unlockedAchievements;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 解锁（节点9）：先 evaluateAchievements 刷新达成状态，达成且功德够
  /// → unlockWeaponWithMerit → 刷新进度；未达成/功德不足均提示。
  Future<void> _unlock(JourneyWeaponModel w) async {
    if (_unlocking) return;
    _unlocking = true;
    try {
      await JourneyBusy.run(context, () => _unlockFlow(w), label: '解锁中…');
    } finally {
      _unlocking = false;
    }
  }

  Future<void> _unlockFlow(JourneyWeaponModel w) async {
    final progress = JourneyProgressService.instance;
    await progress.evaluateAchievements();
    _refreshProgress();
    final relic = _config?.relicOf(w.code);
    // 无成就配置（achievement_code 空）= 纯功德直购，跳过成就判定
    final achieved = relic == null ||
        relic.achievementCode.isEmpty ||
        _unlockedAchievements.contains(relic.achievementCode);
    if (!achieved) {
      _toast('成就未达成，暂无法解锁');
      return;
    }
    final ok = await progress.unlockWeaponWithMerit(w.code);
    _refreshProgress();
    _toast(ok ? '「${w.name}」已入池' : '功德不足，暂无法解锁');
    if (ok && mounted) setState(() {});
  }

  String _achievementName(String code) {
    for (final a in _achievements) {
      if (a.code == code && a.name.isNotEmpty) return a.name;
    }
    return code;
  }

  bool _achievementDone(String code) => _unlockedAchievements.contains(code);

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
    final list = config.weapons.where((w) => w.category == _tab).toList();
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
    // 解锁口径（节点9）：无 relic 配置=默认已解锁；有配置看进度。
    // 角色绑定法宝（character_code 非空）额外门控：归属角色未解锁则锁定，
    // 主动法宝跟随角色一起解锁（角色解锁时自动入池）。
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state.unlockedCharacters
            .contains(boundChar);
    final relic = _config?.relicOf(w.code);
    final noAchievement = relic != null && relic.achievementCode.isEmpty;
    final unlocked =
        !charLocked && (relic == null || _unlockedWeapons.contains(w.code));
    final done = relic == null ||
        noAchievement ||
        _achievementDone(relic.achievementCode);
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
                Row(
                  children: <Widget>[
                    Flexible(child: Text(w.name, style: JourneyTheme.title)),
                    if (unlocked) ...<Widget>[
                      const SizedBox(width: 6),
                      _poolBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(w.desc, style: JourneyTheme.caption),
                if (boundChar.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    charLocked
                        ? '随角色「${_charName(boundChar)}」解锁'
                        : '归属角色：${_charName(boundChar)}',
                    style: charLocked
                        ? JourneyTheme.faint
                        : JourneyTheme.faint.copyWith(
                            color: JourneyTheme.gold),
                  ),
                ],
                // 出处（非取经角色法宝来源，如 哪吒/太上老君；纯展示）
                if (boundChar.isEmpty && w.ownerName.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '出处：${w.ownerName}',
                    style: JourneyTheme.faint.copyWith(
                        color: JourneyTheme.gold),
                  ),
                ],
                if (!unlocked) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    // 角色绑定的法宝未达角色门槛时先提示随角色解锁；
                    // 无成就配置=纯功德直购，否则展示成就条件+功德价
                    charLocked
                        ? '先解锁角色「${_charName(boundChar)}」'
                        : noAchievement
                            ? '功德 ${relic.meritCost} 解锁'
                            : '解锁条件：${_achievementName(relic!.achievementCode)}'
                                ' · ${relic.meritCost} 功德',
                    style: JourneyTheme.faint,
                  ),
                ],
              ],
            ),
          ),
          if (!unlocked && !charLocked)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                JourneyButton(
                  text: noAchievement ? '功德解锁' : '解锁',
                  enabled: done && !_unlocking,
                  onTap: () => _unlock(w),
                ),
                if (!done)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('成就未达成', style: JourneyTheme.faint),
                  ),
              ],
            ),
          if (charLocked)
            const Icon(Icons.lock, color: JourneyTheme.locked, size: 18),
        ],
      ),
    );
  }

  /// 角色名（绑定归属展示用；未配置时回落编码）。
  String _charName(String code) {
    for (final c in _config?.characters ?? const <JourneyCharacterModel>[]) {
      if (c.code == code) return c.name;
    }
    return code;
  }

  /// 已入池角标（已解锁/无 relic 配置法宝）。
  Widget _poolBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JourneyTheme.gold, width: 1),
      ),
      child: const Text(
        '已入池',
        style: TextStyle(fontSize: 10, color: JourneyTheme.goldSoft),
      ),
    );
  }
}
