import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_art.dart';
import '../utils/pet_errors.dart';
import '../utils/pet_home_budget.dart';
import '../widgets/pet_home_adventure.dart';
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_home_scene.dart';
import '../widgets/pet_living_art.dart';
import 'pet_adventure_screen.dart';
import 'pet_bag_screen.dart';
import 'pet_quests_screen.dart';
import 'pet_shop_screen.dart';
import 'pet_wallet_screen.dart';

/// 宠物主页（场景舞台版 2.0，2026-09-17 美化重做）
///
/// 布局原则：宠物是唯一主角（垂直水平居中），其余信息各归其位——
/// - 场景背景：梦幻夜空场景图（与 App 主题解耦，PetSceneBackground）；
/// - 顶部通知横幅：历险归来待领取 / 待救助时出现（进行中不展示），
///   归来点击直接弹窗结算（claim → 奖励 / 遇险提示），不跳历险页；
/// - 左右按钮列贴顶（安全区下留少许间距）：左列 = 返回键 + 背包 / 商城 / 钱包 /
///   寄养（寄养未开放禁用占位）；右列 = 金币胶囊 + 喂食 / 抚摸 / 历险 / 任务
///   （历险钮四态：历险/召回/领取/救助），冷却时黑色透明蒙层白色字体居中倒计时；
/// - 底部状态区：名牌 + 四维独立行沉底（PetBottomStatusCard），历险中附去向提示；
///   无任何宠物时孵化引导卡垂直水平居中（返回键/金币回独立浮层）。
/// 浮层组件见 pet_home_overlays / scene / adventure.dart，冷却派生见 PetActionBudget。
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

