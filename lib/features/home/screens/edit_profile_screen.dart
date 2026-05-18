import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _genderController = TextEditingController();

  // 用户数据
  Map<String, dynamic>? _userData;
  String? _userId;

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
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _birthdayController.dispose();
    _genderController.dispose();
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
    _usernameController.text = _userData!['username'] ?? '';
    _bioController.text = _userData!['bio'] ?? '';
    _locationController.text = _userData!['location'] ?? '';
    _birthdayController.text = _userData!['birthday'] ?? '';
    _genderController.text = _userData!['gender'] ?? '';
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
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'gender': _genderController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http.patch(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/users?id=eq.$_userId'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
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
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // TODO: 更换头像
                          },
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
                    controller: _usernameController,
                    label: '用户名',
                    hint: '请输入用户名',
                    icon: Icons.account_circle_outlined,
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

                  const SizedBox(height: 16),

                  // 个人简介
                  _buildSectionTitle('个人简介'),
                  _buildTextField(
                    controller: _bioController,
                    label: '个性签名',
                    hint: '介绍一下自己',
                    icon: Icons.edit_note_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // 其他信息
                  _buildSectionTitle('其他信息'),
                  _buildTextField(
                    controller: _genderController,
                    label: '性别',
                    hint: '男/女/保密',
                    icon: Icons.people_outline,
                  ),
                  _buildTextField(
                    controller: _birthdayController,
                    label: '生日',
                    hint: 'YYYY-MM-DD',
                    icon: Icons.cake_outlined,
                  ),
                  _buildTextField(
                    controller: _locationController,
                    label: '所在地',
                    hint: '请输入所在城市',
                    icon: Icons.location_on_outlined,
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
