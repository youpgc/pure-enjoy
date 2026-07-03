import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
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
  bool _isDictLoading = true;

  @override
  void initState() {
    super.initState();
    _initDict();
  }

  Future<void> _initDict() async {
    await DictService.instance.initialize();
    if (mounted) {
      setState(() => _isDictLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 提交反馈
  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final userId = AuthService.instance.currentUserId;
    final userNickname = AuthService.instance.currentUserName;
    if (userId == null) {
      showSnackBar(context, '请先登录', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiClient.post(
        'user_feedback',
        {
          'user_id': userId,
          'user_nickname': userNickname,
          'title': _titleController.text.trim(),
          'description': _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          'category': _category,
          'status': 'pending',
        },
      );

      if (result.isSuccess) {
        if (mounted) {
          showSnackBar(context, '反馈提交成功');
          Navigator.pop(context);
        }
      } else {
        throw Exception(result.errorMessage ?? '提交失败');
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
      body: _isDictLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                    Builder(builder: (context) {
                      final categoryOptions = DictService.instance.getItemsSync('feedback_category');
                      return DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: categoryOptions
                            .map((item) => DropdownMenuItem(
                                  value: item.code,
                                  child: Text(item.label),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      );
                    }),
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
