import 'package:flutter/material.dart';

import '../models/pet_models.dart';
import 'pet_item_icon.dart';
/// 宠物主页场景层（2026-09-17 美化重做 + 拍板背景接入）
///
/// 与 App 全局主题解耦的独立界面感：
/// - [PetSceneBackground]：场景背景（2026-09-17 用户拍板选定
///   assets/pets/scenes/scene_dream.png 梦幻夜空·山/水/宠物屋/小路，
///   BoxFit.cover 竖版适配；程序化白日草地版本归档于文末注释，可回退）；
/// - [PetGoldBadge]：右上角金币胶囊；
/// - [PetBottomStatusCard]：沉底状态卡（名牌行 + 四维独立行），状态类内容沉底展示。

/// 独立场景背景（不随 App 主题变化，营造"宠物世界"界面感）。
///
/// 2026-10-09 背景主题购买替换（§11.1）：按 scene_code 分派渲染——
/// - `scene_dream`：梦幻夜空资产（默认，全员可用）；
/// - `scene_meadow`：程序化晨曦草甸（归档白日草地复活，零素材）；
/// - `scene_starry`：程序化星海之栏（零素材）；
/// 未知码/缺省回退 `scene_dream`（铁律 8）。后续资产类主题按 asset_ref 扩展。
class PetSceneBackground extends StatelessWidget {
  const PetSceneBackground({super.key, this.sceneCode = 'scene_dream'});

  final String sceneCode;

  @override
  Widget build(BuildContext context) {
    switch (sceneCode) {
      case 'scene_meadow':
        return const PetSceneBackgroundMeadow();
      case 'scene_starry':
        return const PetSceneBackgroundStarry();
      default:
        return Image.asset(
          'assets/pets/scenes/scene_dream.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
        );
    }
  }
}

/// 程序化星海之栏（scene_starry）：深空渐变 + 确定性星点 + 弦月 + 远山剪影。
/// 星点位置由序号决定（无随机状态，铁律：确定性渲染）。
class PetSceneBackgroundStarry extends StatelessWidget {
  const PetSceneBackgroundStarry({super.key});

  /// 确定性星点表（fx, fy, r, 亮度）——手排 24 颗，疏密有致
  static const _stars = <List<double>>[
    [0.06, 0.08, 1.4, 0.9], [0.14, 0.18, 1.0, 0.6], [0.22, 0.06, 1.8, 1.0],
    [0.31, 0.14, 1.1, 0.7], [0.38, 0.24, 1.3, 0.8], [0.47, 0.09, 1.0, 0.5],
    [0.55, 0.19, 1.6, 0.9], [0.63, 0.05, 1.1, 0.6], [0.70, 0.16, 1.4, 0.8],
    [0.78, 0.10, 1.0, 0.55], [0.86, 0.21, 1.7, 0.9], [0.94, 0.12, 1.1, 0.65],
    [0.10, 0.30, 1.0, 0.5], [0.27, 0.34, 1.2, 0.7], [0.44, 0.31, 1.0, 0.5],
    [0.60, 0.35, 1.2, 0.6], [0.76, 0.30, 1.0, 0.5], [0.92, 0.33, 1.2, 0.7],
    [0.18, 0.44, 1.0, 0.4], [0.52, 0.46, 1.0, 0.45], [0.84, 0.43, 1.0, 0.5],
    [0.36, 0.50, 0.9, 0.35], [0.67, 0.52, 0.9, 0.4], [0.05, 0.55, 0.9, 0.35],
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarryPainter(),
      size: Size.infinite,
    );
  }
}

class _StarryPainter extends CustomPainter {
  static const _top = Color(0xFF0B1026);
  static const _mid = Color(0xFF1B2550);
  static const _bottom = Color(0xFF2E3A6B);

