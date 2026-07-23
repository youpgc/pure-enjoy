import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/storage_service.dart';
import '../../../config.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import 'avatar_crop_screen.dart';
import 'edit_profile_widgets.dart';
import 'avatar_preset_page.dart';
import 'avatar_history_page.dart';
import '../avatar_presets.dart';
import '../avatar_history_service.dart';

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
  final _heightController = TextEditingController();
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

  /// 选择图片并裁剪后上传头像
  ///
  /// 遵循主流应用（微信 / WhatsApp / Instagram）范式：1:1 方形裁切 + 圆形遮罩 +
  /// 缩放手势 + 高清导出。选图后进入 [AvatarCropScreen]，裁切结果再上传到存储桶。
  Future<void> _pickUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      // 进入裁剪页，获取圆形裁切结果（Uint8List?）
      final cropped = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute(
          builder: (_) => AvatarCropScreen(imageBytes: bytes),
        ),
      );
      if (cropped == null) return;

      setState(() => _isUploadingAvatar = true);

      final fileName = '${_userId}_${DateTime.now().millisecondsSinceEpoch}.png';

      // 使用 StorageService 上传（统一走 HttpClient，禁止直接调用 http）
      final publicUrl = await StorageService.instance.uploadFile(
        bucket: AppConfig.avatarsBucket,
        path: 'avatars/$fileName',
        bytes: cropped,
        contentType: 'image/png',
      );

      // 更新用户头像URL
      final updateResult = await ApiClient.patchByFilter(
        'users',
        filters: {ApiClient.userKey(_userId!): 'eq.$_userId'},
        body: {
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (updateResult.isSuccess) {
        setState(() => _avatarUrl = publicUrl);
        // 同步会话缓存，确保“我的”页即时刷新
        await AuthService.instance.reloadCurrentUser();
        if (mounted) showSnackBar(context, '头像更新成功');
        // 记录到头像历史（上传类型，去重由服务端+本地双重保证）
        if (mounted) AvatarHistoryService.recordUpload(url: publicUrl);
      } else {
        throw Exception('更新头像URL失败: ${updateResult.statusCode}');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '头像上传失败，请稍后重试', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// 选择内置预设头像（DiceBear，免费、风格统一）
  ///
  /// 直接把预设头像 URL 写入 `users.avatar_url`，复用现有显示逻辑，无需上传文件。
  Future<void> _pickPresetAvatar() async {
      final selected = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => AvatarPresetPage(currentUrl: _avatarUrl),
        ),
      );
    if (selected == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final updateResult = await ApiClient.patchByFilter(
        'users',
        filters: {ApiClient.userKey(_userId!): 'eq.$_userId'},
        body: {
          'avatar_url': selected,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (updateResult.isSuccess) {
        setState(() => _avatarUrl = selected);
        await AuthService.instance.reloadCurrentUser();
        if (mounted) showSnackBar(context, '已选择预设头像');
        // 记录到头像历史（仅 DiceBear 预设头像，去重由服务端+本地双重保证）
        if (mounted) _recordAvatarHistory(selected);
      } else {
        throw Exception('更新头像URL失败: ${updateResult.statusCode}');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '设置失败，请稍后重试', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// 把用过的预设头像写入历史（去重：相同 URL 仅更新时间）。
  /// 仅记录 DiceBear 预设头像；上传头像不在历史范围内。
  Future<void> _recordAvatarHistory(String url) async {
    final parsed = parseDiceBearUrl(url);
    if (parsed == null) return;
    if (!kAvatarStyles.any((s) => s.key == parsed.style)) return;
    await AvatarHistoryService.record(
      url: url,
      styleKey: parsed.style,
      seed: parsed.seed,
      backgroundColor: parsed.bg,
    );
  }

  /// 把给定头像 URL 设为当前头像（恢复/选择），并同步会话缓存
  Future<void> _applyAvatarUrl(String url, {required String successMsg}) async {
    if (_userId == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final updateResult = await ApiClient.patchByFilter(
        'users',
        filters: {ApiClient.userKey(_userId!): 'eq.$_userId'},
        body: {
          'avatar_url': url,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (updateResult.isSuccess) {
        setState(() => _avatarUrl = url);
        await AuthService.instance.reloadCurrentUser();
        if (mounted) showSnackBar(context, successMsg);
      } else {
        throw Exception('更新头像URL失败: ${updateResult.statusCode}');
      }
    } catch (e) {
      if (mounted) showSnackBar(context, '设置失败，请稍后重试', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// 从历史预设头像页面选择并恢复一个预设头像
  Future<void> _pickPresetHistory() async {
    final selected = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => AvatarHistoryPage(currentUrl: _avatarUrl),
      ),
    );
    if (selected == null || !mounted) return;
    await _applyAvatarUrl(selected, successMsg: '已恢复历史头像');
    // 恢复即「使用过该头像」：写入历史；若仅改了色调（URL 不同）则生成新的一条记录
    if (mounted) _recordAvatarHistory(selected);
  }

  /// 从历史上传头像页面选择并恢复一个上传头像（对应上传头像逻辑：原样恢复，无色调）
  Future<void> _pickUploadHistory() async {
    final selected = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => AvatarUploadHistoryPage(currentUrl: _avatarUrl),
      ),
    );
    if (selected == null || !mounted) return;
    await _applyAvatarUrl(selected, successMsg: '已恢复历史头像');
    // 恢复即「使用过该头像」：写入上传历史；URL 不同（如换了文件）则生成新记录
    if (mounted) AvatarHistoryService.recordUpload(url: selected);
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
          ? const Center(child: LoadingWidget())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 头像区域
                  ProfileAvatarSection(
                    avatarUrl: _avatarUrl,
                    isUploading: _isUploadingAvatar,
                    onPickUpload: _pickUploadAvatar,
                    onPickPreset: _pickPresetAvatar,
                    onPickUploadHistory: _pickUploadHistory,
                    onPickPresetHistory: _pickPresetHistory,
                  ),
                  const SizedBox(height: 24),

                  // 基本信息
                  const ProfileSectionTitle('基本信息'),
                  ProfileTextField(
                    controller: _nicknameController,
                    label: '昵称',
                    hint: '请输入昵称',
                    icon: Icons.person_outline,
                  ),
                  ProfileTextField(
                    controller: _usernameController,
                    label: '用户名',
                    hint: '请输入用户名',
                    icon: Icons.account_circle_outlined,
                  ),
                  ProfileTextField(
                    controller: _emailController,
                    label: '邮箱',
                    hint: '请输入邮箱',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  ProfileTextField(
                    controller: _phoneController,
                    label: '手机号',
                    hint: '请输入手机号',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 16),

                  // 个人简介
                  const ProfileSectionTitle('个人简介'),
                  ProfileTextField(
                    controller: _bioController,
                    label: '个性签名',
                    hint: '介绍一下自己',
                    icon: Icons.edit_note_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // 个人信息
                  const ProfileSectionTitle('个人信息'),
                  ProfileGenderSelector(gender: _gender, onTap: _selectGender),
                  ProfileDateField(
                    controller: _birthdayController,
                    label: '生日',
                    hint: '选择生日',
                    icon: Icons.cake_outlined,
                    onTap: _selectBirthday,
                  ),
                  ProfileTextField(
                    controller: _heightController,
                    label: '身高',
                    hint: '请输入身高（cm）',
                    icon: Icons.height_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  ProfileTextField(
                    controller: _locationController,
                    label: '所在地',
                    hint: '请输入所在城市',
                    icon: Icons.location_on_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 职业信息
                  const ProfileSectionTitle('职业信息'),
                  ProfileTextField(
                    controller: _occupationController,
                    label: '职业',
                    hint: '请输入职业',
                    icon: Icons.work_outline,
                  ),
                  ProfileTextField(
                    controller: _companyController,
                    label: '公司/组织',
                    hint: '请输入公司或组织名称',
                    icon: Icons.business_outlined,
                  ),
                  ProfileTextField(
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

}
