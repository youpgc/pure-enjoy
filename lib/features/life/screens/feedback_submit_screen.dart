import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class FeedbackSubmitScreen extends StatefulWidget {
  const FeedbackSubmitScreen({super.key});

  @override
  State<FeedbackSubmitScreen> createState() => _FeedbackSubmitScreenState();
}

class _FeedbackSubmitScreenState extends State<FeedbackSubmitScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
  }

  Future<void> _submitFeedback() async {
    if (_userId == null) return;
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题和内容')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiClient.post(
        'feedbacks',
        body: {
          'user_id': _userId,
          'title': _titleController.text,
          'content': _contentController.text,
          'status': 'pending',
        },
      );

      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('提交成功')),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('提交失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '请输入反馈标题',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '请详细描述您的问题或建议',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
