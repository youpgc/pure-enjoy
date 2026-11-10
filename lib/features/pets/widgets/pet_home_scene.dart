import 'dart:async';

import '../utils/pet_decay_display.dart';
import '../utils/pet_gold_format.dart';
import 'package:flutter/material.dart';

import '../models/pet_models.dart';
import 'pet_item_icon.dart';
/// 宠物主页场景层
///
/// 与 App 全局主题解耦的独立界面感
/// - [PetSceneBackground]：场景背景（选定
///  assets/pets/scenes/scene_dream.png 梦幻夜空·山/水/宠物屋/小路
/// BoxFit.cover 竖版适配；程序化白日草地版本归档于 pet_home_scene_archive.dart，可回退）；
/// - [PetGoldBadge]：右上角金币胶囊；
/// - [PetBottomStatusCard]：沉底状态卡（名牌行 + 四维独立行），状态类内容沉底展示。

/// 独立场景背景（不随 App 主题变化，营造"宠物世界"界面感）。
///
/// 背景主题购买替换：按 scene_code 分派资产渲染——文件名 = scene_code.png
/// （1024×1352 竖版已裁水印，BoxFit.cover 自适应）；未知码/缺省回退默认
/// `scene_dream`（铁律 8）。程序化晨曦草甸/星海之栏归档于 pet_home_scene_archive.dart，可回退。
class PetSceneBackground extends StatelessWidget {
  const PetSceneBackground({super.key, this.sceneCode = 'scene_dream'});

  final String sceneCode;

  /// 资产类场景码集合（新增主题 = 落图入包 + 服务端上架，此处补码）
  static const Set<String> assetScenes = <String>{
    'scene_dream',
    'scene_meadow',
    'scene_sakura',
    'scene_snow',
    'scene_beach',
    'scene_starry',
    'scene_glow',
    'scene_isle',
  };

  /// 场景图资源路径（未知码回落默认主题）——预热与渲染同源，防路径漂移
  static String assetPath(String code) =>
      'assets/pets/scenes/${assetScenes.contains(code) ? code : 'scene_dream'}.png';

  @override
  Widget build(BuildContext context) {
    final code = assetScenes.contains(sceneCode) ? sceneCode : 'scene_dream';
    return Image.asset(
      assetPath(code),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }
}

/// 右上角金币胶囊（与返回键分离）
///
/// 有宠物时按钮列贴顶：金币核心 [PetGoldBadgeCore] 内联至右列
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
          Text(petGoldLabel(gold),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A4632))),
        ],
      ),
    );
  }
}

/// 沉底状态卡：名牌行 + 四维独立行（饱食/心情/经验/健康，每条一行不并行；
///  亲密度只在详情面板展示)
///
/// 点击整卡打开属性面板（属性系统 Phase 2：四维/健康/性格/加点，见
///  pet_attributes_sheet.dart）。
/// 形态 0-2 → 幼年期/成长期/成年期
String _stageName(int stage) =>
    const ['幼年期', '成长期', '成年期'][stage.clamp(0, 2)];
class PetBottomStatusCard extends StatefulWidget {
  const PetBottomStatusCard({
    super.key,
    required this.pet,
    this.expNeed,
    this.expMaxed = false,
    this.weakHealthAt,
    this.decayHungerPerHour = 0,
    this.decayMoodPerHour = 0,
    this.statsAt,
    this.onTap,
  });

  final PetBriefModel pet;

  /// 升下一级所需经验（rpc_pet_summary config 同源计算，见 petExpNeed）。
  /// null（旧版服务端未下发曲线两键）时经验行回退旧的 /100 展示。
  final int? expNeed;

  /// 已达等级上限（level_max，服务端同源冻结 exp）：经验条满格 +
  /// 数值格展示超出经验 '${exp}/max'
  final bool expMaxed;

  /// 虚弱阈值（历险出发门槛 adventure_health_threshold 同源下发）——
  /// 健康低于此值时健康行转红警示；null（缺键/旧版服务端）不判定不造默认值
  final int? weakHealthAt;

  /// 展示层实时衰减速率（config 同源；0=不衰减）。寄养冻结由调用方以 0 传入
  final int decayHungerPerHour;
  final int decayMoodPerHour;

