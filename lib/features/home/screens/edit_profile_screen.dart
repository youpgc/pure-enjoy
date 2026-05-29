import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';
import '../../../config.dart';

/// 编辑个人资料页面
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // 表单控制器
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // 用户数据
  Map<String, dynamic>? _userData;
  String? _userId;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// 从接口加载用户数据
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        _showError('用户未登录');
        return;
      }
      _userId = userId;

      final response = await http.get(
        Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/users?id=eq.$userId&select=*',
        ),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _userData = data.first as Map<String, dynamic>;
            _initializeControllers();
          });
        }
      } else {
        _showError('加载用户数据失败: ${response.statusCode}');
      }
    } catch (e) {
      _showError('加载用户数据出错: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 初始化表单控制器
  void _initializeControllers() {
    if (_userData == null) return;

    _nicknameController.text = _userData!['nickname'] ?? '';
    _emailController.text = _userData!['email'] ?? '';
    _phoneController.text = _userData!['phone'] ?? '';
    _avatarUrl = _userData!['avatar_url'];
  }

  /// 选择并上传头像
  Future<void> _pickAndUploadAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // 读取文件字节
      final bytes = await file.readAsBytes();

      // 上传到 Supabase Storage
      final uploadResponse = await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/storage/v1/object/avatars/$fileName'),
        headers: {
          ...AuthService.instance.authHeaders,
          'Content-Type': 'image/$fileExt',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        throw Exception('上传失败: ${uploadResponse.statusCode}');
      }

      // 获取公开URL
      final publicUrl = '${AppConfig.supabaseUrl}/storage/v1/object/public/avatars/$fileName';

      // 更新用户头像URL
      final updateResponse = await http.patch(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/users?id=eq.$_userId'),
        headers: AuthService.instance.authHeaders,
        body: jsonEncode({
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (updateResponse.statusCode == 200 || updateResponse.statusCode == 204) {
        setState(() => _avatarUrl = publicUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像更新成功')),
          );
        }
      } else {
        throw Exception('更新头像URL失败: ${updateResponse.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败: $e')),
        );
      }
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  /// 保存用户资料
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http.patch(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/users?id=eq.$_userId'),
        headers: AuthService.instance.authHeaders,
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError('保存失败: ${response.statusCode}');
      }
    } catch (e) {
      _showError('保存出错: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 头像区域
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: colorScheme.onPrimaryContainer,
                                    )
                                  : null,
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.black.withOpacity(0.5),
                                  child: const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                          child: const Text('更换头像'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 基本信息
                  _buildSectionTitle('基本信息'),
                  _buildTextField(
                    controller: _nicknameController,
                    label: '昵称',
                    hint: '请输入昵称',
                    icon: Icons.person_outline,
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: '邮箱',
                    hint: '请输入邮箱',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: '手机号',
                    hint: '请输入手机号',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
