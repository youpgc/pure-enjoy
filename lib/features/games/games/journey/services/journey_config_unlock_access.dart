part of 'journey_config_snapshot.dart';

/// 统一解锁规则与旧图鉴定价的只读访问：按目标类型 + 编码取规则，
/// 无规则时调用侧按「不设门控」处理，保证后台未配置时行为不变。
extension JourneyConfigUnlockAccess on JourneyConfigSnapshot {
  /// 武器图鉴解锁定价（未配置返回 null）。
  JourneyRelicUnlockModel? relicOf(String weaponCode) {
    for (final r in relicUnlocks) {
      if (r.weaponCode == weaponCode) return r;
    }
    return null;
  }

  /// 按目标类型 + 编码取解锁规则（停用规则不返回）。
  JourneyUnlockEntryModel? unlockEntry(String targetKind, String targetCode) {
    for (final e in unlockEntries) {
      if (!e.enabled) continue;
      if (e.targetKind == targetKind && e.targetCode == targetCode) return e;
    }
    return null;
  }

  /// 法宝/被动按编码取规则：按类别推定目标类型，兼容后台错配到另一类。
  /// 门控与购买必须共用此入口，避免交叉查导致口径分叉。
  JourneyUnlockEntryModel? unlockEntryForWeapon(String code) {
    final kind = weaponOf(code)?.category == 'passive' ? 'passive' : 'weapon';
    return unlockEntry(kind, code) ??
        unlockEntry(kind == 'passive' ? 'weapon' : 'passive', code);
  }

  /// 按统一条目键取规则（进度行 unlocked_entries 的键格式）。
  JourneyUnlockEntryModel? unlockEntryByKey(String key) {
    for (final e in unlockEntries) {
      if (!e.enabled) continue;
      if (e.entryKey == key) return e;
    }
    return null;
  }
}
