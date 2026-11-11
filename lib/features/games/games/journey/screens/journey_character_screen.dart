import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../models/journey_talent_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_busy.dart';

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
    // 解锁门槛：纯种子模式（远端 81 难未部署）内置关卡仅 1~20，
    // 扩展角色难号（25~49）压缩到 20，保「离线可玩」口径不永锁
    final levelNeed = (_config?.fromSeed ?? false)
        ? math.min(c.unlockLevelNo, 20)
        : c.unlockLevelNo;
    final progressMet = _progress.farthestLevelNo >= levelNeed;
    final meritMet = _progress.meritBalance >= c.unlockMeritCost;
    final canUnlock = !unlocked && progressMet && meritMet;

    return JourneyCard(
      locked: !unlocked,
      onTap: unlocked
          ? () async {
              // 走服务层：持久化出战选择（直接写字段会在重启后丢失）
              await JourneyBusy.run(
                context,
                () => progress.selectCharacter(c.code),
                label: '切换中…',
              );
              if (mounted) setState(() {});
            }
          : (canUnlock ? () => _unlock(c) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 立绘徽章：角色 SVG 资源（未解锁降透明度）
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
            child: ClipOval(
              child: Opacity(
                opacity: unlocked ? 1.0 : 0.4,
                child: SvgPicture.asset(
                  'assets/games/journey/char_${c.code}.svg',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    c.name.characters.first,
                    style: JourneyTheme.titleLg.copyWith(
                      color: unlocked
                          ? JourneyTheme.goldSoft
                          : JourneyTheme.textFaint,
                    ),
                  ),
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
                if (_abilityPreview(c.code) != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _abilityPreview(c.code)!,
                    style: JourneyTheme.faint.copyWith(
                      // 已解锁（加强点点亮）金字高亮，未解锁灰字
                      color: _progress.talentEnhanceLit(c.code)
                          ? JourneyTheme.gold
                          : JourneyTheme.textFaint,
                    ),
                  ),
                ],
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
    // 与解锁判定同口径：种子模式展示压缩后的门槛难号
    final levelNeed = (_config?.fromSeed ?? false)
        ? math.min(c.unlockLevelNo, 20)
        : c.unlockLevelNo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Icon(Icons.lock, color: JourneyTheme.locked, size: 16),
        const SizedBox(height: 4),
        Text(
          progressMet
              ? '功德 ${c.unlockMeritCost}'
              : '通关第 $levelNeed 难',
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

  /// 角色特殊能力预览文案：能力名 + 解锁口径（天赋树加强点点亮）；
  /// 已解锁附一句能力描述。常量表未覆盖的角色返回 null（不显示该行）。
  String? _abilityPreview(String char) {
    final ability = kJourneyCharAbilities[char];
    if (ability == null) return null;
    final unlocked = _progress.talentEnhanceLit(char);
    return unlocked
        ? '特殊能力「${ability.$1}」· ${ability.$2}'
        : '特殊能力「${ability.$1}」· 天赋树加强点点亮解锁';
  }

  Future<void> _unlock(JourneyCharacterModel c) async {
    // 二次确认：高价功德消耗（3000+）误触代价大，弹窗核对余额再扣
    final balance = JourneyProgressService.instance.state.meritBalance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JourneyTheme.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
          side: const BorderSide(color: JourneyTheme.panelStroke),
        ),
        title: Text('请 ${c.name} 上路？', style: JourneyTheme.title),
        content: Text(
          '将消耗 ${c.unlockMeritCost} 功德解锁「${c.name}」。\n'
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
    final progress = JourneyProgressService.instance;
    if (!mounted) return;
    final ok = await JourneyBusy.run(
      context,
      () async {
        final unlocked = await progress.unlockCharacter(c.code,
            meritCost: c.unlockMeritCost);
        await _load();
        return unlocked;
      },
      label: '请人中…',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${c.name} 已加入取经队伍' : '功德不足，无法请 ${c.name} 上路'),
        backgroundColor: ok ? null : JourneyTheme.danger,
      ),
    );
  }
}
