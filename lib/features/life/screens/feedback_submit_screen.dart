import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/supabase_service.dart';
import '../../../core/widgets/widgets.dart';

/// 提交问题反馈页面
class FeedbackSubmitScreen extends StatefulWidget {
  const FeedbackSubmitScreen({super.key});

  @override
  State<FeedbackSubmitScreen> createState() => _FeedbackSubmitScreenState();
}

class _FeedbackSubmitScreenState extends State<FeedbackSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'bug'; // 默认分类
  bool _isSubmitting = false;

  /// 分类选项
  static const Map<String, String> _categoryOptions = {
    'bug': 'Bug',
    'feature': '功能建议',
    'improvement': '体验优化',
    'other': '其他',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 提交反馈
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      showSnackBar(context, '请先登录', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/user_feedback'),
        headers: SupabaseConfig.writeHeaders,
        body: jsonEncode({
          'user_id': userId,
          'title': _titleController.text.trim(),
          'description': _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          'category': _category,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          showSnackBar(context, '反馈提交成功');
          Navigator.pop(context);
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, '提交失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提交反馈'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '问题标题',
                  hintText: '请简要描述问题',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v?.trim().isEmpty == true ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),

              // 分类选择
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: '分类',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categoryOptions.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 描述输入
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '问题描述（可选）',
                  hintText: '请详细描述问题或建议',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 32),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('提交反馈'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
