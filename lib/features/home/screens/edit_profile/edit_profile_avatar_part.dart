part of './edit_profile_screen.dart';

/// 头像相关逻辑（选图裁剪上传 / 预设 / 历史恢复 / 应用 URL）抽为 mixin，
/// 避免 [_EditProfileScreenState] 超 400 行（膨胀修复）。
///
/// 约束 `on State<EditProfileScreen>`：可直接使用 context / mounted / setState，
/// 并持有头像相关字段（其它资料字段仍留在主 State）。
mixin _EditProfileAvatarMixin on State<EditProfileScreen> {
  String? _userId;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

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
}
