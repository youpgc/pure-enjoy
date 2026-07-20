import 'package:flutter/material.dart' hide ErrorWidget;
import '../../../services/api_client.dart';
import '../../../core/widgets/widgets.dart';

/// app_configs 进程内缓存：配置（用户协议/隐私政策等）几乎不变，
/// 按 configKey 缓存 30 分钟，避免每次进页都打 Supabase。
final Map<String, String> _appConfigCache = {};
final Map<String, DateTime> _appConfigCacheTime = {};
const Duration _appConfigCacheTtl = Duration(minutes: 30);

/// 富文本展示页面
/// 通过 configKey 从 Supabase app_configs 表查询对应配置内容并渲染
class RichTextPage extends StatefulWidget {
  final String configKey;
  final String title;

  const RichTextPage({super.key, required this.configKey, required this.title});

  @override
  State<RichTextPage> createState() => _RichTextPageState();
}

class _RichTextPageState extends State<RichTextPage> {
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    // 命中进程内缓存（30 分钟内）直接复用，省一次 Supabase 往返
    final cachedContent = _appConfigCache[widget.configKey];
    final cachedAt = _appConfigCacheTime[widget.configKey];
    if (cachedContent != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _appConfigCacheTtl) {
      if (mounted) {
        setState(() {
          _content = cachedContent;
          _loading = false;
        });
      }
      return;
    }

    try {
      final result = await ApiClient.get(
        'app_configs',
        filters: {'config_key': 'eq.${widget.configKey}'},
        columns: 'title,content',
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          final content = data[0]['content'] ?? '';
          _appConfigCache[widget.configKey] = content;
          _appConfigCacheTime[widget.configKey] = DateTime.now();
          setState(() {
            _content = content;
            _loading = false;
          });
        } else {
          setState(() {
            _error = '暂无内容';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请稍后重试';
          _loading = false;
        });
      }
    }
  }

  /// 简单的HTML标签去除方法
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<h[1-6]>'), '【')
        .replaceAll(RegExp(r'</h[1-6]>'), '】\n')
        .replaceAll(RegExp(r'<p>'), '')
        .replaceAll(RegExp(r'</p>'), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<strong>'), '')
        .replaceAll(RegExp(r'</strong>'), '')
        .replaceAll(RegExp(r'<em>'), '')
        .replaceAll(RegExp(r'</em>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: ErrorWidget(
                    message: _error!,
                    onRetry: _loadContent,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _stripHtml(_content),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
    );
  }
}
