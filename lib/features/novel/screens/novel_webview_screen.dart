import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 应用内 WebView 阅读页（聚合阅读：打开来源页，不存正文）。
///
/// 仅用于聚合小说（带 sourceUrl 但无本地章节）。当来源无可靠原生 deeplink
/// 或 deeplink 唤起失败时，在此页内直接打开来源站点，让用户在自家设备登录
/// 原平台阅读。提供「在浏览器打开 / 刷新 / 重试」兜底。
class NovelWebViewScreen extends StatefulWidget {
  /// 来源页地址（聚合锚点）
  final String url;

  /// 顶栏标题（取小说书名）
  final String title;

  const NovelWebViewScreen({super.key, required this.url, required this.title});

  @override
  State<NovelWebViewScreen> createState() => _NovelWebViewScreenState();
}

class _NovelWebViewScreenState extends State<NovelWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _isLoading = false;
            _hasError = true;
          }),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// 失败时回退到系统浏览器打开
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: '在浏览器打开',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('页面加载失败，可重试或在浏览器打开'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _controller.reload(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
