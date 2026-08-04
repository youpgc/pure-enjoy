import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../services/storage_service.dart';
import '../../../../config.dart';
import '../../../../services/api_client.dart';
import '../../../../services/supabase_service.dart';
import '../avatar_crop_screen.dart';
import '../avatar_preset/avatar_preset_page.dart';
import '../avatar_history/avatar_history_page.dart';
import '../../avatar_presets.dart';
import '../../avatar_history_service.dart';
import './edit_profile_screen_content.dart';

part 'edit_profile_avatar_part.dart';

/// 编辑个人资料页面
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with _EditProfileAvatarMixin {
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
  final _heightController = TextEditingController();
  final _occupationController = TextEditingController();
  final _companyController = TextEditingController();
  final _websiteController = TextEditingController();

  // 用户数据
  Map<String, dynamic>? _userData;
  String? _gender;

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
    _heightController.dispose();
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
        filters: {
          ApiClient.userKey(userId): 'eq.$userId',
          'is_deleted': 'eq.false',
        },
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _userData = data.first;
            _initializeControllers();
          });
        }
      } else {
        _showError('加载用户数据失败: ${result.statusCode}');
      }
    } catch (e) {
      _showError('加载用户数据失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    _heightController.text = _userData!['height'] != null ? _userData!['height'].toString() : '';
    _occupationController.text = _userData!['occupation'] ?? '';
    _companyController.text = _userData!['company'] ?? '';
    _websiteController.text = _userData!['website'] ?? '';
    _gender = _userData!['gender'] ?? '保密';
    _avatarUrl = _userData!['avatar_url'];
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
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newUsername = _usernameController.text.trim();
      final newPhone = _phoneController.text.trim();

      // 校验用户名唯一性（排除当前用户）
      if (newUsername.isNotEmpty && newUsername != (_userData?['username'] ?? '')) {
        final checkResult = await ApiClient.get(
          'users',
          filters: {
            'username': 'eq.$newUsername',
            'id': 'neq.$_userId',
            'is_deleted': 'eq.false',
          },
          limit: 1,
        );
        if (checkResult.isSuccess && (checkResult.data?.isNotEmpty ?? false)) {
          _showError('用户名已被其他用户使用');
          setState(() => _isSaving = false);
          return;
        }
      }

      // 校验手机号唯一性（排除当前用户）
      if (newPhone.isNotEmpty && newPhone != (_userData?['phone'] ?? '')) {
        final checkResult = await ApiClient.get(
          'users',
          filters: {
            'phone': 'eq.$newPhone',
            'id': 'neq.$_userId',
            'is_deleted': 'eq.false',
          },
          limit: 1,
        );
        if (checkResult.isSuccess && (checkResult.data?.isNotEmpty ?? false)) {
          _showError('手机号已被其他用户使用');
          setState(() => _isSaving = false);
          return;
        }
      }

      final heightText = _heightController.text.trim();
      final updateData = {
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': newPhone,
        'username': newUsername,
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'height': heightText.isNotEmpty ? double.tryParse(heightText) : null,
        'gender': _gender ?? '保密',
        'occupation': _occupationController.text.trim(),
        'company': _companyController.text.trim(),
        'website': _websiteController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final result = await ApiClient.patchByFilter(
        'users',
        filters: {ApiClient.userKey(_userId!): 'eq.$_userId'},
        body: updateData,
      );

      if (result.isSuccess) {
        if (mounted) {
          showSnackBar(context, '保存成功');
          Navigator.pop(context, true);
        }
      } else {
        _showError('保存失败: ${result.statusCode}');
      }
    } catch (e) {
      _showError('保存失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      showSnackBar(context, message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditProfileContent(
      formKey: _formKey,
      isLoading: _isLoading,
      isSaving: _isSaving,
      avatarUrl: _avatarUrl,
      isUploadingAvatar: _isUploadingAvatar,
      gender: _gender,
      nicknameController: _nicknameController,
      usernameController: _usernameController,
      emailController: _emailController,
      phoneController: _phoneController,
      bioController: _bioController,
      heightController: _heightController,
      locationController: _locationController,
      occupationController: _occupationController,
      companyController: _companyController,
      websiteController: _websiteController,
      birthdayController: _birthdayController,
      onSaveProfile: _saveProfile,
      onPickUpload: _pickUploadAvatar,
      onPickPreset: _pickPresetAvatar,
      onPickUploadHistory: _pickUploadHistory,
      onPickPresetHistory: _pickPresetHistory,
      onSelectGender: _selectGender,
      onSelectBirthday: _selectBirthday,
    );
  }
}
