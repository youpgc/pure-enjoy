import 'package:flutter/material.dart';

import '../models/pet_models.dart';

/// 宠物主页场景层（2026-09-17 美化重做 + 拍板背景接入）
///
/// 与 App 全局主题解耦的独立界面感：
/// - [PetSceneBackground]：场景背景（2026-09-17 用户拍板选定
///   assets/pets/scenes/scene_dream.png 梦幻夜空·山/水/宠物屋/小路，
///   BoxFit.cover 竖版适配；程序化白日草地版本归档于文末注释，可回退）；
/// - [PetGoldBadge]：右上角金币胶囊；
/// - [PetBottomStatusCard]：沉底状态卡（名牌行 + 四维横排），状态类内容沉底展示。

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
        child: Container(
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
              const Icon(Icons.paid_outlined, size: 15, color: Color(0xFFF0A020)),
              const SizedBox(width: 4),
              Text('$gold',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A4632))),
            ],
          ),
        ),
      ),
    );
  }
}

/// 沉底状态卡：名牌行 + 四维横排（饱食/心情/亲密/经验）
class PetBottomStatusCard extends StatelessWidget {
  const PetBottomStatusCard({super.key, required this.pet});

  final PetBriefModel pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xCC2E2A24),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '${pet.name} · Lv.${pet.level} · ${pet.showNo} · 形态${pet.stage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF5EFE4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _stat('饱食', Icons.restaurant, pet.hunger)),
              Expanded(child: _stat('心情', Icons.mood, pet.mood)),
              Expanded(child: _stat('亲密', Icons.favorite, pet.intimacy)),
              Expanded(child: _stat('经验', Icons.trending_up, pet.exp)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, IconData icon, int value) {
    const accent = Color(0xFFFFD37E);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 3),
              Text('$label $value',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE8E0D0))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
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
