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

/// 法宝图鉴独立页：category 决定展示主动/被动/特效其中一类。
/// 三处入口各开一页，页面内不再设法宝类别页签。
class JourneyCompendiumScreen extends StatefulWidget {
  final String category;
  final String title;

  const JourneyCompendiumScreen({
    super.key,
    this.category = 'active',
    this.title = '主动法宝',
  });

  @override
  State<JourneyCompendiumScreen> createState() =>
      _JourneyCompendiumScreenState();
}

class _JourneyCompendiumScreenState extends State<JourneyCompendiumScreen>
    with JourneyCompendiumState<JourneyCompendiumScreen> {
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return JourneyPageScaffold(
        title: widget.title,
        body: JourneyLoadError(onRetry: retry),
      );
    }
    final snapshot = config;
    if (snapshot == null) {
      return JourneyPageScaffold(
        title: widget.title,
        body: const Center(child: JourneyLoading(label: '西行中…')),
      );
    }
    final list = snapshot.weapons.where((w) => w.category == widget.category).toList()
      ..sort((a, b) =>
          (isWeaponUnlocked(b) ? 1 : 0) - (isWeaponUnlocked(a) ? 1 : 0));
    return JourneyPageScaffold(
      title: widget.title,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _buildWeaponCard(list[i]),
      ),
    );
  }
}
