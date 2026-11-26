part of 'journey_compendium_screen.dart';

/// 法宝图鉴卡与解锁口径：从图鉴页拆出的展示逻辑，
/// 沿用主页面的配置快照与进度状态，不改变解锁判定。
extension _JourneyCompendiumWeapons on _JourneyCompendiumScreenState {
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
    final entry = _unlockEntryOf(w.code);
    // 有统一规则时以规则为准展示条件与定价，无规则回落旧图鉴口径。
    final relic = entry == null ? _config?.relicOf(w.code) : null;
    final noAchievement = relic != null && relic.achievementCode.isEmpty;
    final unlocked = _isWeaponUnlocked(w);
    final done = entry != null
        ? _unlockConditionMet(entry)
        : relic == null ||
            noAchievement ||
            _achievementDone(relic.achievementCode);
    // 被动加持/特效触发法宝：条件达成且功德足够时锁图标点金，未达条件默认灰锁
    final meritEnough = JourneyProgressService.instance.state.meritBalance >=
        _unlockCostOf(w.code);
    final unlockable = done && meritEnough;
    final showStatusLock = !unlocked &&
        !charLocked &&
        (w.category == 'passive' || w.category == 'effect');
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
                        : entry != null
                            ? '${_conditionLabel(entry)} · ${_unlockCostOf(w.code)} 功德'
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
                if (showStatusLock)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(
                      Icons.lock,
                      color: unlockable
                          ? JourneyTheme.gold
                          : JourneyTheme.locked,
                      size: 18,
                    ),
                  ),
                JourneyButton(
                  text: noAchievement || entry?.conditionType == 'none'
                      ? '功德解锁'
                      : '解锁',
                  enabled: done && !_unlocking,
                  onTap: () => _unlock(w),
                ),
                if (!done)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('前置条件未达成', style: JourneyTheme.faint),
                  ),
              ],
            ),
          if (charLocked)
            const Icon(Icons.lock, color: JourneyTheme.locked, size: 18),
        ],
      ),
    );
  }

  /// 法宝是否已入池（角色绑定未解锁→锁定；有统一规则按规则判定，
  /// 无规则回落旧图鉴口径）。用于列表"已解锁优先"排序与卡片展示。
  bool _isWeaponUnlocked(JourneyWeaponModel w) {
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state.characterUnlocked(boundChar);
    if (charLocked) return false;
    // 有规则无图鉴行时不能走 relic==null 的「默认已解锁」旧口径，
    // 否则该法宝既不显示购买按钮又被战斗门控挡住，成为永久死项。
    final entry = _unlockEntryOf(w.code);
    if (entry != null) {
      return JourneyProgressService.instance
          .isUnlockGranted(entry.targetKind, w.code);
    }
    final relic = _config?.relicOf(w.code);
    return relic == null || _unlockedWeapons.contains(w.code);
  }

  /// 图鉴展示用条件判定：与扣费服务共用模型层判定，妖王击杀读已加载统计。
  bool _unlockConditionMet(JourneyUnlockEntryModel entry) {
    final state = JourneyProgressService.instance.state;
    return journeyUnlockConditionMet(
      entry,
      JourneyUnlockConditionContext(
        farthestLevelNo: state.farthestLevelNo,
        totalKills: state.totalKills,
        totalMeritEarned: state.totalMeritEarned,
        unlockedAchievements: state.unlockedAchievements,
        bossKills: _killStats,
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
}
