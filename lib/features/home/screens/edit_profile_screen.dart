import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = AuthService.instance.currentUserId;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final result = await ApiClient.getOne(
        'users',
        filters: {'id': 'eq.$_userId'},
      );

      if (result.isSuccess) {
        final data = result.data!;
        setState(() {
          _nicknameController.text = data['nickname'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_userId == null) return;

    setState(() => _isSaving = true);

    try {
      final result = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$_userId'},
        body: {
          'nickname': _nicknameController.text,
          'bio': _bioController.text,
        },
      );

      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: ${result.errorMessage}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '简介',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
