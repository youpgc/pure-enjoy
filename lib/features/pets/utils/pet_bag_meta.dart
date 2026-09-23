import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_rpc_models.dart';

/// 背包条目的展示元数据（分类名 / 图标 / 效果描述 / 可用性判定）
///
/// 数值一律来自 pet_items.effect，不在此硬编码。

/// 可在背包直接「使用」到在养宠物身上的效果类型
///
/// P2 三类各有专属 RPC，**不走** rpc_pet_use_item：
/// hatch_accel → rpc_pet_hatch_accelerate（蛋详情页）、
/// trait_wash → rpc_pet_wash_trait（成长页）、
/// unlock → rpc_pet_unlock_feature（背包内即点即开通）。
const Set<String> petUsableEffectTypes = {
  PetItemEffectType.feed.code,
  PetItemEffectType.clean.code,
  PetItemEffectType.toy.code,
  PetItemEffectType.heal.code,
  PetItemEffectType.refinePoint.code,
};

/// 效果类型（键域见 [PetItemEffectType]；未登记值返回 null 走兜底展示）
PetItemEffectType? petBagItemType(PetBagItemModel item) =>
    PetItemEffectType.fromCode(item.effectType);

bool petBagItemUsable(PetBagItemModel item) =>
    item.category == PetBagCategory.consumable.code &&
    petUsableEffectTypes.contains(item.effectType);

String petBagCategoryLabel(String category) =>
    PetBagCategory.fromCode(category)?.label ?? '物品';

IconData petBagFallbackIcon(PetBagItemModel item) {
  if (item.isEgg) return Icons.egg_outlined;
  return switch (petBagItemType(item)) {
    PetItemEffectType.feed => Icons.restaurant,
    PetItemEffectType.clean => Icons.shower_outlined,
    PetItemEffectType.toy => Icons.toys_outlined,
    PetItemEffectType.heal => Icons.healing_outlined,
    PetItemEffectType.refinePoint => Icons.auto_fix_high,
    PetItemEffectType.refineReassign => Icons.auto_fix_high,
    PetItemEffectType.rescue => Icons.health_and_safety_outlined,
    PetItemEffectType.hatchAccel => Icons.speed,
    PetItemEffectType.traitWash => Icons.replay,
    PetItemEffectType.unlock => Icons.vpn_key_outlined,
    null => Icons.inventory_2_outlined,
  };
}

/// 效果描述（依据 pet_items.effect 结构化字段生成，不臆测数值）
String petBagEffectDesc(PetBagItemModel item) {
  final parts = <String>[];
  void addNum(String key, String label) {
    final v = (item.effect[key] as num?)?.toInt();
    if (v != null && v > 0) parts.add('$label+$v');
  }

  switch (petBagItemType(item)) {
    case PetItemEffectType.feed:
      addNum('hunger', '饱食');
      addNum('mood', '心情');
      addNum('exp', '经验');
    case PetItemEffectType.clean:
      parts.add('清洁宠物');
      addNum('mood', '心情');
    case PetItemEffectType.toy:
      parts.add('陪它玩耍');
      addNum('mood', '心情');
      addNum('exp', '经验');
    case PetItemEffectType.heal:
      parts.add('恢复宠物健康（历险受伤后使用）');
    case PetItemEffectType.rescue:
      parts.add('历险遇险时立即救回宠物');
    case PetItemEffectType.refineReassign:
      // 旧洗练剂直洗语义（2026-09-20 下线；历史数据兜底展示）
      parts.add('重新分配宠物升级获得的属性加点（孵化基础属性不受影响）');
    case PetItemEffectType.refinePoint:
      parts.add('使用后获得 1 洗练点（洗练在属性面板进行，每次洗练消耗 1 点）');
    case PetItemEffectType.hatchAccel:
      final min = (item.effect['minutes'] as num?)?.toInt();
      parts.add(min == null
          ? '让一枚等待中的蛋提前出壳（时长见后台配置）'
          : '让一枚等待中的蛋提前 $min 分钟出壳');
    case PetItemEffectType.traitWash:
      parts.add('为一只宠物重掷特性，结果不可回退');
    case PetItemEffectType.unlock:
      final feature = item.effect['feature'] as String? ?? '';
      parts.add(feature.isEmpty
          ? '使用后可开通一项功能'
          : '使用后开通「${petFeatureLabel(feature)}」');
    case null:
      if (item.isEgg) {
        parts.add(item.subType == 'random'
            ? '点击孵蛋页孵化（传说蛋需等待）'
            : '点击立即孵化，见证新伙伴诞生');
      } else if (item.subType == 'rescue') {
        parts.add('历险遇险时立即救回宠物');
      } else if (item.subType == 'evolution') {
        parts.add('进化媒介：进化时由服务端自动扣除，无需手动使用');
      }
  }
  return parts.join(' · ');
}

/// 功能键展示名（[PetFeatureKey] 值域；未登记值原样返回）
String petFeatureLabel(String key) =>
    PetFeatureKey.fromCode(key)?.label ?? key;