class _PetHomeScreenState extends State<PetHomeScreen> {
  /// 左右浮动列占位宽（52px 按钮 + 边距）
  static const double _edgeInset = 64;

  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;
  String? _error;
  bool _busy = false;
  bool _excited = false;

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
    final summary = await PetService.instance.fetchSummary(forceRefresh: force);
    if (mounted) {
      setState(() {
        _enabled = true;
        _summary = summary;
        _error = summary == null ? '总览拉取失败（rpc_pet_summary）' : null;
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
    setState(() {
      _petIndex = (_petIndex + delta + pets.length) % pets.length;
    });
  }

  Future<void> _run(Future<String?> Function() action,
      {String? successMsg, bool celebrate = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      return;
    }
    if (celebrate) _celebrate();
    if (successMsg != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMsg)));
    }
    _load();
  }

  void _celebrate() {
    setState(() => _excited = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _excited = false);
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
                hasEgg: _summary!.eggsReadyInstant > 0, busy: _busy, onHatch: _hatchFirstEgg),
          ),
        ],
      ],
    );
  }

  // ---------- 中央舞台（宠物主角，垂直水平居中） ----------

  Widget _stage() {
    final pet = _currentPet!;
    return Positioned.fill(
      // 底部让位状态面板（名牌+四维沉底），其余方向居中
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_edgeInset + 40, 0, _edgeInset + 40, 128),
        child: Center(
          child: PetLivingArt(
            frames: petIdleFrames(pet.speciesCode),
            fallbackAsset: petStageArtAsset(pet.speciesCode, pet.stage),
            excited: _excited,
            onTap: () => _run(() => PetRpc.interact(pet.id),
                successMsg: '开心 +${_budget.cfg('interact_mood')}'),
          ),
        ),
      ),
    );
  }

  List<Widget> _switchArrows() => [
        Positioned(
          left: _edgeInset - 4, top: 0, bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_left, onTap: () => _switchPet(-1)),
          ),
        ),
        Positioned(
          right: _edgeInset - 4, top: 0, bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_right, onTap: () => _switchPet(1)),
          ),
        ),
      ];

  // ---------- 顶部通知横幅（历险状态） ----------

  Widget _topBanner(ColorScheme cs) {
    final adv = _summary?.ongoingAdventure;
    if (adv == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 76, vertical: 4),
          child: Center(child: PetAdventureBanner(adv: adv, onTap: _bannerTap())),
        ),
      ),
    );
  }

  // ---------- 底部状态区（名牌 + 四维沉底） ----------

  Widget _bottomPanel(ColorScheme cs) {
    final pet = _currentPet!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pet.status == PetPetStatus.adventuring) ...[
                const PetAdventureNote(),
                const SizedBox(height: 6),
              ],
              PetBottomStatusCard(pet: pet),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 左侧入口列（返回键 + 背包/商城/钱包/寄养，贴顶） ----------

  Widget _leftRail() {
    return Positioned(
      left: 8,
      top: 0,
      child: Padding(
        // 贴顶：安全区下方留些许间距；返回键内联列首（避免与独立浮层重叠）
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetBackButtonCore(onBack: () => Navigator.maybePop(context)),
            const SizedBox(height: 10),
            PetEdgeButton(
                icon: Icons.inventory_2_outlined,
                label: '背包',
                onTap: _openBag),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.storefront_outlined,
                label: '商城',
                onTap: () => _openShop(_summary?.wallet.goldBalance ?? 0)),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.account_balance_wallet_outlined,
                label: '钱包',
                onTap: _openWallet),
            const SizedBox(height: 14),
            // 寄养未开放：禁用置灰占位，点击提示
            PetEdgeButton(
                icon: Icons.luggage_outlined,
                label: '寄养',
                disabled: true,
                onTap: () => showFosterComingSoon(context)),
          ],
        ),
      ),
    );
  }

  // ---------- 右侧操作列（金币 + 喂食/抚摸/历险/任务，贴顶） ----------

  /// 蒙层策略：正常态无蒙层；冷却中黑蒙层显示倒计时；当日次数耗尽提示上限
  String? _overlay(Duration? cool, int? remain) {
    if (cool != null) return _budget.coolText(cool);
    if (remain != null && remain <= 0) return '已达上限';
    return null;
  }

  Widget _rightRail() {
    final pet = _currentPet;
    final feedCool = _budget.feedCooldown;
    final interactCool = _budget.interactCooldown;
    // 历险中的宠物不在场，喂食/抚摸禁用（服务端同样拦截 PET_NOT_REARING）
    final feedOff = pet == null ||
        _busy ||
        pet.status == PetPetStatus.adventuring ||
        _budget.blocked(feedCool, _budget.feedRemain);
    final interactOff = pet == null ||
        _busy ||
        pet.status == PetPetStatus.adventuring ||
        _budget.blocked(interactCool, _budget.interactRemain);
    return Positioned(
      right: 8,
      top: 0,
      child: Padding(
        // 贴顶：安全区下方留些许间距；金币胶囊内联列首（避免与独立浮层重叠）
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetGoldBadgeCore(gold: _summary?.wallet.goldBalance ?? 0),
            const SizedBox(height: 10),
            PetEdgeButton(
                icon: Icons.restaurant,
                label: '喂食',
                overlay: _overlay(feedCool, _budget.feedRemain),
                onTap: feedOff
                    ? null
                    : () => _run(() => PetRpc.feed(pet.id),
                        successMsg: '喂饱啦', celebrate: true)),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.touch_app_outlined,
                label: '抚摸',
                overlay: _overlay(interactCool, _budget.interactRemain),
                onTap: interactOff
                    ? null
                    : () => _run(() => PetRpc.interact(pet.id),
                        celebrate: true)),
            const SizedBox(height: 14),
            _adventureButton(),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.task_alt_outlined,
                label: '任务',
                onTap: _openQuests),
          ],
        ),
      ),
    );
  }

  // ---------- 孵化（诞生弹窗 + 刷新） ----------

  /// 即开首颗蛋 → 诞生弹窗（基础型形象大图）→ 确认后刷新宠物信息
  Future<void> _hatchFirstEgg() async {
    final (eggs, err) = await PetRpc.fetchEggs();
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      }
      return;
    }
    PetEggModel? target;
    for (final e in eggs) {
      if (e.isInstant) {
        target = e;
        break;
      }
    }
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('没有可即开孵化的蛋')));
      }
      return;
    }
    final (result, hatchErr) = await PetRpc.hatchEgg(target.id);
    if (!mounted) return;
    if (hatchErr != null || result == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(hatchErr))));
      return;
    }
    _celebrate();
    // 图片权重：展示基础型形象大图（帧序列首帧，未登记种属回退静态立绘）
    final frames = petIdleFrames(result.speciesCode);
    await showPetBirthDialog(
      context,
      img: frames.isNotEmpty
          ? frames.first
          : petStageArtAsset(result.speciesCode, 0),
      result: result,
    );
    // 点击确认后刷新宠物信息
    _load();
  }

  // ---------- 页面跳转 ----------

  void _openBag() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetBagScreen(petId: _currentPet?.id),
      ),
    ).then((_) => _load());
  }

  void _openShop(int gold) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PetShopScreen(goldBalance: gold)),
    ).then((_) => _load());
  }

  void _openQuests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetQuestsScreen()),
    ).then((_) => _load());
  }

  void _openAdventure() {
    final pet = _currentPet;
    if (pet == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先孵化一只宠物才能历险')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetAdventureScreen(
          petId: pet.id,
          petName: pet.name,
          adventure: _summary?.ongoingAdventure,
          tiers: _tierList(),
          hunger: pet.hunger,
          mood: pet.mood,
        ),
      ),
    ).then((_) => _load());
  }

  // ---------- 主页历险交互（分流/动作/四态钮，helper 见 pet_home_adventure.dart） ----------

  // ---------- 主页历险交互（helper 见 pet_home_adventure.dart） ----------
  // 横幅点击分流：待救助 → 历险页处理；归来待领取 → claim 弹窗结算
  VoidCallback _bannerTap() =>
      _summary?.ongoingAdventure?.status == 'awaiting_rescue'
          ? _openAdventure
          : () => _runAdventure(claimAdventureResult);

  /// 历险动作统一入口：归来领取（弹窗）/ 召回确认（无奖励中断），完成后刷新
  Future<void> _runAdventure(AdventureAction run) async {
    final adv = _summary?.ongoingAdventure;
    if (adv == null || _busy) return;
    if (await run(context, adv.id) && mounted) _load();
  }

  /// 右列历险钮四态（历险/召回/领取/救助，分支逻辑见 petAdventureRailButton）
  Widget _adventureButton() => petAdventureRailButton(
      adv: _summary?.ongoingAdventure,
      openAdventure: _openAdventure,
      claimResult: () => _runAdventure(claimAdventureResult),
      recall: () => _runAdventure(recallAdventureConfirmed));

  void _openWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetWalletScreen()),
    ).then((_) => _load());
  }

  List<Map<String, dynamic>> _tierList() {
    final raw = _summary?.config['adventure_tiers'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
