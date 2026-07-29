import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import './edit_profile_widgets.dart';

/// {@template edit_profile_content}
/// [EditProfileScreen] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入的控制器与回调，不持有状态；所有表单/状态逻辑仍在原 State 中。
/// {@endtemplate}
class EditProfileContent extends StatelessWidget {
  /// {@macro edit_profile_content}
  const EditProfileContent({
    super.key,
    required this.formKey,
    required this.isLoading,
    required this.isSaving,
    required this.avatarUrl,
    required this.isUploadingAvatar,
    required this.gender,
    required this.nicknameController,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.bioController,
    required this.heightController,
    required this.locationController,
    required this.occupationController,
    required this.companyController,
    required this.websiteController,
    required this.birthdayController,
    required this.onSaveProfile,
    required this.onPickUpload,
    required this.onPickPreset,
    required this.onPickUploadHistory,
    required this.onPickPresetHistory,
    required this.onSelectGender,
    required this.onSelectBirthday,
  });

  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final bool isSaving;
  final String? avatarUrl;
  final bool isUploadingAvatar;
  final String? gender;

  final TextEditingController nicknameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController bioController;
  final TextEditingController heightController;
  final TextEditingController locationController;
  final TextEditingController occupationController;
  final TextEditingController companyController;
  final TextEditingController websiteController;
  final TextEditingController birthdayController;

  final VoidCallback onSaveProfile;
  final VoidCallback onPickUpload;
  final VoidCallback onPickPreset;
  final VoidCallback onPickUploadHistory;
  final VoidCallback onPickPresetHistory;
  final VoidCallback onSelectGender;
  final VoidCallback onSelectBirthday;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: isSaving ? null : onSaveProfile,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: LoadingWidget())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 头像区域
                  ProfileAvatarSection(
                    avatarUrl: avatarUrl,
                    isUploading: isUploadingAvatar,
                    onPickUpload: onPickUpload,
                    onPickPreset: onPickPreset,
                    onPickUploadHistory: onPickUploadHistory,
                    onPickPresetHistory: onPickPresetHistory,
                  ),
                  const SizedBox(height: 24),

                  // 基本信息
                  const ProfileSectionTitle('基本信息'),
                  ProfileTextField(
                    controller: nicknameController,
                    label: '昵称',
                    hint: '请输入昵称',
                    icon: Icons.person_outline,
                  ),
                  ProfileTextField(
                    controller: usernameController,
                    label: '用户名',
                    hint: '请输入用户名',
                    icon: Icons.account_circle_outlined,
                  ),
                  ProfileTextField(
                    controller: emailController,
                    label: '邮箱',
                    hint: '请输入邮箱',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  ProfileTextField(
                    controller: phoneController,
                    label: '手机号',
                    hint: '请输入手机号',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 16),

                  // 个人简介
                  const ProfileSectionTitle('个人简介'),
                  ProfileTextField(
                    controller: bioController,
                    label: '个性签名',
                    hint: '介绍一下自己',
                    icon: Icons.edit_note_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // 个人信息
                  const ProfileSectionTitle('个人信息'),
                  ProfileGenderSelector(gender: gender, onTap: onSelectGender),
                  ProfileDateField(
                    controller: birthdayController,
                    label: '生日',
                    hint: '选择生日',
                    icon: Icons.cake_outlined,
                    onTap: onSelectBirthday,
                  ),
                  ProfileTextField(
                    controller: heightController,
                    label: '身高',
                    hint: '请输入身高（cm）',
                    icon: Icons.height_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  ProfileTextField(
                    controller: locationController,
                    label: '所在地',
                    hint: '请输入所在城市',
                    icon: Icons.location_on_outlined,
                  ),

                  const SizedBox(height: 16),

                  // 职业信息
                  const ProfileSectionTitle('职业信息'),
                  ProfileTextField(
                    controller: occupationController,
                    label: '职业',
                    hint: '请输入职业',
                    icon: Icons.work_outline,
                  ),
                  ProfileTextField(
                    controller: companyController,
                    label: '公司/组织',
                    hint: '请输入公司或组织名称',
                    icon: Icons.business_outlined,
                  ),
                  ProfileTextField(
                    controller: websiteController,
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
