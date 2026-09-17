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
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_living_art.dart';
import 'pet_adventure_screen.dart';
import 'pet_bag_screen.dart';
import 'pet_quests_screen.dart';
import 'pet_shop_screen.dart';
import 'pet_wallet_screen.dart';

/// 宠物主页（满屏舞台版，2026-09-17 定版）
///
/// 布局：宠物帧动画 + 背景占满整页，其余内容浮动于四边——
/// - 顶部提示信息：宠物名牌 + 四维状态 + 历险横幅 / 孵化引导；
/// - 右侧操作列：喂食 / 抚摸 / 历险 / 任务（含冷却倒计时与当日剩余次数）；
/// - 左侧入口列：背包 / 商城 / 钱包，左上角返回 + 金币胶囊；
/// - 中央舞台：PetLivingArt 帧动画（多宠时舞台两侧切换箭头，单宠隐藏）；
/// - 未登记帧序列的种属回退单帧立绘（petStageArtAsset）。
/// 浮层展示组件见 pet_home_overlays.dart，冷却/次数派生见 PetActionBudget。
///
/// 【3D 下线归档 2026-09】原 AppBar「3D POC 工作台」debug 入口与
/// PetAssetCard 资源包状态卡随 3D 渲染层一并下线（源码注释保留）；
/// 数据库 render3d_enabled / asset_manifest 列保留，3D 转后期迭代。
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key, this.initialTab});

  /// 深链页签（bag / shop / wallet / quests ...），null 表示正常进入
  final String? initialTab;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  /// 左右浮动列占位宽（52px 按钮 + 边距），舞台与提示内容避让
  static const double _edgeInset = 64;

  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;
  String? _error;
  bool _busy = false;
  bool _excited = false;

  /// 当前展示的宠物下标（针对 [_rearingPets]；单宠时恒 0）
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

  /// 在养宠物列表（历险中/寄养中的不参与舞台展示与切换）
  List<PetBriefModel> get _rearingPets =>
      (_summary?.pets ?? const <PetBriefModel>[])
          .where((p) => p.status == PetPetStatus.rearing)
          .toList();

  /// 当前选中的宠物（无在养宠物返回 null）
  PetBriefModel? get _currentPet {
    final pets = _rearingPets;
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
        final count = _rearingPets.length;
        if (_petIndex >= count) _petIndex = 0;
      });
    }
  }

  void _switchPet(int delta) {
    final pets = _rearingPets;
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
        _background(cs),
        if (_rearingPets.isNotEmpty) ...[
          _stage(cs),
          ..._switchArrows(cs),
        ],
        _topHints(cs),
        _leftRail(cs),
        _rightRail(cs),
        PetTopLeftBar(
          gold: _summary?.wallet.goldBalance ?? 0,
          onBack: () => Navigator.maybePop(context),
        ),
      ],
    );
  }

  // ---------- 满屏背景 ----------

  Widget _background(ColorScheme cs) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primaryContainer.withValues(alpha: 0.30), cs.surface],
          ),
        ),
      );

  // ---------- 中央舞台（帧动画） ----------

  Widget _stage(ColorScheme cs) {
    final pet = _currentPet!;
    final topInset = MediaQuery.paddingOf(context).top +
        158 +
        (_summary?.ongoingAdventure != null ? 66 : 0);
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(_edgeInset, topInset, _edgeInset, 28),
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

  List<Widget> _switchArrows(ColorScheme cs) => [
        Positioned(
          left: _edgeInset - 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_left, onTap: () => _switchPet(-1)),
          ),
        ),
        Positioned(
          right: _edgeInset - 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_right, onTap: () => _switchPet(1)),
          ),
        ),
      ];

  // ---------- 顶部提示信息 ----------

  Widget _topHints(ColorScheme cs) {
    final pet = _currentPet;
    final adv = _summary?.ongoingAdventure;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(_edgeInset + 8,
            MediaQuery.paddingOf(context).top + 4, _edgeInset + 8, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pet != null) ...[
              PetNamePill(pet: pet),
              const SizedBox(height: 6),
              PetStatusCard(pet: pet),
              if (adv != null) ...[
                const SizedBox(height: 8),
                PetAdventureBanner(adv: adv, onTap: _openAdventure),
              ],
            ] else
              PetHatchGuide(
                hasEgg: _summary!.eggsReadyInstant > 0,
                busy: _busy,
                onHatch: _hatchFirstEgg,
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 左侧入口列（背包/商城/钱包） ----------

  Widget _leftRail(ColorScheme cs) {
    final s = _summary;
    return Positioned(
      left: 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetEdgeButton(
                  icon: Icons.inventory_2_outlined,
                  label: '背包',
                  onTap: _openBag),
              const SizedBox(height: 14),
              PetEdgeButton(
                  icon: Icons.storefront_outlined,
                  label: '商城',
                  onTap: () => _openShop(s?.wallet.goldBalance ?? 0)),
              const SizedBox(height: 14),
              PetEdgeButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '钱包',
                  onTap: _openWallet),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 右侧操作列（喂食/抚摸/历险/任务） ----------

  Widget _rightRail(ColorScheme cs) {
    final pet = _currentPet;
    final feedCool = _budget.feedCooldown;
    final interactCool = _budget.interactCooldown;
    final feedOff =
        pet == null || _busy || _budget.blocked(feedCool, _budget.feedRemain);
    final interactOff = pet == null ||
        _busy ||
        _budget.blocked(interactCool, _budget.interactRemain);
    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetEdgeButton(
                  icon: Icons.restaurant,
                  label: '喂食',
                  badge: feedCool != null
                      ? _budget.coolText(feedCool)
                      : (_budget.feedRemain != null
                          ? '剩${_budget.feedRemain}'
                          : null),
                  onTap: feedOff
                      ? null
                      : () => _run(() => PetRpc.feed(pet.id),
                          successMsg: '喂饱啦', celebrate: true)),
              const SizedBox(height: 14),
              PetEdgeButton(
                  icon: Icons.touch_app_outlined,
                  label: '抚摸',
                  badge: interactCool != null
                      ? _budget.coolText(interactCool)
                      : (_budget.interactRemain != null
                          ? '剩${_budget.interactRemain}'
                          : null),
                  onTap: interactOff
                      ? null
                      : () => _run(() => PetRpc.interact(pet.id),
                          celebrate: true)),
              const SizedBox(height: 14),
              PetEdgeButton(
                  icon: Icons.explore_outlined,
                  label: '历险',
                  onTap: _openAdventure),
              const SizedBox(height: 14),
              PetEdgeButton(
                  icon: Icons.task_alt_outlined,
                  label: '任务',
                  onTap: _openQuests),
            ],
          ),
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