  @override
  void paint(Canvas canvas, Size size) {
    // 深空渐变
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        sky,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_top, _mid, _bottom])
              .createShader(sky));

    // 星点
    for (final star in PetSceneBackgroundStarry._stars) {
      canvas.drawCircle(
        Offset(star[0] * size.width, star[1] * size.height),
        star[2],
        Paint()..color = Colors.white.withValues(alpha: star[3]),
      );
    }

    // 弦月（右上）
    final moonCenter = Offset(size.width * 0.80, size.height * 0.16);
    canvas.drawCircle(moonCenter, 34, Paint()..color = const Color(0xFFF5EFD8));
    final biteColor = Color.lerp(_top, _mid, 0.32)!;
    canvas.drawCircle(
        moonCenter.translate(-14, -8), 30, Paint()..color = biteColor);

    // 远山剪影（两重）
    final hill1 = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.66,
          size.width * 0.5, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.86,
          size.width, size.height * 0.74)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.74, size.width, size.height * 0.26),
        Paint()..color = const Color(0xFF141A38));
    canvas.drawPath(hill1, Paint()..color = const Color(0xFF1A2142));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 程序化晨曦草甸（scene_meadow）：白日草地归档复活，配色调暖为晨曦
class PetSceneBackgroundMeadow extends StatelessWidget {
  const PetSceneBackgroundMeadow({super.key});

  static const _skyTop = Color(0xFFFFE3B3);
  static const _skyBottom = Color(0xFFFFF6E3);
  static const _grassTop = Color(0xFFA8D48A);
  static const _grassBottom = Color(0xFF7CB860);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_skyTop, _skyBottom],
            stops: [0.0, 0.62]),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 晨曦太阳
          Positioned(
            right: 56,
            top: 70,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD98A),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFFD98A).withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 12),
                ],
              ),
            ),
          ),
          // 云两朵（程序化，同归档造型）
          Positioned(
            left: 40,
            top: 96,
            child: _cloud(92),
          ),
          Positioned(
            right: 130,
            top: 150,
            child: _cloud(68),
          ),
          // 草地
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.34,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [_grassTop, _grassBottom]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloud(double width) {
    final h = width * 0.52;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: _blob(width * 0.46, h * 0.62)),
          Positioned(
              left: width * 0.24,
              top: 0,
              child: _blob(width * 0.52, h * 0.78)),
          Positioned(
              right: 0, bottom: 0, child: _blob(width * 0.44, h * 0.58)),
        ],
      ),
    );
  }

  Widget _blob(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(h / 2),
        ),
      );
}

/// 右上角金币胶囊（与返回键分离）
///
/// 2026-09-17：有宠物时按钮列贴顶，金币核心 [PetGoldBadgeCore] 内联至右列
/// 首位避免重叠；本外壳仅无宠物分支使用。
class PetGoldBadge extends StatelessWidget {
  const PetGoldBadge({super.key, required this.gold});

  final int gold;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Padding(
        padding:
            EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6, right: 8),
        child: PetGoldBadgeCore(gold: gold),
      ),
    );
  }
}

/// 金币胶囊核心（白底圆角，可内联进按钮列）
class PetGoldBadgeCore extends StatelessWidget {
  const PetGoldBadgeCore({super.key, required this.gold});

  final int gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PetItemIcon(
              iconKey: 'ui_coin', fallback: Icons.paid_outlined, size: 15),
          const SizedBox(width: 4),
          Text('$gold',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A4632))),
        ],
      ),
    );
  }
}

/// 沉底状态卡：名牌行 + 五维独立行（饱食/心情/亲密/经验/健康，每条一行不并行）
///
/// 点击整卡打开属性面板（属性系统 Phase 2：四维/健康/性格/加点，见
/// pet_attributes_sheet.dart）。
/// 形态 0-2 → 幼年期/成长期/成年期（2026-10-10 转译）
String _stageName(int stage) =>
    const ['幼年期', '成长期', '成年期'][stage.clamp(0, 2)];

class PetBottomStatusCard extends StatelessWidget {
  const PetBottomStatusCard({
    super.key,
    required this.pet,
    this.expNeed,
    this.expMaxed = false,
    this.onTap,
  });

  final PetBriefModel pet;

  /// 升下一级所需经验（rpc_pet_summary config 同源计算，见 petExpNeed）。
  /// null（旧版服务端未下发曲线两键）时经验行回退旧的 /100 展示。
  final int? expNeed;

  /// 已达等级上限（level_max，服务端同源冻结 exp）：经验条满格 + 显示 MAX
  final bool expMaxed;

