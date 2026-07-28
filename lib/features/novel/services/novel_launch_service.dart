import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';
import '../screens/novel_reader_screen.dart';
import '../screens/novel_webview_screen.dart';
import 'reading_history_service.dart';

/// 小说跳转路由服务（聚合阅读核心：阶段 1 路由层）。
///
/// 模型：仅存元数据、不存正文。按来源决定跳转方式：
/// - 无来源链接（自有书库，含本地章节）→ 打开内置阅读器 [NovelReaderScreen]；
/// - 有来源链接且来源已登记原生 scheme → 优先尝试唤起原生 App（deeplink），
///   失败回退应用内 WebView；
/// - 有来源链接但无可靠 deeplink → 应用内 WebView 打开来源页，失败再回退系统浏览器。
///
/// 路由逻辑集中在此，所有阅读入口（书架/详情/历史/首页）统一调用 [launch]。
class NovelLaunchService {
  NovelLaunchService._();

  static final NovelLaunchService instance = NovelLaunchService._();

  factory NovelLaunchService() => instance;

  /// 跳转阅读。
  ///
  /// [novel] 目标小说；[startChapter] 仅对内置阅读器生效（聚合阅读由来源站决定进度）。
  Future<void> launch(
    BuildContext context,
    NovelModel novel, {
    int startChapter = 1,
  }) async {
    // 自有书库：无来源链接 → 内置阅读器
    if (novel.sourceUrl == null || novel.sourceUrl!.isEmpty) {
      await _openInternalReader(context, novel, startChapter);
      return;
    }

    // 聚合小说：合规行为记录（计数 + 阅读历史 + 书架时间戳），不阻塞跳转。
    // 立场：仅记录「用户从本 App 跳出过」这一事实，不采集原平台内行为。
    _recordExternalReading(novel); // ignore: unawaited_futures

    // 聚合小说：按来源选择 deeplink / WebView
    final target = _resolveExternalTarget(novel);
    if (target.deeplink != null) {
      final opened = await _tryLaunchDeeplink(target.deeplink!);
      if (opened) return;
    }
    // WebView（应用内）兜底
    if (!context.mounted) return;
    await _openWebView(context, novel);
  }

  /// 打开内置阅读器
  Future<void> _openInternalReader(
    BuildContext context,
    NovelModel novel,
    int startChapter,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelReaderScreen(
          novel: novel,
          startChapter: startChapter,
        ),
      ),
    );
  }

  /// 打开应用内 WebView
  Future<void> _openWebView(BuildContext context, NovelModel novel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelWebViewScreen(
          url: novel.sourceUrl!,
          title: novel.title,
        ),
      ),
    );
  }

  /// 解析外部跳转目标：返回 deeplink（可空）与来源 web 地址。
  _ExternalTarget _resolveExternalTarget(NovelModel novel) {
    final source = (novel.source ?? '').toLowerCase();
    final url = novel.sourceUrl!;

    // 纵横：已知有原生 App，尝试 scheme 唤起；失败回退 WebView
    if (source.contains('zongheng') || source.contains('纵横')) {
      final bookId = _extractZonghengBookId(url);
      if (bookId != null) {
        return _ExternalTarget(
          deeplink: 'zongheng://book/detail/$bookId',
          web: url,
        );
      }
    }

    // 其它来源：应用内 WebView
    return _ExternalTarget(deeplink: null, web: url);
  }

  /// 从纵横来源链接中提取书号，兼容
  /// https://www.zongheng.com/detail/{id} 与
  /// https://book.zongheng.com/book/{id}.html
  String? _extractZonghengBookId(String url) {
    final match = RegExp(r'/(?:detail|book)/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  /// 尝试唤起原生 App；成功返回 true，否则回退。
  Future<bool> _tryLaunchDeeplink(String deeplink) async {
    try {
      final uri = Uri.parse(deeplink);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return launched;
      }
    } catch (_) {
      // 忽略异常，交由 WebView 兜底
    }
    return false;
  }

  /// 聚合小说外部阅读记录（合规指标）：跳转原平台时记三件事，任一失败不阻塞。
  ///
  /// ① `read_count` 原子自增 —— 走 security definer RPC
  ///    `fn_increment_novel_read_count`（客户端无 novels UPDATE 权限，
  ///    直接 PATCH 会被 RLS 静默拦截且有并发丢失）；
  /// ② `reading_history` 写一条「外部阅读」明细（chapter_order=0 表示
  ///    外部平台阅读、无章节语义），喂排行/推荐的行为输入；
  /// ③ `user_novels.last_read_at` 刷新（仅已在书架时），支撑「继续阅读」排序。
  Future<void> _recordExternalReading(NovelModel novel) async {
    if (novel.id.isEmpty) return;
    // ① 阅读计数（RPC 原子自增）
    try {
      await ApiClient.rpc(
        'fn_increment_novel_read_count',
        params: {'p_novel_id': novel.id},
      );
    } catch (_) {
      // 计数失败不影响阅读跳转
    }
    // ② 阅读历史明细（chapter_order=0 = 外部阅读，无章节/进度语义）
    try {
      await ReadingHistoryService().recordReading(
        novelId: novel.id,
        chapterId: null,
        chapterOrder: 0,
        readDurationSeconds: 0,
        progress: 0,
      );
    } catch (_) {
      // 历史写入失败不影响阅读跳转
    }
    // ③ 书架时间戳（仅已在书架的书，避免误建书架记录）
    try {
      final userId = SessionManager.instance.currentUserId;
      if (userId == null) return;
      final shelf = await ApiClient.get(
        'user_novels',
        filters: {'user_id': 'eq.$userId', 'novel_id': 'eq.${novel.id}'},
        columns: 'id',
        limit: 1,
      );
      if (shelf.isSuccess && shelf.data != null && shelf.data!.isNotEmpty) {
        await ApiClient.patch(
          'user_novels',
          {'last_read_at': DateTime.now().toUtc().toIso8601String()},
          id: shelf.data!.first['id'].toString(),
        );
      }
    } catch (_) {
      // 时间戳失败不影响阅读跳转
    }
  }
}

/// 外部跳转目标：deeplink（可空）与来源 web 地址。
class _ExternalTarget {
  final String? deeplink;
  final String web;

  _ExternalTarget({required this.deeplink, required this.web});
}
