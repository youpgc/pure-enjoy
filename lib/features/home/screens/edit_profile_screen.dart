import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';

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
  final _occupationController = TextEditingController();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();

  // 用户数据
  Map<String, dynamic>? _userData;
  String? _userId;
  String? _avatarUrl;
  String? _gender;
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
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _birthdayController.dispose();
    _occupationController.dispose();
    _companyController.dispose();
    _websiteController.dispose();
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

      final result = await ApiClient.get(
        'users',
        filters: {'id': 'eq.$userId'},
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          setState(() {
            _userData = data.first as Map<String, dynamic>;
            _initializeControllers();
          });
        }
      } else {
        _showError('加载用户数据失败: ${result.statusCode}');
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
    _occupationController.text = _userData!['occupation'] ?? '';
    _companyController.text = _userData!['company'] ?? '';
    _websiteController.text = _userData!['website'] ?? '';
    _gender = _userData!['gender'] ?? '保密';
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

      // 读取文件字节
      final bytes = await file.readAsBytes();

      // 上传到 Supabase Storage（使用原始 http，因为文件上传需要发送原始字节）
      final uploadResponse = await http.post(
        Uri.parse('${SupabaseConfig.url}/storage/v1/object/avatars/$fileName'),
        headers: {
          ...SupabaseConfig.headers,
          'Content-Type': 'image/$fileExt',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        throw Exception('上传失败: HTTP ${uploadResponse.statusCode}');
      }

      // 获取公开URL
      final publicUrl = '${SupabaseConfig.url}/storage/v1/object/public/avatars/$fileName';

      // 更新用户头像URL
      final updateResult = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$_userId'},
        body: {
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (updateResult.isSuccess) {
        setState(() => _avatarUrl = publicUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像更新成功')),
          );
        }
      } else {
        throw Exception('更新头像URL失败: ${updateResult.statusCode}');
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

  /// 选择生日
  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthdayController.text.isNotEmpty
          ? DateTime.tryParse(_birthdayController.text) ?? DateTime(2000)
          : DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  /// 选择性别
  void _selectGender() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('男'),
              leading: const Icon(Icons.male),
              onTap: () {
                setState(() => _gender = '男');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('女'),
              leading: const Icon(Icons.female),
              onTap: () {
                setState(() => _gender = '女');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('保密'),
              leading: const Icon(Icons.lock_outline),
              onTap: () {
                setState(() => _gender = '保密');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
        'gender': _gender ?? '保密',
        'occupation': _occupationController.text.trim(),
        'company': _companyController.text.trim(),
        'website': _websiteController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await ApiClient.patch(
        'users',
        filters: {'id': 'eq.$_userId'},
        body: updateData,
      );

      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showError('保存失败: ${result.statusCode}');
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
        SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
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
                                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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

                  // 个人信息
                  _buildSectionTitle('个人信息'),
                  _buildGenderSelector(),
                  _buildDatePickerField(
                    controller: _birthdayController,
                    label: '生日',
                    hint: '选择生日',
                    icon: Icons.cake_outlined,
                    onTap: _selectBirthday,
                  ),
                  _buildTextField(
                    controller: _locationController,
                    label: '所在地',
                    hint: '请输入所在城市',
                    icon: Icons.location_on_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 职业信息
                  _buildSectionTitle('职业信息'),
                  _buildTextField(
                    controller: _occupationController,
                    label: '职业',
                    hint: '请输入职业',
                    icon: Icons.work_outline,
                  ),
                  _buildTextField(
                    controller: _companyController,
                    label: '公司/组织',
                    hint: '请输入公司或组织名称',
                    icon: Icons.business_outlined,
                  ),
                  _buildTextField(
                    controller: _websiteController,
                    label: '个人网站',
                    hint: 'https://example.com',
                    icon: Icons.link_outlined,
                    keyboardType: TextInputType.url,
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

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _selectGender,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '性别',
            prefixIcon: const Icon(Icons.people_outline),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            border: const OutlineInputBorder(),
          ),
          child: Text(
            _gender ?? '保密',
            style: TextStyle(
              color: _gender == null ? Theme.of(context).colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ),
    );
  }
}
