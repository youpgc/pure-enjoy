import 'package:flutter/foundation.dart';
import './api_client.dart';
import './sensitive_word_models.dart';
import './sensitive_word_logger.dart';

export './sensitive_word_models.dart';

/// 敏感词模型与检测结果已抽到 sensitive_word_models.dart（见本文件顶部 export）

/// 敏感词过滤服务
/// 从 Supabase 加载敏感词列表，在本地进行文本检测和过滤
/// 支持小说敏感词和系统敏感词两个分类，各有独立开关
class SensitiveWordService {
  SensitiveWordService._();
  static final SensitiveWordService instance = SensitiveWordService._();

  /// 敏感词缓存（按分类分组）
  final Map<String, List<SensitiveWordModel>> _wordCache = {};

  /// 分类开关状态
  bool _novelEnabled = false;
  bool _systemEnabled = false;

  /// 缓存时间戳
  DateTime? _lastFetch;

  /// 缓存有效期（小时）
  static const int _cacheHours = 6;

  /// 是否已初始化
  bool _initialized = false;

  /// 是否正在刷新中（防止并发刷新）
  bool _isRefreshing = false;

  /// ==================== 初始化 ====================

  /// 初始化服务：加载敏感词和开关状态
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSwitches();
    await _loadWords();
    _initialized = true;
    if (kDebugMode) {
      debugPrint('✅ 敏感词服务初始化完成'
          '(小说:${_wordCache['novel']?.length ?? 0}, '
          '系统:${_wordCache['system']?.length ?? 0}, '
          '小说开关:$_novelEnabled, 系统开关:$_systemEnabled)');
    }
  }

  /// 强制刷新敏感词缓存（带锁，防止并发）
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await _loadSwitches();
      await _loadWords();
      if (kDebugMode) debugPrint('🔄 敏感词缓存已刷新');
    } finally {
      _isRefreshing = false;
    }
  }

  /// ==================== 数据加载 ====================

  /// 加载分类开关状态
  Future<void> _loadSwitches() async {
    try {
      final response = await ApiClient.get(
        'sensitive_word_configs',
        select: 'config_key,config_value',
        limit: null,
      );

      if (response.isSuccess && response.data != null) {
        for (final config in response.data!) {
          if (config['config_key'] == 'novel_enabled') {
            _novelEnabled = config['config_value'] == 'true';
          } else if (config['config_key'] == 'system_enabled') {
            _systemEnabled = config['config_value'] == 'true';
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 加载敏感词开关失败');
    }
  }

  /// 加载敏感词列表
  Future<void> _loadWords() async {
    try {
      final response = await ApiClient.get(
        'sensitive_words',
        select: 'id,word,category,level,replace_word,match_mode,is_active,hit_count',
        filters: {'is_active': 'eq.true'},
        limit: null,
      );

      if (response.isSuccess && response.data != null) {
        _wordCache.clear();

        for (final item in response.data!) {
          final word = SensitiveWordModel.fromJson(item);
          _wordCache.putIfAbsent(word.category, () => []).add(word);
        }

        _lastFetch = DateTime.now();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 加载敏感词列表失败');
    }
  }

  /// ==================== 公共接口 ====================

  /// 检查文本是否包含敏感词（小说分类）
  /// 用于小说内容发布前检测
  Future<SensitiveWordCheckResult> checkNovelContent(String text) async {
    return _checkText(text, 'novel');
  }

  /// 检查文本是否包含敏感词（系统分类）
  /// 用于用户评论、昵称、简介等检测
  Future<SensitiveWordCheckResult> checkSystemContent(String text) async {
    return _checkText(text, 'system');
  }

  /// 通用检测（同时检测两个分类）
  Future<SensitiveWordCheckResult> checkAll(String text) async {
    // 先检查是否需要检测
    if (!_novelEnabled && !_systemEnabled) {
      return SensitiveWordCheckResult.safe(text);
    }

    final novelResult = await _checkText(text, 'novel');
    final systemResult = await _checkText(text, 'system');

    // 合并结果
    final allMatched = [...novelResult.matchedWords, ...systemResult.matchedWords];
    if (allMatched.isEmpty) {
      return SensitiveWordCheckResult.safe(text);
    }

    // 判断是否有 block 级别
    final hasBlock = allMatched.any((w) => w.level == 'block');
    final processedText = _processText(text, allMatched);

    return SensitiveWordCheckResult(
      hasSensitive: true,
      isBlocked: hasBlock,
      processedText: processedText,
      matchedWords: allMatched,
      actionTaken: hasBlock ? 'blocked' : 'replaced',
    );
  }

  /// 同步检查小说内容（需先调用 initialize）
  SensitiveWordCheckResult checkNovelContentSync(String text) {
    return _checkTextSync(text, 'novel');
  }

  /// 同步检查系统内容（需先调用 initialize）
  SensitiveWordCheckResult checkSystemContentSync(String text) {
    return _checkTextSync(text, 'system');
  }

  /// ==================== 内部方法 ====================

  /// 异步检查文本
  Future<SensitiveWordCheckResult> _checkText(String text, String category) async {
    // 检查开关
    if (!_isCategoryEnabled(category)) {
      return SensitiveWordCheckResult.safe(text);
    }

    // 检查缓存是否过期，自动刷新（带锁）
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inHours >= _cacheHours) {
      await refresh();
    }

    return _checkTextSync(text, category);
  }

  /// 同步检查文本（核心逻辑）
  SensitiveWordCheckResult _checkTextSync(String text, String category) {
    if (!_isCategoryEnabled(category)) {
      return SensitiveWordCheckResult.safe(text);
    }

    final words = _wordCache[category] ?? [];
    if (words.isEmpty) {
      return SensitiveWordCheckResult.safe(text);
    }

    final matchedWords = <SensitiveWordModel>[];

    for (final sw in words) {
      if (_isMatch(text, sw)) {
        matchedWords.add(sw);
      }
    }

    if (matchedWords.isEmpty) {
      return SensitiveWordCheckResult.safe(text);
    }

    final hasBlock = matchedWords.any((w) => w.level == 'block');
    final processedText = _processText(text, matchedWords);

    return SensitiveWordCheckResult(
      hasSensitive: true,
      isBlocked: hasBlock,
      processedText: processedText,
      matchedWords: matchedWords,
      actionTaken: hasBlock
          ? 'blocked'
          : matchedWords.any((w) => w.level == 'replace')
              ? 'replaced'
              : 'warned',
    );
  }

  /// 判断文本是否匹配敏感词
  bool _isMatch(String text, SensitiveWordModel sw) {
    final lowerText = text.toLowerCase();
    final lowerWord = sw.word.toLowerCase();
    switch (sw.matchMode) {
      case 'exact':
        // 完全匹配：文本与敏感词完全一致（去除首尾空格后比较）
        return lowerText.trim() == lowerWord.trim();
      case 'contains':
        // 包含匹配：文本中包含敏感词
        return lowerText.contains(lowerWord);
      case 'regex':
        try {
          return RegExp(sw.word, caseSensitive: false).hasMatch(text);
        } catch (e) {
          if (kDebugMode) debugPrint('正则匹配敏感词失败');
          return false;
        }
      default:
        return lowerText.contains(lowerWord);
    }
  }

  /// 处理文本（替换敏感词）
  String _processText(String text, List<SensitiveWordModel> matchedWords) {
    String result = text;

    for (final sw in matchedWords) {
      switch (sw.level) {
        case 'block':
          // block 级别：用 *** 替换
          result = result.replaceAll(
            RegExp(sw.word, caseSensitive: false),
            '***',
          );
          break;
        case 'replace':
          // replace 级别：用指定替换词替换
          final replaceWith = sw.replaceWord ?? '***';
          result = result.replaceAll(
            RegExp(sw.word, caseSensitive: false),
            replaceWith,
          );
          break;
        case 'warn':
          // warn 级别：不替换文本，仅标记
          break;
      }
    }

    return result;
  }

  /// 检查分类是否启用
  bool _isCategoryEnabled(String category) {
    return category == 'novel' ? _novelEnabled : _systemEnabled;
  }

  /// ==================== 日志记录 ====================

  /// 记录敏感词命中日志到 Supabase（实现见 sensitive_word_logger.dart）
  Future<void> logHit({
    required SensitiveWordModel word,
    required String source,
    String? sourceId,
    String? userId,
    String? contentSnippet,
    required String actionTaken,
  }) =>
      logSensitiveWordHit(
        word: word,
        source: source,
        sourceId: sourceId,
        userId: userId,
        contentSnippet: contentSnippet,
        actionTaken: actionTaken,
      );

  /// ==================== 便捷方法 ====================

  /// 检查并处理文本（一步到位）
  /// 返回处理后的文本，如果不需要处理则返回原文
  /// 同时自动记录命中日志
  Future<String> filterAndLog({
    required String text,
    required String category,
    required String source,
    String? sourceId,
    String? userId,
  }) async {
    final result = category == 'novel'
        ? await checkNovelContent(text)
        : await checkSystemContent(text);

    if (result.hasSensitive) {
      // 异步记录日志（不阻塞主流程）
      for (final word in result.matchedWords) {
        logHit(
          word: word,
          source: source,
          sourceId: sourceId,
          userId: userId,
          contentSnippet: text,
          actionTaken: result.actionTaken,
        );
      }
    }

    return result.processedText;
  }

  /// 获取开关状态
  bool isNovelEnabled() => _novelEnabled;
  bool isSystemEnabled() => _systemEnabled;

  /// 清除缓存
  void clearCache() {
    _wordCache.clear();
    _lastFetch = null;
    _initialized = false;
  }
}
