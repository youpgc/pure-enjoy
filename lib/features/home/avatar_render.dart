/// 头像渲染层：网络为主，[cached_network_image] 磁盘缓存。
///
/// 设计：
/// - 所有头像均使用规范 DiceBear URL（背景色由服务端 backgroundColor 渲染），
///   任意客户端（app / 后台 / 网页）都能直接加载，无任何本地资源依赖。
/// - 显示经 [CachedNetworkImageProvider] 命中磁盘缓存，进入页面静默渲染、
///   已看过的头像离线可显示；首次加载走网络。
/// - 历史兼容：早期「本地令牌」(avt:) 与「面板池」(pool_ 种子) URL 都还原为
///   真实 DiceBear URL 走网络，避免旧头像断裂。
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'avatar_presets.dart';

/// 头像 hex 背景色 -> Color
Color avatarHexToColor(String hex) =>
    Color(int.parse('ff${hex.replaceAll('#', '')}', radix: 16));

/// 渲染解析结果
class ResolvedAvatar {
  /// 可直接用于 [CircleAvatar.backgroundImage] 的图像源（已含服务端渲染的背景色）
  final ImageProvider image;

  /// 建议叠加的兜底背景色 hex（透明风格无 backgroundColor 时用作彩色圆底；null = 不叠加）
  final String? bg;

  const ResolvedAvatar({required this.image, this.bg});
}

/// 从 DiceBear URL 中解析 backgroundColor 参数
String? _bgFromUrl(String url) {
  try {
    return Uri.parse(url).queryParameters['backgroundColor'];
  } catch (_) {
    return null;
  }
}

/// 把早期「本地令牌」avt:<styleKey>:<index>:<bg> 还原为规范 DiceBear URL。
/// 仍用确定性的 pool_<key>_<index> 种子（与后台/网页一致），走网络加载。
String? tokenToUrl(String token) {
  final parts = token.split(':');
  if (parts.length < 4 || parts[0] != 'avt') return null;
  final styleKey = parts[1];
  final bg = parts[3].isNotEmpty ? parts[3] : null;
  return diceBearUrl(
    style: styleKey,
    seed: 'pool_${styleKey}_${parts[2]}',
    backgroundColor: bg,
  );
}

/// 把保存值（本地令牌 / DiceBear URL / null）解析为可渲染头像。
/// [saved] 为 null / 空时回退到默认风格第 0 张（网络 URL）。
ResolvedAvatar resolveAvatar(String? saved) {
  if (saved == null || saved.isEmpty) {
    final def = kDefaultStyle;
    final url = diceBearUrl(
      style: def.key,
      seed: 'pool_${def.key}_0',
      backgroundColor: def.defaultBg,
    );
    return ResolvedAvatar(
      image: CachedNetworkImageProvider(url),
      bg: def.defaultBg,
    );
  }
  // 早期本地令牌：还原为真实 URL 走网络
  if (saved.startsWith('avt:')) {
    final url = tokenToUrl(saved);
    if (url != null) {
      return ResolvedAvatar(
        image: CachedNetworkImageProvider(url),
        bg: _bgFromUrl(url),
      );
    }
  }
  // 否则视为 DiceBear URL（含旧版 / pool_ 种子 URL）
  return ResolvedAvatar(
    image: CachedNetworkImageProvider(saved),
    bg: _bgFromUrl(saved),
  );
}

/// hex 背景色 -> 色相(H)，用于头像背景色调统一计算（饱和/明度由调用方固定）
HSVColor hsvFromHex(String hex) {
  final v = int.parse(hex.replaceAll('#', ''), radix: 16);
  final c = Color.fromARGB(
    255,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  );
  return HSVColor.fromColor(c);
}

/// 头像背景色调固定饱和/明度，保证任意色相都是柔和耐看的衬底
const double kAvatarToneSaturation = 0.7;
const double kAvatarToneValue = 0.92;

/// 网络头像圆形（DiceBear URL）：加载中显示转圈，出错回退 person 图标。
/// 用于头像网格与编辑页主预览，配合 [CachedNetworkImage] 的磁盘缓存。
Widget cachedAvatarCircle({
  required String url,
  required double radius,
  required Color tint,
  required ColorScheme colorScheme,
}) {
  return CachedNetworkImage(
    imageUrl: url,
    cacheKey: url,
    imageBuilder: (context, image) => CircleAvatar(
      radius: radius,
      backgroundColor: tint,
      backgroundImage: image,
    ),
    placeholder: (context, _) => CircleAvatar(
      radius: radius,
      backgroundColor: tint,
      child: SizedBox(
        width: radius * 0.55,
        height: radius * 0.55,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      ),
    ),
    errorWidget: (context, _, __) => CircleAvatar(
      radius: radius,
      backgroundColor: tint,
      child: Icon(
        Icons.person,
        size: radius * 0.9,
        color: colorScheme.onPrimaryContainer,
      ),
    ),
    fadeInDuration: const Duration(milliseconds: 150),
  );
}
