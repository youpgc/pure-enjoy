import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../models/journey_unlock_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_kill_stats_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_progress_sync.dart';
import '../services/journey_seed.dart';
import '../widgets/journey_busy.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_theme.dart';

/// 各独立图鉴页共享的配置加载、进度刷新与解锁逻辑。
/// 页面只维护自身列表与卡片渲染，解锁口径集中在此避免多处分叉。
mixin JourneyCompendiumState<T extends StatefulWidget> on State<T> {
  JourneyConfigSnapshot? config;
  Set<String> unlockedWeapons = const <String>{};
  Set<String> unlockedAchievements = const <String>{};
  List<JourneyAchievementDef> achievements = const <JourneyAchievementDef>[];
  Map<String, int> killStats = const <String, int>{};
  bool loadFailed = false;
  bool unlocking = false;
  String? unlockFailureReason;

  Future<void> load() async {
    try {
      await JourneyConfigService.instance.ensure(JourneyConfigScope.compendium);
      final progress = JourneyProgressService.instance;
      await progress.ensureLoaded();
      // 先恢复远端已解锁态，再判定新达成的成就（失败不阻塞图鉴展示）。
      await progress.refreshAchievementState();
      final gameId = JourneyConfigService.instance.cached?.gameId ?? '';
      final defs = await JourneyProgressSync.fetchAchievements(gameId);
      final kills = await JourneyKillStatsService.fetchKills();
      refreshProgress();
      if (!mounted) return;
      setState(() {
        config = JourneyConfigService.instance.cached;
        achievements = defs;
        killStats = kills;
        loadFailed = false;
      });
    } catch (e, st) {
      reportJourneyLoadError(e, st);
      if (mounted) setState(() => loadFailed = true);
    }
  }

  void retry() {
    setState(() => loadFailed = false);
    load();
  }

  void refreshProgress() {
    final state = JourneyProgressService.instance.state;
    unlockedWeapons = state.unlockedWeapons;
    unlockedAchievements = state.unlockedAchievements;
  }

  void toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  JourneyUnlockEntryModel? unlockEntryOf(String code) =>
      config?.unlockEntryForWeapon(code);

  /// 确认弹窗展示价与服务端扣费同源：统一规则优先，旧图鉴价兜底。
  int unlockCostOf(String code) =>
      unlockEntryOf(code)?.meritCost ?? config?.relicOf(code)?.meritCost ?? 0;

  /// 图鉴展示用条件判定：与扣费服务共用模型层判定，妖王击杀读已加载统计。
  bool unlockConditionMet(JourneyUnlockEntryModel entry) {
    final state = JourneyProgressService.instance.state;
    return journeyUnlockConditionMet(
      entry,
      JourneyUnlockConditionContext(
        farthestLevelNo: state.farthestLevelNo,
        totalKills: state.totalKills,
        totalMeritEarned: state.totalMeritEarned,
        unlockedAchievements: state.unlockedAchievements,
        bossKills: killStats,
      ),
    );
  }

  bool achievementDone(String code) => unlockedAchievements.contains(code);

  String achievementName(String code) {
    for (final a in achievements) {
      if (a.code == code && a.name.isNotEmpty) return a.name;
    }
    return code;
  }

  String charName(String code) {
    for (final c in config?.characters ?? const <JourneyCharacterModel>[]) {
      if (c.code == code) return c.name;
    }
    return code;
  }

  /// 妖王编码转中文名：远端怪物表优先，内置种子兜底。
  String bossName(String code) {
    for (final m in config?.monsters ?? const <JourneyMonsterModel>[]) {
      if (m.code == code && m.name.isNotEmpty) return m.name;
    }
    for (final row in kJourneyMonsterSeed) {
      if (row['code'] == code) return row['name'] as String? ?? code;
    }
    return code;
  }

  String conditionLabel(JourneyUnlockEntryModel entry) =>
      switch (entry.conditionType) {
        'none' => '无前置条件',
        'level_cleared' => '通关第 ${entry.conditionValue} 难',
        'achievement' => '达成「${achievementName(entry.conditionValue)}」',
        'total_kills' => '累计击杀 ${entry.conditionValue}',
        'merit_earned' => '累计功德 ${entry.conditionValue}',
        'revived' => '完成首次还魂',
        'boss_killed' => '伏诛 ${bossName(entry.conditionValue)}',
        _ => '待达成',
      };

  /// 二次确认 + 扣费的通用解锁流程，法宝与维度槽共用同一入口。
  Future<void> requestUnlock({
    required String subject,
    required String name,
    required int cost,
    required Future<bool> Function() action,
    required String successMessage,
  }) async {
    if (unlocking) return;
    unlocking = true;
    try {
      final balance = JourneyProgressService.instance.state.meritBalance;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: JourneyTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
            side: const BorderSide(color: JourneyTheme.panelStroke),
          ),
          title: Text('解锁$subject？', style: JourneyTheme.title),
          content: Text(
            '将消耗 $cost 功德解锁「$name」。\n'
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
      if (confirmed != true || !mounted) return;
      unlockFailureReason = null;
      await JourneyBusy.run(
        context,
        () async {
          final ok = await action();
          refreshProgress();
          toast(ok
              ? successMessage
              : unlockFailureReason ?? '条件未达成或功德不足，暂无法解锁');
          if (ok && mounted) setState(() {});
        },
        label: '解锁中…',
      );
    } finally {
      unlocking = false;
    }
  }

  /// 法宝解锁：统一规则与旧 relic 共用判定，无规则仅做成就预检。
  Future<bool> unlockWeapon(JourneyWeaponModel w) async {
    final progress = JourneyProgressService.instance;
    await progress.evaluateAchievements();
    refreshProgress();
    final entry = unlockEntryOf(w.code);
    final achieved = entry != null
        ? unlockConditionMet(entry)
        : (() {
            final relic = config?.relicOf(w.code);
            return relic == null ||
                relic.achievementCode.isEmpty ||
                achievementDone(relic.achievementCode);
          })();
    if (!achieved) {
      unlockFailureReason = '前置条件未达成，暂无法解锁';
      return false;
    }
    return progress.unlockWeaponWithMerit(w.code);
  }

  /// 维度槽解锁：条件与扣费全走统一规则服务。
  Future<bool> unlockSlot(String code) async {
    final progress = JourneyProgressService.instance;
    await progress.evaluateAchievements();
    refreshProgress();
    return progress.unlockTarget('slot', code);
  }

  /// 法宝是否已入池：角色绑定未解锁则锁定；有规则按规则，无规则走旧口径。
  bool isWeaponUnlocked(JourneyWeaponModel w) {
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state.characterUnlocked(boundChar);
    if (charLocked) return false;
    final entry = unlockEntryOf(w.code);
    if (entry != null) {
      return JourneyProgressService.instance
          .isUnlockGranted(entry.targetKind, w.code);
    }
    final relic = config?.relicOf(w.code);
    return relic == null || unlockedWeapons.contains(w.code);
  }
}
