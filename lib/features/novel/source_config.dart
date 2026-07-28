/// 小说来源（source 字段）的共享配置：标签映射 + 聚合判定。
///
/// 与后台 `constants/novel.ts` 的 `NOVEL_SOURCE_MAP` / `NOVEL_AGGREGATED_SOURCES`
/// 保持对齐，避免两端各写一套导致标签漂移（如飞卢缺「飞卢」标签）。
///
/// 注意：App 端聚合判定以 `source_url` 非空为准（见 NovelModel.isAggregated），
/// 此处的 [aggregated] 仅用于与后台标签逻辑保持一致，不直接参与路由。
class NovelSourceConfig {
  /// source 取值 → 中文展示名。
  static const Map<String, String> labels = {
    'original': '原创',
    'zongheng': '纵横',
    'faloo': '飞卢',
    'douban': '豆瓣',
    '17k': '17K',
  };

  /// 聚合书（非原创）来源集合，用于标签着色，与后台保持一致。
  static const Set<String> aggregated = {
    'zongheng',
    'faloo',
    'douban',
    '17k',
  };

  /// 取来源展示名；未知来源返回原始字符串，空返回「外部来源」。
  static String displayName(String? source) {
    if (source == null || source.isEmpty) return '外部来源';
    final s = source.toLowerCase();
    for (final entry in labels.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
    return source;
  }

  /// 是否为纵横来源（纵横有原生 App，可尝试 scheme 唤起）。
  static bool isZongheng(String? source) {
    if (source == null || source.isEmpty) return false;
    return source.toLowerCase().contains('zongheng');
  }
}
