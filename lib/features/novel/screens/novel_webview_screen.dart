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

  /// 来源展示名（合规标注，如「纵横」「飞卢」），为空则不显示
  final String? sourceName;

  const NovelWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.sourceName,
  });

  @override
  State<NovelWebViewScreen> createState() => _NovelWebViewScreenState();
}

class _NovelWebViewScreenState extends State<NovelWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  // 顶部合规信息条是否仍展示（用户可手动收起）
  late bool _showSourceNotice;

  // 移动端 UA：让原站渲染移动阅读版式，体验更接近原生阅读器（零风险、纯前端）
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _showSourceNotice = widget.sourceName != null && widget.sourceName!.isNotEmpty;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.sourceName != null && widget.sourceName!.isNotEmpty)
              Text(
                '来源：${widget.sourceName}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
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
      body: Column(
        children: [
          // 顶部合规信息条：明确内容来自原平台、纯享仅作跳转（可收起）
          if (_showSourceNotice && !_hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '内容由「${widget.sourceName}」提供，纯享不存储正文，请在原平台阅读或登录。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showSourceNotice = false),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
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
          ),
        ],
      ),
    );
  }
}
