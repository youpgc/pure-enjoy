import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_art.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_living_art.dart';
import 'pet_adventure_screen.dart';
import 'pet_bag_screen.dart';
import 'pet_quests_screen.dart';
import 'pet_shop_screen.dart';
import 'pet_wallet_screen.dart';

/// 宠物主页（2D 动画版，交互闭环 + 多宠切换）
///
/// 布局（2026-09-17 定版）：
/// - 宠物立绘居中舞台展示，多宠时舞台两侧出现左右切换按钮（单宠隐藏）；
/// - 交互操作按钮浮动在页面左右两侧（左：喂食/抚摸；右：历险/任务）；
/// - 底部功能入口：背包/商城/钱包；
/// 渲染层：静态立绘 + 呼吸/互动动效（PetLivingArt）；
/// 3D 相关入口已按 2026-09 定调全部下线（代码注释保留，3D 转后期迭代）。
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key, this.initialTab});

  /// 深链页签（bag / shop / wallet / quests ...），null 表示正常进入
  final String? initialTab;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;
  String? _error;
  bool _busy = false;
  bool _excited = false;

  /// 当前展示的宠物下标（针对 [_rearingPets]；单宠时恒 0）
  int _petIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTab == null ? '宠物' : '宠物 · ${widget.initialTab}'),
        // 【3D 下线 2026-09】S1 POC 工作台入口注释保留，3D 转后期迭代：
        // if (kDebugMode)
        //   IconButton(
        //     tooltip: '3D POC 工作台',
        //     icon: const Icon(Icons.science_outlined),
        //     onPressed: () => Navigator.push(
        //       context,
        //       MaterialPageRoute(builder: (_) => const PetPocScreen()),
        //     ),
        //   ),
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: LoadingWidget());
    }
    if (!_enabled) {
      return const EmptyWidget(message: '宠物功能暂未开放');
    }
    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('宠物数据加载失败，请稍后重试'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _loading = true);
                _load(force: true);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final summary = _summary!;
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _walletCard(summary, colorScheme),
              const SizedBox(height: 12),
              if (_rearingPets.isNotEmpty) ...[
                _petStage(colorScheme),
                const SizedBox(height: 12),
                if (summary.ongoingAdventure != null) ...[
                  _adventureBanner(summary.ongoingAdventure!, colorScheme),
                  const SizedBox(height: 12),
                ],
              ] else
                _hatchGuide(summary, colorScheme),
              const SizedBox(height: 12),
              _entryRow(colorScheme),
            ],
          ),
          // 左右浮动操作列（有在养宠物才可用）
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _floatButton(
                    colorScheme,
                    icon: Icons.restaurant,
                    label: '喂食',
                    onTap: _currentPet == null || _busy
                        ? null
                        : () => _run(
                            () => PetRpc.feed(_currentPet!.id),
                            successMsg:
                                '喂饱啦（今日免费 ${_summary?.config['free_feed_daily'] ?? '-'} 次）',
                            celebrate: true),
                  ),
                  const SizedBox(height: 14),
                  _floatButton(
                    colorScheme,
                    icon: Icons.touch_app_outlined,
                    label: '抚摸',
                    onTap: _currentPet == null || _busy
                        ? null
                        : () => _run(() => PetRpc.interact(_currentPet!.id),
                            celebrate: true),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _floatButton(
                    colorScheme,
                    icon: Icons.explore_outlined,
                    label: '历险',
                    onTap: _currentPet == null || _busy ? null : _openAdventure,
                  ),
                  const SizedBox(height: 14),
                  _floatButton(
                    colorScheme,
                    icon: Icons.task_alt_outlined,
                    label: '任务',
                    onTap: _openQuests,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 金币卡 ----------

  Widget _walletCard(PetSummaryModel s, ColorScheme cs) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.paid_outlined),
        title: const Text('金币'),
        subtitle: Text('累计获得 ${s.wallet.totalEarned} · 累计消费 ${s.wallet.totalSpent}'),
        trailing: Text(
          '${s.wallet.goldBalance}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.primary),
        ),
      ),
    );
  }

  // ---------- 中央宠物舞台（多宠左右切换） ----------

  Widget _petStage(ColorScheme cs) {
    final pets = _rearingPets;
    final pet = _currentPet!;
    final multi = pets.length > 1;
    final art = petStageArtAsset(pet.speciesCode, pet.stage);
    return Card(
      child: Padding(
        // 左右浮动按钮占位（按钮列宽约 54px），内容内收避免遮挡
        padding: const EdgeInsets.fromLTRB(48, 12, 48, 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  child: multi
                      ? IconButton(
                          onPressed: () => _switchPet(-1),
                          icon: const Icon(Icons.chevron_left),
                          tooltip: '上一只',
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      PetLivingArt(
                        assetPath: art,
                        excited: _excited,
                        onTap: () => _run(() => PetRpc.interact(pet.id),
                            successMsg:
                                '开心 +${_summary?.config['interact_mood'] ?? 5}'),
                      ),
                      const SizedBox(height: 4),
                      Text('${pet.name} · Lv.${pet.level}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${pet.speciesCode} · ${pet.rarity} · ${_genderText(pet.gender)} · 形态 ${pet.stage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: multi
                      ? IconButton(
                          onPressed: () => _switchPet(1),
                          icon: const Icon(Icons.chevron_right),
                          tooltip: '下一只',
                        )
                      : null,
                ),
              ],
            ),
            if (multi) ...[
              const SizedBox(height: 2),
              Text('${_petIndex + 1}/${pets.length}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            _statRow('饱食度', pet.hunger, cs),
            _statRow('心情', pet.mood, cs),
            _statRow('亲密度', pet.intimacy, cs),
            _statRow('经验', pet.exp, cs),
          ],
        ),
      ),
    );
  }

  String _genderText(dynamic gender) {
    final code = gender?.code as String?;
    return switch (code) {
      'male' => '♂',
      'female' => '♀',
      _ => '·',
    };
  }

  Widget _statRow(String label, int value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.end, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------- 左右浮动操作按钮 ----------

  Widget _floatButton(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                size: 22,
                color: enabled ? cs.onPrimaryContainer : cs.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: enabled ? cs.onSurface : cs.outline,
          ),
        ),
      ],
    );
  }

  // ---------- 历险横幅 ----------

  Widget _adventureBanner(PetAdventureBriefModel adv, ColorScheme cs) {
    final finished =
        adv.endAt == null || !DateTime.now().isBefore(adv.endAt!);
    return Card(
      color: finished ? cs.primaryContainer : cs.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(
          finished ? Icons.redeem_outlined : Icons.explore_outlined,
          color: cs.primary,
        ),
        title: Text(
          finished ? '历险已结束，点击查看结果' : '历险进行中 · ${adv.status == 'awaiting_rescue' ? '待救助' : '归来倒计时'}',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: adv.status == 'awaiting_rescue'
            ? const Text('需要你的救援！', style: TextStyle(fontSize: 12))
            : Text(
                finished ? '' : '预计 ${adv.endAt!.toLocal().difference(DateTime.now()).inMinutes} 分钟后归来',
                style: const TextStyle(fontSize: 12),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openAdventure,
      ),
    );
  }

  // ---------- 无宠物：孵化引导 ----------

  Widget _hatchGuide(PetSummaryModel s, ColorScheme cs) {
    final hasEgg = s.eggsReadyInstant > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.egg_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 8),
            Text(hasEgg ? '你的第一颗蛋已经就绪' : '还没有宠物'),
            const SizedBox(height: 4),
            Text(
              hasEgg ? '点击下方按钮，立即见证新伙伴的诞生' : '初始蛋将在背包中发放，稍后回来试试',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (hasEgg) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _hatchFirstEgg,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('立即孵化'),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 新伙伴诞生！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名字：${result.name}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('编号：${result.showNo}'),
            Text('稀有度：${result.rarity}'),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('太好了')),
        ],
      ),
    );
    _load();
  }

  // ---------- 底部功能入口 ----------

  Widget _entryRow(ColorScheme cs) {
    final s = _summary;
    final entries = [
      ('背包', Icons.inventory_2_outlined, _openBag),
      ('商城', Icons.storefront_outlined, () => _openShop(s?.wallet.goldBalance ?? 0)),
      ('钱包', Icons.account_balance_wallet_outlined, _openWallet),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (label, icon, onTap) in entries)
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: cs.primary),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }
}

/*
 * 【3D 下线归档 2026-09】
 * - 原 AppBar「3D POC 工作台」debug 入口：见 appBar actions 注释块；
 * - 原 3D 资源包状态卡（PetAssetCard，按系懒加载下载）：本页 ListView 中
 *   `if (pet != null) PetAssetCard(family: pet.family)` 一行随 3D 渲染层
 *   一并下线；pet_asset_card / pet_asset_service / pet_poc_screen 源码
 *   均注释保留，待 3D 后期迭代恢复；
 * - 数据库 render3d_enabled / asset_manifest 列保留（默认关闭），门控
 *   查询降级逻辑保留，不影响 2D 主链路。
 */
