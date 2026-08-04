/// 敏感词模型（从 sensitive_word_service.dart 抽出，便于复用与测试）
class SensitiveWordModel {
  final String id;
  final String word;
  final String category; // novel, system
  final String level; // block, replace, warn
  final String? replaceWord;
  final String matchMode; // exact, contains, regex
  final bool isActive;
  final int hitCount;

  SensitiveWordModel({
    required this.id,
    required this.word,
    required this.category,
    required this.level,
    this.replaceWord,
    required this.matchMode,
    required this.isActive,
    required this.hitCount,
  });

  factory SensitiveWordModel.fromJson(Map<String, dynamic> json) {
    return SensitiveWordModel(
      id: json['id'] as String,
      word: json['word'] as String,
      category: json['category'] as String,
      level: json['level'] as String,
      replaceWord: json['replace_word'] as String?,
      matchMode: json['match_mode'] as String? ?? 'contains',
      isActive: json['is_active'] as bool? ?? true,
      hitCount: json['hit_count'] as int? ?? 0,
    );
  }
}

/// 敏感词检测结果
class SensitiveWordCheckResult {
  /// 是否包含敏感词
  final bool hasSensitive;

  /// 是否被拦截（仅 level=block 时为 true）
  final bool isBlocked;

  /// 处理后的文本（替换后的内容）
  final String processedText;

  /// 命中的敏感词列表
  final List<SensitiveWordModel> matchedWords;

  /// 处理动作: blocked, replaced, warned, none
  final String actionTaken;

  SensitiveWordCheckResult({
    required this.hasSensitive,
    required this.isBlocked,
    required this.processedText,
    required this.matchedWords,
    required this.actionTaken,
  });

  /// 安全结果（无敏感词）
  factory SensitiveWordCheckResult.safe(String text) {
    return SensitiveWordCheckResult(
      hasSensitive: false,
      isBlocked: false,
      processedText: text,
      matchedWords: [],
      actionTaken: 'none',
    );
  }
}
