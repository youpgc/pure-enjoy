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

/// 独立场景背景（不随 App 主题变化，营造"宠物世界"界面感）
class PetSceneBackground extends StatelessWidget {
  const PetSceneBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/pets/scenes/scene_dream.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }
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
class PetBottomStatusCard extends StatelessWidget {
  const PetBottomStatusCard({super.key, required this.pet, this.onTap});

  final PetBriefModel pet;

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
                    '${pet.name} · Lv.${pet.level} · ${pet.showNo} · 形态${pet.stage}',
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
            _statRow('经验', 'ui_exp', Icons.trending_up, pet.exp),
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
  Widget _statRow(String label, String iconKey, IconData fallback, int value) {
    const accent = Color(0xFFFFD37E);
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
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF5EFE4))),
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
