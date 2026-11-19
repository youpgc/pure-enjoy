import 'package:flutter/material.dart';

import '../battle/journey_attributes_data.dart';
import '../models/journey_talent_models.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';

/// 西行记录详情页：展示单场对局结算时采集的属性快照。
/// 快照按属性面板全量口径随记录落库，旧记录无快照时展示空态。
class JourneyRunDetailScreen extends StatelessWidget {
  const JourneyRunDetailScreen({super.key, required this.record});

  final JourneyRunRecordModel record;

  String get _title {
    if (record.levelTitle.isNotEmpty) return record.levelTitle;
    if (record.levelNo > 0) return '第 ${record.levelNo} 难';
    switch (record.kind) {
      case 'endless':
        return '无尽妖潮';
      case 'daily':
        return '西行游历';
      default:
        return '模式对局';
    }
  }

  /// 角色摘要：优先读快照内的角色名/等级/波次；旧记录仅有 character_code
  /// 时回退 code、等级或波次缺失时不展示该段，避免拼出半截文案。
  String _characterLine() {
    final detail = record.runDetail;
    if (detail == null) return '';
    final name = detail['character_name'] as String? ?? '';
    final code = detail['character_code'] as String? ?? '';
    final level = detail['char_level'];
    final wave = detail['wave'];
    final parts = <String>[
      if (name.isNotEmpty) name else if (code.isNotEmpty) code,
      if (level is num && level > 0) 'Lv${level.round()}',
      if (wave is num && wave > 0) '第 ${wave.round()} 波',
    ];
    return parts.join(' · ');
  }

  List<JourneyAttrGroup> _groups() {
    final raw = record.runDetail?['attr_groups'];
    if (raw is! List) return const <JourneyAttrGroup>[];
    final groups = <JourneyAttrGroup>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final group = JourneyAttrGroup.fromJson(item);
      if (group != null) groups.add(group);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final characterLine = _characterLine();
    return JourneyPageScaffold(
      title: '西行记录详情',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: <Widget>[
          JourneyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_title, style: JourneyTheme.title),
                const SizedBox(height: 6),
                if (characterLine.isNotEmpty) ...<Widget>[
                  Text(characterLine, style: JourneyTheme.body),
                  const SizedBox(height: 6),
                ],
                Text(
                  '${record.cleared ? '通关 ✓' : '未竟'} · '
                  '击杀 ${record.kills} · 功德 +${record.meritGained}',
                  style: JourneyTheme.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text('本局暂无属性快照', style: JourneyTheme.faint),
              ),
            )
          else
            for (final group in groups) ...<Widget>[
              Text(group.title, style: JourneyTheme.title),
              const SizedBox(height: 6),
              JourneyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final row in group.rows) _attrRow(row.$1, row.$2),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _attrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 108, child: Text(label, style: JourneyTheme.body)),
          Expanded(child: Text(value, style: JourneyTheme.caption)),
        ],
      ),
    );
  }
}
