import 'package:flutter/material.dart';
import '../avatar_render.dart';

/// 编辑资料 - 区块标题
class ProfileSectionTitle extends StatelessWidget {
  final String title;

  const ProfileSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
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
}

/// 编辑资料 - 通用文本输入框
class ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const ProfileTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
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

/// 编辑资料 - 日期选择输入框
class ProfileDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const ProfileDateField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// 编辑资料 - 性别选择
class ProfileGenderSelector extends StatelessWidget {
  final String? gender;
  final VoidCallback onTap;

  const ProfileGenderSelector({
    super.key,
    required this.gender,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: '性别',
            prefixIcon: Icon(Icons.people_outline),
            suffixIcon: Icon(Icons.arrow_drop_down),
            border: OutlineInputBorder(),
          ),
          child: Text(
            gender ?? '保密',
            style: TextStyle(
              color: gender == null ? Theme.of(context).colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 编辑资料 - 头像区域
class ProfileAvatarSection extends StatelessWidget {
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback onPickUpload;
  final VoidCallback onPickPreset;
  final VoidCallback onPickUploadHistory;
  final VoidCallback onPickPresetHistory;

  const ProfileAvatarSection({
    super.key,
    required this.avatarUrl,
    required this.isUploading,
    required this.onPickUpload,
    required this.onPickPreset,
    required this.onPickUploadHistory,
    required this.onPickPresetHistory,
  });

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册上传'),
              onTap: () {
                Navigator.pop(ctx);
                onPickUpload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('历史上传头像'),
              onTap: () {
                Navigator.pop(ctx);
                onPickUploadHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.face_outlined),
              title: const Text('选择预设头像'),
              onTap: () {
                Navigator.pop(ctx);
                onPickPreset();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('历史预设头像'),
              onTap: () {
                Navigator.pop(ctx);
                onPickPresetHistory();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = resolveAvatar(avatarUrl);
    final tint = resolved.bg != null ? avatarHexToColor(resolved.bg!) : null;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: isUploading ? null : () => _showOptions(context),
                child: avatarUrl == null
                    ? CircleAvatar(
                        radius: 50,
                        backgroundColor: tint ?? colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : cachedAvatarCircle(
                        url: avatarUrl!,
                        radius: 50,
                        tint: tint ?? colorScheme.primaryContainer,
                        colorScheme: colorScheme,
                      ),
              ),
              if (isUploading)
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
            onPressed: isUploading ? null : () => _showOptions(context),
            child: const Text('更换头像'),
          ),
        ],
      ),
    );
  }
}
