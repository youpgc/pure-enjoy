import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/novel_model.dart';
import '../screens/novel_reader_screen.dart';
import '../screens/novel_webview_screen.dart';

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
}

/// 外部跳转目标：deeplink（可空）与来源 web 地址。
class _ExternalTarget {
  final String? deeplink;
  final String web;

  _ExternalTarget({required this.deeplink, required this.web});
}
