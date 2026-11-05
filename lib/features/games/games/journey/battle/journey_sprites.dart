import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 西行·战斗精灵缓存：SVG → ui.Picture（Flame Canvas 直接绘制）。
/// 对局页进入时 warmUp 预热；单资源失败记 null，渲染层走几何兜底，
/// 不因素材缺失阻塞对局。
class JourneySprites {
  JourneySprites._();

  static final Map<String, ui.Picture?> _cache = <String, ui.Picture?>{};

  // 资源路径拼装（与 assets/games/journey/ 下文件一一对应）
  static String monster(String code) => 'assets/games/journey/monster_$code.svg';
  static String pickup(String kind) => 'assets/games/journey/pickup_$kind.svg';
  static String weapon(String code) => 'assets/games/journey/weapon_$code.svg';
  static String character(String code) => 'assets/games/journey/char_$code.svg';

  /// 预热一批键；重复调用自动去重；并行加载（进关精灵数量多时显著提速）。
  static Future<void> warmUp(
    BuildContext context,
    Iterable<String> keys,
  ) async {
    final pending =
        keys.where((k) => !_cache.containsKey(k)).toSet();
    if (pending.isEmpty) return;
    final entries = await Future.wait(pending
        .map((k) async => MapEntry<String, ui.Picture?>(k, await _load(context, k))));
    _cache.addEntries(entries);
  }

  static Future<ui.Picture?> _load(BuildContext context, String key) async {
    try {
      final info = await vg.loadPicture(SvgAssetLoader(key), context);
      return info.picture;
    } catch (_) {
      return null;
    }
  }

  /// 取已预热的精灵（未预热/失败返回 null）。
  static ui.Picture? get(String key) => _cache[key];

  /// 在 [canvas] 上按 [dstRect] 绘制精灵。
  /// [srcWidth]/[srcHeight] 为该 SVG 的 viewBox 尺寸（方形资源两者相同）；
  /// 两轴独立缩放以正确支持非方形视箱（如角色立绘 220×300）。
  static void draw(
    Canvas canvas,
    ui.Picture? picture, {
    required Rect dstRect,
    required double srcWidth,
    required double srcHeight,
  }) {
    if (picture == null) return;
    if (srcWidth <= 0 || srcHeight <= 0) return;
    canvas.save();
    canvas.translate(dstRect.left, dstRect.top);
    canvas.scale(dstRect.width / srcWidth, dstRect.height / srcHeight);
    canvas.drawPicture(picture);
    canvas.restore();
  }
}
