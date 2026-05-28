import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config.dart';

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
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/app_configs?config_key=eq.${widget.configKey}&select=title,content',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _content = data[0]['content'] ?? '';
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
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
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
              ? Center(child: Text(_error!))
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
