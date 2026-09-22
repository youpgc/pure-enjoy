import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_rpc_models.dart';

/// 背包条目的展示元数据（分类名 / 图标 / 效果描述 / 可用性判定）
///
/// 数值一律来自 pet_items.effect，不在此硬编码。

/// 可在背包直接「使用」到在养宠物身上的效果类型
const Set<String> petUsableEffectTypes = {
  'feed',
  'clean',
  'toy',
  'heal',
  'refine_point',
};

bool petBagItemUsable(PetBagItemModel item) =>
    item.category == PetBagCategory.consumable.code &&
    petUsableEffectTypes.contains(item.effectType);

String petBagCategoryLabel(String category) =>
    PetBagCategory.fromCode(category)?.label ?? '物品';

IconData petBagFallbackIcon(PetBagItemModel item) {
  if (item.isEgg) return Icons.egg_outlined;
  return switch (item.effectType) {
    'feed' => Icons.restaurant,
    'clean' => Icons.shower_outlined,
    'toy' => Icons.toys_outlined,
    'rescue' => Icons.health_and_safety_outlined,
    'heal' => Icons.healing_outlined,
    'refine_point' => Icons.auto_fix_high,
    'refine_reassign' => Icons.auto_fix_high,
    _ => Icons.inventory_2_outlined,
  };
}

/// 效果描述（依据 pet_items.effect 结构化字段生成，不臆测数值）
String petBagEffectDesc(PetBagItemModel item) {
  final parts = <String>[];
  void addNum(String key, String label) {
    final v = (item.effect[key] as num?)?.toInt();
    if (v != null && v > 0) parts.add('$label+$v');
  }

  switch (item.effectType) {
    case 'feed':
      addNum('hunger', '饱食');
      addNum('mood', '心情');
      addNum('exp', '经验');
    case 'clean':
      parts.add('清洁宠物');
      addNum('mood', '心情');
    case 'toy':
      parts.add('陪它玩耍');
      addNum('mood', '心情');
      addNum('exp', '经验');
    case 'rescue':
      parts.add('历险遇险时立即救回宠物');
    case 'heal':
      parts.add('恢复宠物健康（历险受伤后使用）');
    case 'refine_point':
      parts.add('使用后获得 1 洗练点（洗练在属性面板进行，每次洗练消耗 1 点）');
    // 旧洗练剂直洗语义（2026-09-20 下线；SQL 未执行时兜底展示）
    case 'refine_reassign':
      parts.add('重新分配宠物升级获得的属性加点（孵化基础属性不受影响）');
    default:
      if (item.isEgg) parts.add('点击立即孵化，见证新伙伴诞生');
  }
  return parts.join(' · ');
}
