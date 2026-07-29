import 'package:flutter/material.dart';
import '../../avatar_presets.dart';
import '../../avatar_render.dart';
part 'avatar_preset_page_parts.dart';
part 'avatar_preset_grid.dart';
part 'avatar_preset_tone.dart';

/// 编辑资料 - 预设头像选择页面
/// 支持：风格自选（[kAvatarStyles]）、7 个主色调 + 单条「色调」滑动条自定义背景色、
/// 「换一批」（重新生成一批网络头像）；点选头像仅暂存，需点右上角「确认」才写入 avatar_url；
/// 重新打开时根据 [currentUrl] 回显风格 / 色调 / 头像。头像一律走网络 DiceBear URL
/// （背景色由服务端渲染），[cached_network_image] 负责磁盘缓存。
class AvatarPresetPage extends StatefulWidget {
  final String? currentUrl;

  const AvatarPresetPage({super.key, this.currentUrl});

  @override
  State<AvatarPresetPage> createState() => _AvatarPresetPageState();
}
