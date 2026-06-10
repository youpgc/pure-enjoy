import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// 敏感词模型
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

  /// ==================== 初始化 ====================

  /// 初始化服务：加载敏感词和开关状态
  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSwitches();
    await _loadWords();
    _initialized = true;
    debugPrint('✅ 敏感词服务初始化完成 '
        '(小说:${_wordCache['novel']?.length ?? 0}, '
        '系统:${_wordCache['system']?.length ?? 0}, '
        '小说开关:${_novelEnabled}, 系统开关:${_systemEnabled})');
  }

  /// 强制刷新敏感词缓存
  Future<void> refresh() async {
    await _loadSwitches();
    await _loadWords();
    debugPrint('🔄 敏感词缓存已刷新');
  }

  /// ==================== 数据加载 ====================

  /// 加载分类开关状态
  Future<void> _loadSwitches() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/sensitive_word_configs?select=config_key,config_value',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> configs = jsonDecode(response.body);
        for (final config in configs) {
          if (config['config_key'] == 'novel_enabled') {
            _novelEnabled = config['config_value'] == 'true';
          } else if (config['config_key'] == 'system_enabled') {
            _systemEnabled = config['config_value'] == 'true';
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 加载敏感词开关失败: $e');
    }
  }

  /// 加载敏感词列表
  Future<void> _loadWords() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/sensitive_words?is_active=eq.true&select=id,word,category,level,replace_word,match_mode,is_active,hit_count',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _wordCache.clear();

        for (final item in data) {
          final word = SensitiveWordModel.fromJson(item as Map<String, dynamic>);
          _wordCache.putIfAbsent(word.category, () => []).add(word);
        }

        _lastFetch = DateTime.now();
      }
    } catch (e) {
      debugPrint('❌ 加载敏感词列表失败: $e');
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

    // 检查缓存是否过期，自动刷新
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
          debugPrint('正则匹配敏感词失败: $e');
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

  /// 记录敏感词命中日志到 Supabase
  /// [word] 命中的敏感词
  /// [category] 分类
  /// [source] 来源类型
  /// [sourceId] 来源记录ID
  /// [userId] 用户ID
  /// [contentSnippet] 内容片段
  /// [actionTaken] 处理动作
  Future<void> logHit({
    required SensitiveWordModel word,
    required String source,
    String? sourceId,
    String? userId,
    String? contentSnippet,
    required String actionTaken,
  }) async {
    try {
      // 截取内容片段（前后各50字符）
      String? snippet;
      if (contentSnippet != null && contentSnippet.length > 100) {
        final index = contentSnippet.toLowerCase().indexOf(word.word.toLowerCase());
        if (index >= 0) {
          final start = (index - 50).clamp(0, contentSnippet.length);
          final end = (index + word.word.length + 50).clamp(0, contentSnippet.length);
          snippet = contentSnippet.substring(start, end);
        } else {
          snippet = '${contentSnippet.substring(0, 50)}...';
        }
      } else {
        snippet = contentSnippet;
      }

      await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/sensitive_word_logs'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'word_id': word.id,
          'word': word.word,
          'category': word.category,
          'source': source,
          'source_id': sourceId,
          'user_id': userId,
          'content_snippet': snippet,
          'action_taken': actionTaken,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      // 更新命中次数（异步，不等待）
      _incrementHitCount(word.id);
    } catch (e) {
      debugPrint('❌ 记录敏感词日志失败: $e');
    }
  }

  /// 增加敏感词命中次数（使用 RPC 原子更新）
  Future<void> _incrementHitCount(String wordId) async {
    try {
      // 使用 RPC 函数原子更新命中次数，避免 N+1 查询问题
      final response = await http.post(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/rpc/increment_sensitive_word_hit_count',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'word_id': wordId,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ 更新命中次数失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 更新命中次数失败: $e');
    }
  }

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
