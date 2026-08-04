import 'package:flutter/foundation.dart';
import './api_client.dart';
import './sensitive_word_models.dart';

/// 敏感词命中日志与计数（从 SensitiveWordService 抽出，无实例状态依赖）
/// 与原类内实现逐字节一致。

/// 增加敏感词命中次数（使用 RPC 原子更新）
Future<void> incrementSensitiveWordHitCount(String wordId) async {
  try {
    // 使用 RPC 函数原子更新命中次数，避免 N+1 查询问题
    final response = await ApiClient.post(
      'rpc/increment_sensitive_word_hit_count',
      {
        'word_id': wordId,
      },
    );

    if (!response.isSuccess) {
      if (kDebugMode) debugPrint('❌ 更新命中次数失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ 更新命中次数失败');
  }
}

/// 记录敏感词命中日志到 Supabase
/// [word] 命中的敏感词
/// [source] 来源类型
/// [sourceId] 来源记录ID
/// [userId] 用户ID
/// [contentSnippet] 内容片段
/// [actionTaken] 处理动作
Future<void> logSensitiveWordHit({
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

    await ApiClient.post(
      'sensitive_word_logs',
      {
        'word_id': word.id,
        'word': word.word,
        'category': word.category,
        'source': source,
        'source_id': sourceId,
        'user_id': userId,
        'content_snippet': snippet,
        'action_taken': actionTaken,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    // 更新命中次数（异步，不等待）
    await incrementSensitiveWordHitCount(word.id);
  } catch (e) {
    if (kDebugMode) debugPrint('❌ 记录敏感词日志失败');
  }
}
