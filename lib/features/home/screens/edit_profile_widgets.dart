import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final VoidCallback onPick;

  const ProfileAvatarSection({
    super.key,
    required this.avatarUrl,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: 50,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
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
            onPressed: isUploading ? null : onPick,
            child: const Text('更换头像'),
          ),
        ],
      ),
    );
  }
}
