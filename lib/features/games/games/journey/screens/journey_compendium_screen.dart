import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../battle/journey_sprites.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_kill_stats_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../services/journey_seed.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_busy.dart';

import 'journey_compendium_widgets.dart';

/// 图鉴页（节点9 解锁链路 + 妖怪击杀图鉴）：法宝=功德+达成条件混合解锁
/// 口径的展示层；妖怪=分类型击杀累计（击杀≥1 解锁，展示累计击杀数）。
///
/// 法宝图鉴=入池资格：未解锁法宝局内三选一不出现；达成条件对应
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

  /// 分类型击杀累计（monster_code → 次数）：妖怪页签解锁与计数展示。
  Map<String, int> _killStats = const <String, int>{};
  String _tab = 'active';
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载失败标记：异常时由错误态接管，避免永久停在 loading。
  bool _loadFailed = false;

  Future<void> _load() async {
    try {
      await JourneyConfigService.instance.ensure(JourneyConfigScope.compendium);
      final progress = JourneyProgressService.instance;
      await progress.ensureLoaded();
      // 成就判定刷新（best-effort）+ 定义行拉取（解锁条件名/描述展示用）
      await progress.evaluateAchievements();
      final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
      final defs = await JourneyProgressSync.fetchAchievements(gameId);
      // 击杀图鉴数据（失败/未登录回落空表=全未解锁）
      final kills = await JourneyKillStatsService.fetchKills();
      _refreshProgress();
      if (!mounted) return;
      setState(() {
        _config = JourneyConfigService.instance.cached;
        _achievements = defs;
        _killStats = kills;
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
      // 二次确认：功德消耗解锁前核对价与余额，避免误触（与角色解锁口径一致）
      final cost = _config?.relicOf(w.code)?.meritCost ?? 0;
      final balance = JourneyProgressService.instance.state.meritBalance;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: JourneyTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
            side: const BorderSide(color: JourneyTheme.panelStroke),
          ),
          title: const Text('解锁法宝？', style: JourneyTheme.title),
          content: Text(
            '将消耗 $cost 功德解锁「${w.name}」。\n'
            '当前功德余额 $balance，确认后即时扣除。',
            style: JourneyTheme.body,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('再想想', style: JourneyTheme.body),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '确认解锁',
                style: JourneyTheme.body.copyWith(color: JourneyTheme.gold),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
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
    if (_loadFailed) {
      return JourneyPageScaffold(
        title: '法宝图鉴',
        body: JourneyLoadError(onRetry: _retry),
      );
    }
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
      'monster': '妖怪',
    };
    final list = config.weapons.where((w) => w.category == _tab).toList()
      ..sort((a, b) =>
          (_isWeaponUnlocked(b) ? 1 : 0) - (_isWeaponUnlocked(a) ? 1 : 0));
    return JourneyPageScaffold(
      title: '图鉴',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: tabs.entries
                  .map((e) => JourneyCompendiumTabChip(
                        label: e.value,
                        selected: _tab == e.key,
                        onTap: () => setState(() => _tab = e.key),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: _tab == 'monster'
                ? _buildMonsterList()
                : ListView.separated(
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

  /// 妖怪图鉴列表：journey_monsters 远端配置优先，空回落内置种子池；
  /// 击杀≥1 解锁（头像彩色+累计击杀数），未解锁灰度剪影。
  Widget _buildMonsterList() {
    final config = _config;
    final monsters = (config != null && config.monsters.isNotEmpty)
        ? config.monsters
        : kJourneyMonsterSeed.map(JourneyMonsterModel.fromJson).toList();
    // 已解锁（累计击杀≥1）优先排在前面，未解锁次之（原配置序为次级序）
    final sorted = List<JourneyMonsterModel>.from(monsters)
      ..sort((a, b) =>
          ((_killStats[b.code] ?? 0) > 0 ? 1 : 0) -
          ((_killStats[a.code] ?? 0) > 0 ? 1 : 0));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildMonsterCard(sorted[i]),
    );
  }

  Widget _buildMonsterCard(JourneyMonsterModel m) {
    final kills = _killStats[m.code] ?? 0;
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
                    // 未解锁弱化剪影：保留轮廓、压暗细节
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

  Widget _buildWeaponCard(JourneyWeaponModel w) {
    final qualityIdx = w.isActive ? 3 : (w.isPassive ? 2 : 1);
    final quality = JourneyTheme.qualityColors[qualityIdx.clamp(0, 3)];
    // 解锁口径（节点9）：无 relic 配置=默认已解锁；有配置看进度。
    // 角色绑定法宝（character_code 非空）额外门控：归属角色未解锁则锁定，
    // 主动法宝跟随角色一起解锁（角色解锁时自动入池）。唐僧为初始角色
    // （isCharacterUnlocked 内 code=='tang' 特判，集合中无记录），绑定
    // 法宝须走同一口径，否则初始禅杖误显示为未解锁。
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state
            .characterUnlocked(boundChar);
    final relic = _config?.relicOf(w.code);
    final noAchievement = relic != null && relic.achievementCode.isEmpty;
    final unlocked = _isWeaponUnlocked(w);
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
              JourneySprites.weapon(w.code),
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
                      const JourneyPoolBadge(),
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
                        : JourneyTheme.faint.copyWith(color: JourneyTheme.gold),
                  ),
                ],
                // 出处（非取经角色法宝来源，如 哪吒/太上老君；纯展示）
                if (boundChar.isEmpty && w.ownerName.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '出处：${w.ownerName}',
                    style:
                        JourneyTheme.faint.copyWith(color: JourneyTheme.gold),
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

  /// 法宝是否已入池（解锁口径同 _buildWeaponCard：角色绑定未解锁→锁定，
  /// 有 relic 配置看进度，无配置默认已解锁）。用于列表"已解锁优先"排序。
  bool _isWeaponUnlocked(JourneyWeaponModel w) {
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state.characterUnlocked(boundChar);
    final relic = _config?.relicOf(w.code);
    return !charLocked && (relic == null || _unlockedWeapons.contains(w.code));
  }

  /// 角色名（绑定归属展示用；未配置时回落编码）。
  String _charName(String code) {
    for (final c in _config?.characters ?? const <JourneyCharacterModel>[]) {
      if (c.code == code) return c.name;
    }
    return code;
  }
}
