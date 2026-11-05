import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';

/// S5 五行天赋页。
///
/// 天赋点总量 81（首通 1 点/难）；每系 16 层常规+第 17 层标志强化；
/// 相生相克前置（高层需先修生源，标志层需本系满+克我者≥4）。
class JourneyTalentScreen extends StatefulWidget {
  const JourneyTalentScreen({super.key});

  @override
  State<JourneyTalentScreen> createState() => _JourneyTalentScreenState();
}

class _JourneyTalentScreenState extends State<JourneyTalentScreen> {
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
        title: '五行天赋',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    final allocated = _progress.talentPoints.length;
    return JourneyPageScaffold(
      title: '五行天赋',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          JourneyPanel(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '天赋点 $_progressText',
                        style: JourneyTheme.title,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: allocated /
                              JourneyProgressService.talentPoolTotal,
                          minHeight: 6,
                          backgroundColor: JourneyTheme.bgDeep,
                          color: JourneyTheme.gold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '点数来源：每难首通 +1（81 难=81 点）· 相生前置，不可一次点满',
                        style: JourneyTheme.faint,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                JourneyCurrencyBar(merit: _progress.meritBalance),
              ],
            ),
          ),
          ..._buildElementSections(config),
        ],
      ),
    );
  }

  String get _progressText {
    final allocated = _progress.talentPoints.length;
    const total = JourneyProgressService.talentPoolTotal;
    return '$allocated / $total · 余 ${_progress.talentPool} 点';
  }

  List<Widget> _buildElementSections(JourneyConfigSnapshot config) {
    const elements = <String>['metal', 'wood', 'water', 'fire', 'earth'];
    return elements.map((e) {
      final rows = config.talents.where((t) => t.element == e).toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      final color = JourneyTheme.elementColors[e] ?? JourneyTheme.gold;
      final name = JourneyTheme.elementNames[e] ?? e;
      final generator = JourneyProgressService.generatorOf[e]!;
      final generatorName =
          JourneyProgressService.restrainerOfName(generator);
      final taken = _progress.talentLevelsOf(e);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              SvgPicture.asset(
                'assets/games/journey/element_$e.svg',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: color),
                  ),
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ),
              const SizedBox(width: 8),
              Text('$name 系', style: JourneyTheme.title),
              const SizedBox(width: 8),
              Text(
                taken >= 16
                    ? '已满 16 层 · 标志层可点'
                    : '已修 $taken/16 · 高层需「$generatorName」系相生',
                style: JourneyTheme.faint,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((t) => _buildTalentRow(t, color)),
        ],
      );
    }).toList();
  }

  Widget _buildTalentRow(JourneyTalentModel talent, Color color) {
    final taken = _progress.talentPointsOf(talent.element, talent.seq);
    final blockReason = JourneyProgressService.instance
        .talentBlockReason(talent);
    final canSpend = taken == 0 && blockReason == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: JourneyCard(
        onTap: canSpend ? () => _spend(talent) : null,
        qualityColor: talent.isSignature
            ? color
            : (taken > 0 ? color : null),
        locked: !canSpend,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        talent.name,
                        style: talent.isSignature
                            ? JourneyTheme.title.copyWith(color: color)
                            : JourneyTheme.body,
                      ),
                      if (talent.isSignature) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('标志',
                              style: TextStyle(
                                  fontSize: 9, color: color)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    taken > 0
                        ? '已点亮'
                        : (talent.isSignature
                            ? talent.signatureDesc
                            : (blockReason ?? '消耗 1 天赋点')),
                    style: JourneyTheme.faint,
                  ),
                ],
              ),
            ),
            Icon(
              taken > 0
                  ? Icons.check_circle
                  : (talent.isSignature
                      ? Icons.workspace_premium
                      : Icons.circle_outlined),
              color: taken > 0 ? color : JourneyTheme.locked,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _spend(JourneyTalentModel talent) async {
    final ok = await JourneyProgressService.instance.spendTalent(talent);
    if (!mounted) return;
    if (ok) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('前置条件未满足')),
      );
    }
  }
}
