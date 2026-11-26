import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../battle/journey_sprites.dart';
import '../models/journey_models.dart';
import '../models/journey_unlock_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';

import 'journey_compendium_state.dart';

/// 维度槽图鉴独立页：展示全部武器维度槽（属性/效果两类）。
/// 初始槽无解锁规则、直接可用；后期槽按后台解锁规则显示条件与功德定价，
/// 解锁走统一服务（条件校验→扣功德→写流水→写进度）。
class JourneySlotCompendiumScreen extends StatefulWidget {
  const JourneySlotCompendiumScreen({super.key});

  @override
  State<JourneySlotCompendiumScreen> createState() =>
      _JourneySlotCompendiumScreenState();
}

class _JourneySlotCompendiumScreenState
    extends State<JourneySlotCompendiumScreen>
    with JourneyCompendiumState<JourneySlotCompendiumScreen> {
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return JourneyPageScaffold(
        title: '维度图鉴',
        body: JourneyLoadError(onRetry: retry),
      );
    }
    final snapshot = config;
    if (snapshot == null) {
      return const JourneyPageScaffold(
        title: '维度图鉴',
        body: Center(child: JourneyLoading(label: '西行中…')),
      );
    }
    final defs = snapshot.slotDefMap().values.toList();
    // 分组与卡片共用一次规则查询结果，避免逐槽重复遍历规则表。
    final entries = <String, JourneyUnlockEntryModel?>{
      for (final def in defs) def.code: snapshot.unlockEntry('slot', def.code),
    };
    final initial = defs.where((def) => entries[def.code] == null).toList();
    final unlockable = defs.where((def) => entries[def.code] != null).toList();
    return JourneyPageScaffold(
      title: '维度图鉴',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _sectionTitle('初始维度 · 直接可用', initial.length),
          ...initial.map((def) => _buildSlotCard(def, entries[def.code])),
          const SizedBox(height: 12),
          _sectionTitle('进阶维度 · 功德解锁', unlockable.length),
          ...unlockable.map((def) => _buildSlotCard(def, entries[def.code])),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            Text('$label（$count）', style: JourneyTheme.title),
          ],
        ),
      );

  Widget _buildSlotCard(JourneySlotDefModel def, JourneyUnlockEntryModel? entry) {
    final granted = JourneyProgressService.instance
        .isUnlockGranted('slot', def.code);
    final persistent = granted || entry == null;
    final balance = JourneyProgressService.instance.state.meritBalance;
    final deficit = entry != null && !granted && balance < entry.meritCost;
    final kindLabel = def.kind == 'attribute' ? '属性' : '效果';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: JourneyCard(
        qualityColor: persistent ? JourneyTheme.gold : JourneyTheme.panelStroke,
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
                  color: persistent ? JourneyTheme.gold : JourneyTheme.locked,
                  width: 1.2,
                ),
              ),
              child: SvgPicture.asset(
                JourneySprites.slotIcon(def.code),
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.category,
                  color: JourneyTheme.gold,
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
                      Flexible(child: Text(def.name, style: JourneyTheme.title)),
                      const SizedBox(width: 6),
                      _tag(kindLabel),
                      const SizedBox(width: 4),
                      _tag('上限 ${def.maxLevel} 级'),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(def.effectPerLevel, style: JourneyTheme.caption),
                  const SizedBox(height: 3),
                  Text(
                    entry == null
                        ? '初始可用 · 三选一可习得'
                        : granted
                            ? '已解锁 · 三选一可习得'
                            : '${conditionLabel(entry)} · ${entry.meritCost} 功德',
                    style: deficit
                        ? JourneyTheme.faint.copyWith(color: JourneyTheme.locked)
                        : JourneyTheme.faint.copyWith(color: JourneyTheme.gold),
                  ),
                ],
              ),
            ),
            if (entry != null && !granted)
              JourneyButton(
                text: '解锁',
                enabled: unlockConditionMet(entry) && !deficit && !unlocking,
                onTap: () => requestUnlock(
                  subject: '维度',
                  name: def.name,
                  cost: entry.meritCost,
                  action: () => unlockSlot(def.code),
                  successMessage: '「${def.name}」已解锁',
                ),
              )
            else if (persistent)
              const Icon(Icons.verified, color: JourneyTheme.gold, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JourneyTheme.panelStroke),
        ),
        child: Text(text, style: JourneyTheme.faint),
      );
}
