import 'package:flutter/material.dart';
import '../avatar_presets.dart';
import '../avatar_render.dart';
import '../avatar_history_service.dart';
import '../../../core/widgets/widgets.dart';
part 'avatar_history_page_parts.dart';

/// 预设头像历史（DiceBear，支持色调编辑）
/// 点「保存修改」即把当前预览（可能已改色调）恢复为当前头像，并回传给编辑页套用为
/// 当前头像且写入历史。
class AvatarHistoryPage extends StatelessWidget {
  final String? currentUrl;

  const AvatarHistoryPage({super.key, this.currentUrl});

  @override
  Widget build(BuildContext context) => _AvatarHistoryView(
        currentUrl: currentUrl,
        type: 'dicebear',
        toneEnabled: true,
        title: '历史头像',
        confirmLabel: '保存修改',
      );
}

/// 上传头像历史（完整图片 URL，无色调编辑）
/// 点「保存」把选中头像回传编辑页，由其套用为当前头像并写入历史。
class AvatarUploadHistoryPage extends StatelessWidget {
  final String? currentUrl;

  const AvatarUploadHistoryPage({super.key, this.currentUrl});

  @override
  Widget build(BuildContext context) => _AvatarHistoryView(
        currentUrl: currentUrl,
        type: 'upload',
        toneEnabled: false,
        title: '历史上传头像',
        confirmLabel: '保存',
      );
}

/// 头像历史通用页面（预设 / 上传共用）
///
/// 通过 [type] 决定拉取哪类记录（dicebear / upload）；[toneEnabled] 决定是否提供
/// 主色调编辑与「最终效果」预览（仅预设头像需要；上传头像为完整 URL，原样恢复）。
/// 历史网格渲染于标题与主色调（上传模式为预览）之间，最多 [_kHistoryRows] 行。
/// 进入「历史管理」：显示删除图标、禁用点选、隐藏选中高亮；进入时重置选中与色调。
class _AvatarHistoryView extends StatefulWidget {
  final String? currentUrl;
  final String type;
  final bool toneEnabled;
  final String title;
  final String confirmLabel;

  const _AvatarHistoryView({
    this.currentUrl,
    required this.type,
    required this.toneEnabled,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_AvatarHistoryView> createState() => _AvatarHistoryViewState();
}
