part of 'journey_compendium_screen.dart';

// 解锁卡片与宿主同库，setState 为库内可见的受保护成员。
// ignore_for_file: invalid_use_of_protected_member

/// 维度解锁页签：统一解锁规则的 App 展示与购买入口。
/// 法宝/被动沿用原图鉴卡片入口，规则由同一服务判定与落账。
extension _JourneyCompendiumUnlocks on _JourneyCompendiumScreenState {
  /// 法宝/被动的统一规则：与扣费服务和战斗门控共用同一解析入口。
  JourneyUnlockEntryModel? _unlockEntryOf(String code) =>
      _config?.unlockEntryForWeapon(code);

  /// 确认弹窗展示价与服务端扣费同源：统一规则优先，旧图鉴价兜底。
  int _unlockCostOf(String code) =>
      _unlockEntryOf(code)?.meritCost ?? _config?.relicOf(code)?.meritCost ?? 0;

  Widget _buildSlotUnlockList() {
    final entries = (_config?.unlockEntries ?? const <JourneyUnlockEntryModel>[])
        .where((e) => e.targetKind == 'slot' && e.enabled)
        .toList();
    if (entries.isEmpty) {
      return const Center(
        child: Text('暂无待解锁维度', style: JourneyTheme.body),
      );
    }
    final progress = JourneyProgressService.instance;
    final sorted = List<JourneyUnlockEntryModel>.from(entries)
      ..sort((a, b) {
        final aDone = progress.isUnlockGranted(a.targetKind, a.targetCode) ? 1 : 0;
        final bDone = progress.isUnlockGranted(b.targetKind, b.targetCode) ? 1 : 0;
        return aDone - bDone;
      });
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildSlotUnlockCard(sorted[i]),
    );
  }

  Widget _buildSlotUnlockCard(JourneyUnlockEntryModel entry) {
    // 带内置种子兜底的映射：干净会话未预载维度表时仍能显示中文名。
    final def = _config?.slotDefMap()[entry.targetCode];
    final name = def?.name ?? entry.targetCode;
    final done =
        JourneyProgressService.instance.isUnlockGranted('slot', entry.targetCode);
    final balance = JourneyProgressService.instance.state.meritBalance;
    final deficit = !done && balance < entry.meritCost;
    return JourneyCard(
      qualityColor: done ? JourneyTheme.gold : JourneyTheme.panelStroke,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$name${done ? ' · 已解锁' : ''}',
                    style: JourneyTheme.title),
                const SizedBox(height: 4),
                Text(
                  '${_conditionLabel(entry)} · ${entry.meritCost} 功德',
                  style: JourneyTheme.body.copyWith(
                    color: deficit ? JourneyTheme.locked : null,
                  ),
                ),
                if (entry.remark.isNotEmpty)
                  Text(entry.remark, style: JourneyTheme.body),
              ],
            ),
          ),
          if (!done)
            TextButton(
              onPressed: () => _unlockSlot(entry, name),
              child: Text(
                '解锁',
                style: JourneyTheme.body.copyWith(color: JourneyTheme.gold),
              ),
            ),
        ],
      ),
    );
  }

  String _conditionLabel(JourneyUnlockEntryModel entry) => switch (entry.conditionType) {
        'none' => '无前置条件',
        'level_cleared' => '通关第 ${entry.conditionValue} 难',
        'achievement' => '达成「${_achievementName(entry.conditionValue)}」',
        'total_kills' => '累计击杀 ${entry.conditionValue}',
        'merit_earned' => '累计功德 ${entry.conditionValue}',
        'revived' => '完成首次还魂',
        'boss_killed' => '伏诛 ${_bossName(entry.conditionValue)}',
        _ => '待达成',
      };

  /// 妖王编码转中文名：远端怪物表优先，内置种子兜底。
  String _bossName(String code) {
    for (final m in _config?.monsters ?? const <JourneyMonsterModel>[]) {
      if (m.code == code && m.name.isNotEmpty) return m.name;
    }
    for (final row in kJourneyMonsterSeed) {
      if (row['code'] == code) return row['name'] as String? ?? code;
    }
    return code;
  }

  Future<void> _unlockSlot(JourneyUnlockEntryModel entry, String name) async {
    if (_unlocking) return;
    _unlocking = true;
    try {
      final progress = JourneyProgressService.instance;
      await progress.evaluateAchievements();
      _refreshProgress();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: JourneyTheme.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
            side: const BorderSide(color: JourneyTheme.panelStroke),
          ),
          title: const Text('解锁维度？', style: JourneyTheme.title),
          content: Text(
            '将消耗 ${entry.meritCost} 功德解锁「$name」，确认后即时扣除。',
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
      await JourneyBusy.run(
        context,
        () async {
          final ok = await progress.unlockTarget('slot', entry.targetCode);
          _refreshProgress();
          _toast(ok ? '「$name」已解锁' : '条件未达成或功德不足');
          if (ok && mounted) setState(() {});
        },
        label: '解锁中…',
      );
    } finally {
      _unlocking = false;
    }
  }
}
