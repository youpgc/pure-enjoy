part of 'journey_compendium_screen.dart';

/// 法宝图鉴卡：展示品质、图标、归属、解锁条件；解锁按钮走共享
/// requestUnlock，判定与扣费仍由统一规则服务承载。
extension _JourneyCompendiumWeapons on _JourneyCompendiumScreenState {
  Widget _buildWeaponCard(JourneyWeaponModel w) {
    final qualityIdx = w.isActive ? 3 : (w.isPassive ? 2 : 1);
    final quality = JourneyTheme.qualityColors[qualityIdx.clamp(0, 3)];
    final boundChar = w.characterCode;
    final charLocked = boundChar.isNotEmpty &&
        !JourneyProgressService.instance.state.characterUnlocked(boundChar);
    final entry = unlockEntryOf(w.code);
    final relic = entry == null ? config?.relicOf(w.code) : null;
    final noAchievement = relic != null && relic.achievementCode.isEmpty;
    final unlocked = isWeaponUnlocked(w);
    final done = entry != null
        ? unlockConditionMet(entry)
        : relic == null ||
            noAchievement ||
            achievementDone(relic.achievementCode);
    final meritEnough =
        JourneyProgressService.instance.state.meritBalance >= unlockCostOf(w.code);
    final unlockable = done && meritEnough;
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
                        ? '随角色「${charName(boundChar)}」解锁'
                        : '归属角色：${charName(boundChar)}',
                    style: charLocked
                        ? JourneyTheme.faint
                        : JourneyTheme.faint.copyWith(color: JourneyTheme.gold),
                  ),
                ],
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
                    charLocked
                        ? '先解锁角色「${charName(boundChar)}」'
                        : entry != null
                            ? '${conditionLabel(entry)} · ${unlockCostOf(w.code)} 功德'
                            : noAchievement
                                ? '功德 ${relic.meritCost} 解锁'
                                : '解锁条件：${achievementName(relic!.achievementCode)}'
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.lock,
                    color: unlockable ? JourneyTheme.gold : JourneyTheme.locked,
                    size: 18,
                  ),
                ),
                JourneyButton(
                  text: '解锁',
                  enabled: unlockable && !unlocking,
                  onTap: () => requestUnlock(
                    subject: '法宝',
                    name: w.name,
                    cost: unlockCostOf(w.code),
                    action: () => unlockWeapon(w),
                    successMessage: '「${w.name}」已入池',
                  ),
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
}
