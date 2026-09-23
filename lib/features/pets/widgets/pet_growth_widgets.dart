import 'package:flutter/material.dart';

import '../models/pet_p2_models.dart';
import '../models/pet_rpc_models.dart';
import 'pet_item_icon.dart';

/// 养成页（进化/特性）的展示小块
///
/// 与页面同属 P2，但 `pet_growth_screen.dart` 承载状态与写操作后已超 500 行
/// 硬底线，故把纯展示件抽出（无状态、只收 props，回调以 on 开头）。
/// 这些函数**不做任何判定**：条件是否满足、形态是否可选一律由服务端裁决。

/// 宠物切换条（全部个体，含非在养：选中后按钮自述不可用的原因）
Widget petGrowthPetSelector(
  ColorScheme cs,
  List<PetPetDetailModel> details,
  String? selectedId,
  ValueChanged<String> onSelect,
) {
  if (details.isEmpty) return const SizedBox.shrink();
  return SizedBox(
    height: 46,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: details.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final p = details[i];
        return ChoiceChip(
          selected: p.id == selectedId,
          onSelected: (_) => onSelect(p.id),
          label: Text('${p.name} Lv${p.level}'),
        );
      },
    ),
  );
}

/// 当前形态卡（阶位/稀有度/亲密/特性；进化与特性页签共用头部）
Widget petGrowthHeadCard(ColorScheme cs, PetPetDetailModel? pet) {
  if (pet == null) return const SizedBox.shrink();
  final trait = pet.traitName == null ? '暂无特性' : '特性 ${pet.traitName}';
  return Card(
    color: cs.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${pet.genderLabel} ${pet.name} · ${pet.showNo}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '第 ${pet.stage + 1} 阶 · ${pet.rarityCode} · '
              '亲密 ${pet.intimacy} · $trait',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ],
      ),
    ),
  );
}

/// 进化条件明细（pet_evo_stages.conditions → 人话 chip，见 conditionLabels）
Widget petGrowthConditions(ColorScheme cs, PetEvoStageOptionModel o) {
  final labels = o.conditionLabels;
  if (labels.isEmpty) {
    return Text('无额外条件',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
  }
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final label in labels)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        ),
    ],
  );
}

/// 玩家自选分支候选（[onEvolve] 为 null 表示不可点：灰度未开或正在处理）
Widget petGrowthOptionCard(
  ColorScheme cs,
  PetPetDetailModel pet,
  PetEvoStageOptionModel o, {
  required bool busy,
  VoidCallback? onEvolve,
}) {
  final enabled = o.enabled && !busy;
  return Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${pet.name} → ${o.name}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text(o.rarityCode,
                  style: TextStyle(fontSize: 12, color: cs.tertiary)),
            ],
          ),
          const SizedBox(height: 6),
          petGrowthConditions(cs, o),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onEvolve : null,
              child: Text(o.enabled ? '进化' : '该形态暂未开放'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 概率分支合并卡：列出可能形态与各自条件，按钮不指定目标（服务端按权重掷）
Widget petGrowthRollCard(
  ColorScheme cs,
  List<PetEvoStageOptionModel> rolled, {
  required bool busy,
  VoidCallback? onEvolve,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('由概率决定的形态',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(rolled.map((o) => '${o.name}（${o.rarityCode}）').join('、'),
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          for (final o in rolled) ...[
            const SizedBox(height: 8),
            petGrowthConditions(cs, o),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: busy ? null : onEvolve,
              child: const Text('进化（形态随机）'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 洗练剂行（背包 trait_wash 道具；[onWash] 为 null 表示忙或道具行缺 id）
Widget petGrowthWashRow(
  ColorScheme cs,
  PetBagItemModel item, {
  required bool busy,
  VoidCallback? onWash,
}) {
  return Card(
    child: ListTile(
      leading: PetItemIcon(
          iconKey: item.iconKey, fallback: Icons.auto_fix_high, size: 26),
      title: Text(item.name),
      subtitle: Text('可用 ×${item.quantity}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      trailing: FilledButton.tonal(
        onPressed: busy || item.itemId.isEmpty ? null : onWash,
        child: const Text('洗练'),
      ),
    ),
  );
}