  /// 数据锚点时刻（summary 拉取时间）；null 不插值
  final DateTime? statsAt;

  /// 打开属性面板（null 时不可点）
  final VoidCallback? onTap;

  @override
  State<PetBottomStatusCard> createState() => _PetBottomStatusCardState();
}

class _PetBottomStatusCardState extends State<PetBottomStatusCard>
    with TickerProviderStateMixin {
  Timer? _tick;

  /// 属性点待分配金框呼吸（0↔1 循环渐显渐隐
  ///  提示挂在主页状态卡——升级后不开详情面板也能看到有待分配点；
  ///  无待分配点时停表，不空转重建）
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  /// 经验条增长动画链（升级时旧条补满→归零→逐级补满
  ///  →末段到新位置，多级成链）
  late final AnimationController _expAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  TweenSequence<double>? _expSeq;
  String? _prevPetId;
  int? _prevExp;
  int? _prevLevel;
  int? _prevNeed;
  bool _prevMaxed = false;

  @override
  void initState() {
    super.initState();
    // 展示层实时衰减：每分钟按速率插值重绘（服务端惰性结算为准）
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant PetBottomStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeRunExpAnimation();
    _syncPulse();
  }

  /// 金框呼吸起停跟随待分配点：有点数时循环，分配完即停（装饰层静止）
  void _syncPulse() {
    final shouldGlow = widget.pet.pendingAttrPoints > 0;
    if (shouldGlow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldGlow && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  /// 经验/等级变化时构建增长链：同级单段缓动；升级 k 级 = 旧条补满 →
  /// 中间级各 0→满 → 末段到新位置。换宠（id 变化）不动画直接换值。
  void _maybeRunExpAnimation() {
    final pet = widget.pet;
    if (_prevPetId != pet.id) {
      _prevPetId = pet.id;
      _prevExp = pet.exp;
      _prevLevel = pet.level;
      _prevNeed = widget.expNeed;
      _prevMaxed = widget.expMaxed;
      _expSeq = null;
      return;
    }
    if (pet.exp == _prevExp &&
        pet.level == _prevLevel &&
        widget.expMaxed == _prevMaxed) {
      return;
    }
    final oldExp = _prevExp ?? pet.exp;
    final oldLevel = _prevLevel ?? pet.level;
    final oldNeed = (_prevNeed ?? widget.expNeed) ?? 100;
    final oldMaxed = _prevMaxed;
    _prevExp = pet.exp;
    _prevLevel = pet.level;
    _prevNeed = widget.expNeed;
    _prevMaxed = widget.expMaxed;

    final maxed = widget.expMaxed;
    final need = widget.expNeed;
    // 缺曲线（need null）时与 _statRow 的 /100 回退口径一致
    final effNeed = maxed ? null : (need ?? 100);
    final newFrac =
        (effNeed == null || effNeed <= 0) ? 1.0 : (pet.exp / effNeed).clamp(0.0, 1.0);
    final oldFrac = oldMaxed ? 1.0 : (oldExp / oldNeed).clamp(0.0, 1.0);
    final gained = pet.level - oldLevel;
    final segs = <TweenSequenceItem<double>>[];
    if (gained > 0) {
      segs.add(TweenSequenceItem(
          tween: Tween(begin: oldFrac, end: 1.0), weight: 1));
      for (var i = 1; i < gained; i++) {
        segs.add(TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.0), weight: 1));
      }
      segs.add(TweenSequenceItem(
          tween: Tween(begin: 0.0, end: newFrac), weight: 1));
    } else if (pet.exp >= oldExp) {
      // 同级增长（含新满级 0→满）：单段缓动
      segs.add(TweenSequenceItem(
          tween: Tween(begin: oldFrac, end: newFrac), weight: 1));
    } else {
      // 经验回退（非常规口径）：不动画直接落新值
      _expSeq = null;
      return;
    }
    _expSeq = TweenSequence<double>(segs);
    _expAnim.duration =
        Duration(milliseconds: (500 * segs.length).clamp(600, 3200));
    _expAnim.forward(from: 0);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    _expAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final expNeed = widget.expNeed;
    final expMaxed = widget.expMaxed;
    final anchor = widget.statsAt;
    // 饱食/心情插值（无锚点/速率 0 = 原值）
    final hunger = anchor == null
        ? pet.hunger
        : petDecayedStat(
            pet.hunger, anchor, widget.decayHungerPerHour, DateTime.now());
    final mood = anchor == null
        ? pet.mood
        : petDecayedStat(
            pet.mood, anchor, widget.decayMoodPerHour, DateTime.now());
    // 经验条动画取值移入经验行的 AnimatedBuilder（增长链逐帧只重建本行）
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        // 卡片内容缓存为 child：金框呼吸逐帧只重建装饰层
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
            _statRow('饱食', 'ui_hunger', Icons.restaurant, hunger),
            const SizedBox(height: 6),
            _statRow('心情', 'ui_mood', Icons.mood, mood),
            const SizedBox(height: 6),
            // 亲密度不在主界面展示：详情面板（属性面板）已有对应字段
            // 健康/经验行序：健康紧随心情
            // 健康行（历险失败惩罚扣减；低于出发门槛=虚弱，进度条转红警示；
            // 阈值缺键不判定）
            _statRow('健康', 'ui_health', Icons.health_and_safety_outlined,
                pet.health,
                valueColor: (widget.weakHealthAt != null &&
                        pet.health < widget.weakHealthAt!)
                    ? const Color(0xFFE57373)
                    : null),
            const SizedBox(height: 6),
            // 经验行独立接动画：增长链播放中逐帧取序列插值（静止取实际值），
            // 只重建本行，不影响卡片其余行
            AnimatedBuilder(
              animation: _expAnim,
              builder: (_, __) {
                final frac = (_expSeq != null && _expAnim.isAnimating)
                    ? _expSeq!.evaluate(_expAnim)
                    : null;
                return _statRow('经验', 'ui_exp', Icons.trending_up, pet.exp,
                    max: expMaxed ? null : expNeed,
                    forceFull: expMaxed,
                    fractionOverride: frac,
                    displayText: expMaxed
                        ? '${pet.exp}/max'
                        : (expNeed == null ? null : '${pet.exp}/$expNeed'));
              },
            ),
          ],
        ),
        builder: (ctx, content) {
          // 属性点待分配金框：呼吸脉冲（用户在主页不开面板即感知）
          final glow = pet.pendingAttrPoints > 0;
          const glowColor = Color(0xFFE8A33D);
          final t = _pulse.value;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xCC2E2A24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: glow
                    ? glowColor.withValues(alpha: 0.2 + 0.8 * t)
                    : Colors.transparent,
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glow ? 0.25 * t : 0),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: content,
          );
        },
      ),
    );
  }

  /// 单条状态行：图标 + 标签 + 进度条 + 数值（独占一行）
  ///
  /// [max] 为该行值域上限（缺省 100）；[displayText] 非空时数值格改显该文案
  /// （经验行 exp/need），格宽随之放宽。经验需求 >100（2 级起），写死 /100
  /// 会让条恒满——上限必须来自 summary config 同源曲线（petExpNeed）。
  Widget _statRow(String label, String iconKey, IconData fallback, int value,
      {int? max,
      bool forceFull = false,
      String? displayText,
      double? fractionOverride,
      Color? valueColor}) {
    const accent = Color(0xFFFFD37E);
    final barColor = valueColor ?? accent;
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
              value: fractionOverride ??
                  (forceFull ? 1.0 : (value / denom).clamp(0.0, 1.0)),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          // 数值格全行统一宽度：经验行 exp/need 与单值行（饱食 85 等）右端对齐
          // 五条进度条右缘齐平；80px 承载后期 13 字符（'144422/144423' ≈79px）
          // 原字号不缩放；FittedBox 兜底防未来更长文案溢出
          width: 80,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(displayText ?? '$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFFF5EFE4))),
          ),
        ),
      ],
    );
  }
}

// 程序化背景归档（Flat 晨曦草甸 / Meadow / Starry 星海之栏，可回退实现）：
// 整块移入 pet_home_scene_archive.dart 保存，恢复时整块拷回本文件即可。
