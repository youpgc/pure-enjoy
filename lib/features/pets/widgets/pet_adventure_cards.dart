import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_rpc_models.dart';

/// 历险页卡片组件（2026-09-17 属性系统 Phase 2 拆分）
///
/// 承载属性要求行与「为你匹配」推荐卡，保证历险页行数在 500 以内。
/// 语义对齐服务端（feature_pet_attributes_20260917.sql）：
/// - 等级 = 硬门槛（不达标 UI 灰置，start 校验 PET_LEVEL_TOO_LOW）；
/// - 属性 = 结算判据（不达标仍可出发，claim 时判 failed + 惩罚）→
///   未达标项红显「有风险」而非禁止。

/// 属性要求摘要行（智力 20 · 力量 15）：未达标项红显加粗（风险提示）
class PetAttrReqText extends StatelessWidget {
  const PetAttrReqText({super.key, required this.reqs, required this.attrs});

  /// spot.attr_requirements：[{attr, value}]
  final List<Map<String, dynamic>> reqs;

  /// 当前宠物四维属性（键与 PetAttrKey.code 对齐）
  final Map<String, int> attrs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    for (final r in reqs) {
      final key = PetAttrKey.fromCode(r['attr'] as String?);
      final value = (r['value'] as num?)?.toInt();
      if (key == null || value == null) continue;
      final ok = (attrs[key.code] ?? 0) >= value;
      spans.add(TextSpan(
        text: '${key.label} $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: ok ? FontWeight.w400 : FontWeight.w700,
          color: ok ? cs.onSurfaceVariant : cs.error,
        ),
      ));
      spans.add(const TextSpan(text: '  ', style: TextStyle(fontSize: 11)));
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 「为你匹配」推荐卡（rpc_pet_adventure_match 随机标推荐的历险地；
/// 可一键展开档位选择，也可忽略自行挑）
class PetMatchBanner extends StatelessWidget {
  const PetMatchBanner({super.key, required this.spotName, this.onTap});

  final String spotName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.auto_awesome_outlined, color: cs.primary),
        title: Text('为你匹配 · $spotName',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: const Text('根据宠物当前条件推荐，点击查看历险时长',
            style: TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}

/// 历险地卡片：等级硬门槛灰置（服务端 start 同校验）；属性要求 = 结算
/// 判据（未达标仍可出发，claim 判 failed），未达标项红显提示风险
Widget petSpotCard(
  BuildContext context, {
  required PetSpotModel spot,
  required int petLevel,
  required Map<String, int> petAttrs,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final req = spot.requiredLevel;
  final locked = req != null && petLevel < req;
  final hasReq = spot.attrRequirements.isNotEmpty;
  return Card(
    child: ListTile(
      leading: Icon(locked ? Icons.lock_outline : Icons.explore_outlined),
      title: Text(spot.name),
      subtitle: (req != null || hasReq)
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (req != null)
                    Text(
                      locked ? 'Lv.$req 解锁' : '等级达标 Lv.$req',
                      style: TextStyle(
                          fontSize: 11,
                          color: locked ? cs.error : cs.onSurfaceVariant),
                    ),
                  if (hasReq)
                    PetAttrReqText(
                        reqs: spot.attrRequirements, attrs: petAttrs),
                ],
              ),
            )
          : null,
      isThreeLine: req != null && hasReq,
      trailing: locked
          ? const Icon(Icons.lock_outline, size: 18)
          : const Icon(Icons.chevron_right),
      onTap: locked ? null : onTap,
    ),
  );
}