  /// 打开属性面板（null 时不可点）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xCC2E2A24),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // 编号（showNo）已隐藏；形态 0-2 转译幼年期/成长期/成年期
                    '${pet.name} · Lv.${pet.level} · ${_stageName(pet.stage)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF5EFE4)),
                  ),
                ),
                // 属性面板入口提示（整卡可点）
                const Icon(Icons.keyboard_arrow_up,
                    size: 16, color: Color(0xFFF5EFE4)),
              ],
            ),
            const SizedBox(height: 8),
            _statRow('饱食', 'ui_hunger', Icons.restaurant, pet.hunger),
            const SizedBox(height: 6),
            _statRow('心情', 'ui_mood', Icons.mood, pet.mood),
            const SizedBox(height: 6),
            _statRow('亲密', 'ui_bond', Icons.favorite, pet.intimacy),
            const SizedBox(height: 6),
            _statRow('经验', 'ui_exp', Icons.trending_up, pet.exp,
                max: expMaxed ? null : expNeed,
                forceFull: expMaxed,
                displayText: expMaxed
                    ? 'MAX'
                    : (expNeed == null ? null : '${pet.exp}/$expNeed')),
            const SizedBox(height: 6),
            // 健康行（状态值：历险失败惩罚扣减，恢复途径后续配置）
            _statRow('健康', 'ui_health', Icons.health_and_safety_outlined,
                pet.health),
          ],
        ),
      ),
    );
  }

  /// 单条状态行：图标 + 标签 + 进度条 + 数值（独占一行）
  ///
  /// [max] 为该行值域上限（缺省 100）；[displayText] 非空时数值格改显该文案
  /// （经验行 exp/need），格宽随之放宽。经验需求 >100（2 级起），写死 /100
  /// 会让条恒满——上限必须来自 summary config 同源曲线（petExpNeed）。
  Widget _statRow(String label, String iconKey, IconData fallback, int value,
      {int? max, bool forceFull = false, String? displayText}) {
    const accent = Color(0xFFFFD37E);
    final denom = (max == null || max <= 0) ? 100 : max;
    return Row(
      children: [
        PetItemIcon(iconKey: iconKey, fallback: fallback, size: 14),
        const SizedBox(width: 6),
        SizedBox(
          width: 26,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFFE8E0D0))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: forceFull ? 1.0 : (value / denom).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          // 数值格全行统一宽度：经验行 exp/need 与单值行（饱食 85 等）右端对齐，
          // 五条进度条右缘齐平；FittedBox 防高等级 '1094189813/1094189813' 溢出
          width: 64,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(displayText ?? '$value',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF5EFE4))),
          ),
        ),
      ],
    );
  }
}

/* ==================== 归档（2026-09-17 程序化白日草地背景，可回退） ====================

const Color _skyTop = Color(0xFFA9D7F5);
const Color _skyBottom = Color(0xFFE8F6E0);
const Color _grassTop = Color(0xFF9ED07E);
const Color _grassBottom = Color(0xFF7CB860);
const Color _sun = Color(0xFFFFE08A);

/// 独立场景背景（程序化：天空渐变 + 太阳 + 云朵 + 草地）
class PetSceneBackgroundFlat extends StatelessWidget {
  const PetSceneBackgroundFlat({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyBottom],
          stops: [0.0, 0.62],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            right: 56,
            top: 72,
            child: _SceneSun(size: 64),
          ),
          const Positioned(left: 40, top: 92, child: _SceneCloud(width: 92)),
          const Positioned(right: 130, top: 148, child: _SceneCloud(width: 68)),
          const Positioned(left: 150, top: 52, child: _SceneCloud(width: 54)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height * 0.34,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_grassTop, _grassBottom],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneSun extends StatelessWidget {
  const _SceneSun({this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _sun.withValues(alpha: 0.28),
      ),
      padding: EdgeInsets.all(size * 0.25),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: _sun),
      ),
    );
  }
}

class _SceneCloud extends StatelessWidget {
  const _SceneCloud({this.width = 80});

  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.52;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: _blob(width * 0.46, h * 0.62)),
          Positioned(left: width * 0.24, top: 0, child: _blob(width * 0.52, h * 0.78)),
          Positioned(right: 0, bottom: 0, child: _blob(width * 0.44, h * 0.58)),
        ],
      ),
    );
  }

  Widget _blob(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(h / 2),
        ),
      );
}

==================== 归档结束 ==================== */
