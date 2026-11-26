import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../battle/journey_sprites.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';

import 'journey_compendium_state.dart';
import 'journey_compendium_widgets.dart';

part 'journey_compendium_weapons.dart';

/// 法宝图鉴独立页：主动/被动/特效三类以页签切换，共用同一列表与解锁口径。
class JourneyCompendiumScreen extends StatefulWidget {
  const JourneyCompendiumScreen({super.key});

  @override
  State<JourneyCompendiumScreen> createState() =>
      _JourneyCompendiumScreenState();
}

class _JourneyCompendiumScreenState extends State<JourneyCompendiumScreen>
    with JourneyCompendiumState<JourneyCompendiumScreen> {
  static const _tabs = <(String, String)>[
    ('active', '主动'),
    ('passive', '被动'),
    ('effect', '特效'),
  ];
  String _category = 'active';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return JourneyPageScaffold(
        title: '法宝图鉴',
        body: JourneyLoadError(onRetry: retry),
      );
    }
    final snapshot = config;
    if (snapshot == null) {
      return const JourneyPageScaffold(
        title: '法宝图鉴',
        body: Center(child: JourneyLoading(label: '西行中…')),
      );
    }
    final list = snapshot.weapons.where((w) => w.category == _category).toList()
      ..sort((a, b) =>
          (isWeaponUnlocked(b) ? 1 : 0) - (isWeaponUnlocked(a) ? 1 : 0));
    return JourneyPageScaffold(
      title: '法宝图鉴',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: _tabs
                  .map((tab) => JourneyCompendiumTabChip(
                        label: tab.$2,
                        selected: tab.$1 == _category,
                        onTap: () => setState(() => _category = tab.$1),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: ValueKey(_category),
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
}
