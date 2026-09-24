import 'dart:async';

import 'package:flutter/material.dart';

/// 宠物主页库（part 拆分）：本文件是 library 声明与状态主体，
/// 三个 part 共用下列导入（Dart 的 part 文件不能自带 import）。
import '../../../constants/pet.dart';
import '../../../constants/pet_render.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_audio.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_action_machine.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_home_budget.dart';
import '../widgets/pet_attributes_sheet.dart';
import '../widgets/pet_feed_sheet.dart';
import '../widgets/pet_fx_overlay.dart';
import '../widgets/pet_home_adventure.dart';
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_home_scene.dart';
import '../widgets/pet_living_art.dart';
import 'pet_achievements_screen.dart';
import 'pet_adventure_screen.dart';
import 'pet_bag_screen.dart';
import 'pet_breed_screen.dart';
import 'pet_egg_screen.dart';
import 'pet_foster_screen.dart';
import 'pet_growth_screen.dart';
import 'pet_quests_screen.dart';
import 'pet_shop_screen.dart';
import 'pet_wallet_screen.dart';

part 'pet_home_screen_layout.dart';
part 'pet_home_screen_actions.dart';

/// 宠物主页（场景舞台版 2.0，2026-09-17 美化重做）
///
/// 布局原则：宠物是唯一主角（垂直水平居中），其余信息各归其位——
/// - 场景背景：梦幻夜空场景图（与 App 主题解耦，PetSceneBackground）；
/// - 顶部通知横幅：历险归来待领取 / 待救助时出现（进行中不展示），
///   归来点击直接弹窗结算（claim → 奖励 / 遇险提示），不跳历险页；
/// - 左右按钮列贴顶（安全区下留少许间距）：左列 = 返回键 + 背包 / 商城 / 钱包 /
///   寄养 / 成就 / 繁育（P2 四项里成就与繁育走主页直达，孵蛋走背包蛋行、
///   进化与特性洗练走属性面板，避免按钮列在小屏上溢出）；
///   右列 = 金币胶囊 + 喂食 / 抚摸 / 历险 / 任务
///   （历险钮四态：历险/召回/领取/救助），冷却时黑色透明蒙层白色字体居中倒计时；
/// - 底部状态区：名牌 + 四维独立行沉底（PetBottomStatusCard），历险中附去向提示；
///   无任何宠物时孵化引导卡垂直水平居中（返回键/金币回独立浮层）。
/// - 中央舞台手势（2026-09-24 2D 动画定版）：单击 = 抚摸（走 interact RPC）、
///   双击 = 开心演出（纯表现，不发 RPC 不加数值）、长按 = 属性面板；
///   动作由 [PetActionMachine] 仲裁，粒子由 [PetFxController] 绘制。
/// 浮层组件见 pet_home_overlays / scene / adventure.dart，冷却派生见 PetActionBudget。
///
/// 【文件拆分 2026-09-22】单文件超 500 行红线，按职责拆为三个 part：
/// - 本文件：状态字段 + 生命周期 + 数据装载 + 派生取值 + 整体 Stack 组装
/// - `pet_home_screen_layout.dart`：舞台 / 顶部横幅 / 底部状态 / 左右两列的浮层构建
/// - `pet_home_screen_actions.dart`：交互动作（喂食、孵化、跳转、历险四态）
///
/// 【3D 下线归档 2026-09】3D 渲染层与资源包状态卡一并下线（源码注释保留），
/// 数据库 render3d_enabled / asset_manifest 列保留，3D 转后期迭代。
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key, this.initialTab});

  /// 深链页签（bag / shop / wallet / quests ...），null 表示正常进入
  final String? initialTab;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;
  String? _error;
  bool _busy = false;

  /// 动作仲裁器（优先级/防抖，逻辑见 [PetActionMachine]）
  final PetActionMachine _machine = PetActionMachine();

  /// 舞台粒子层控制器（爱心/星星/碎屑/进化光柱，空闲自动停表）
  late final PetFxController _fx = PetFxController(vsync: this);

  /// 当前展示的宠物下标（针对 [_stagePets]；单宠时恒 0）
  int _petIndex = 0;

  Timer? _tick; // 冷却倒计时逐秒刷新

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _budget.anyCooling) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _fx.dispose();
    super.dispose();
  }

  /// 舞台宠物列表：在养 + 历险中（历险派遣后原宠物保留原位，寄养/繁育中不展示）
  List<PetBriefModel> get _stagePets => (_summary?.pets ?? const <PetBriefModel>[])
      .where((p) => p.status == PetPetStatus.rearing || p.status == PetPetStatus.adventuring)
      .toList();

  /// 当前选中的宠物（无舞台宠物返回 null）
  PetBriefModel? get _currentPet {
    final pets = _stagePets;
    if (pets.isEmpty) return null;
    if (_petIndex < 0 || _petIndex >= pets.length) return pets.first;
    return pets[_petIndex];
  }

  /// 当前宠物的进行中历险（多宠场景按 petId 过滤——A 宠历险不再错挂到
  /// B 宠的历险钮/历险页；顶部横幅保留全局：归来/待救助是全局事件通知）
  PetAdventureBriefModel? get _currentAdventure {
    final adv = _summary?.ongoingAdventure;
    if (adv == null) return null;
    final pet = _currentPet;
    if (pet != null && adv.petId == pet.id) return adv;
    return null;
  }

  /// 冷却与每日次数派生（逻辑见 [PetActionBudget]）
  PetActionBudget get _budget =>
      PetActionBudget(config: _summary?.config ?? const {}, pet: _currentPet);

  Future<void> _load({bool force = false}) async {
    final enabled = await PetService.instance.isPetEnabled(forceRefresh: force);
    if (!enabled) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
      return;
    }
    final (summary, err) =
        await PetService.instance.fetchSummary(forceRefresh: force);
    if (mounted) {
      setState(() {
        _enabled = true;
        _summary = summary;
        _error = summary == null ? (err ?? '宠物功能已关闭') : null;
        _loading = false;
        // 多宠切换下标防越界（列表变短时回第一只）
        final count = _stagePets.length;
        if (_petIndex >= count) _petIndex = 0;
      });
    }
  }

  void _switchPet(int delta) {
    final pets = _stagePets;
    if (pets.length < 2) return;
    // 换宠回落环境态：A 宠的演出不带进 B 宠
    _machine.reset();
    _fx.clear();
    setState(() {
      _petIndex = (_petIndex + delta + pets.length) % pets.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody(Theme.of(context).colorScheme));
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (!_enabled) return const EmptyWidget(message: '宠物功能暂未开放');
    if (_summary == null) {
      return PetLoadErrorView(
        message: _error,
        onRetry: () {
          setState(() => _loading = true);
          _load(force: true);
        },
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const PetSceneBackground(),
        if (_stagePets.isNotEmpty) ...[
          _stage(),
          ..._switchArrows(),
          _topBanner(cs),
          _bottomPanel(cs),
          _leftRail(),
          _rightRail(),
        ] else ...[
          // 无任何宠物：返回键/金币常驻顶部角落 + 孵化引导卡垂直水平居中
          PetBackButton(onBack: () => Navigator.maybePop(context)),
          PetGoldBadge(gold: _summary?.wallet.goldBalance ?? 0),
          Center(
            child: PetHatchGuide(
                hasEgg: _summary!.eggsReadyInstant > 0,
                busy: _busy,
                onHatch: _hatchFirstEgg,
                onGoEggs: _openEggs),
          ),
        ],
      ],
    );
  }
}
