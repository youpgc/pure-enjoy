import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_p2_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../services/pet_service.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_growth_widgets.dart';

/// 养成页签（进化 / 特性）——UI 语义，非 DDL 值域，故不进 constants/pet.dart
enum PetGrowthTab {
  evolve('进化'),
  trait('特性');

  const PetGrowthTab(this.label);

  final String label;
}

/// 宠物养成页（P2：进化 + 特性洗练）
///
/// 两条链路的概率与条件判定都在服务端（铁律 1）：
/// - 进化 `rpc_pet_evolve`：条件四项（等级/亲密/金币/道具）全过才扣减，
///   **不可逆**；多分支时按 `pet_evo_stages.pick_mode` 分流——`user_choice`
///   由玩家选定目标形态并回传 species_id，`weighted_random` 一律回传 null
///   交服务端按权重掷取（客户端代选会让随机分支失效，属破坏配置语义）；
/// - 特性洗练 `rpc_pet_wash_trait`：结果即最终结果、不提供回退，
///   且**洗出空特性是合法结果**（trait_id=null 表示这次没掷中）。
class PetGrowthScreen extends StatefulWidget {
  const PetGrowthScreen({super.key, this.petId, this.initialTab});

  /// 预选宠物（主页/属性面板进入时带上；null 时取列表第一只）
  final String? petId;

  /// 起始页签（背包里的洗练剂「去洗练」直达特性页签）
  final PetGrowthTab? initialTab;

  @override
  State<PetGrowthScreen> createState() => _PetGrowthScreenState();
}

class _PetGrowthScreenState extends State<PetGrowthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loading = true;
  String? _error;
  List<PetPetDetailModel> _details = const [];
  List<PetEvoStageOptionModel> _options = const [];
  List<PetBagItemModel> _washItems = const [];
  String? _petId;
  bool _optionsLoading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, initialIndex: widget.initialTab?.index ?? 0, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (force) await PetService.instance.invalidateSummary();
    final (details, err) = await PetRpcP2.fetchPetDetails();
    final (bag, _) = await PetRpc.fetchBag();
    if (!mounted) return;
    String? keep;
    for (final id in [_petId, widget.petId]) {
      if (id != null && details.any((p) => p.id == id)) {
        keep = id;
        break;
      }
    }
    keep ??= _firstRearingId(details);
    setState(() {
      _details = details;
      _petId = keep;
      _error = err == null ? null : petRpcErrorText(err);
      _washItems = bag
          .where((e) => e.effectType == PetItemEffectType.traitWash.code)
          .toList();
      _loading = false;
    });
    await _loadOptions();
  }

  static String? _firstRearingId(List<PetPetDetailModel> details) {
    for (final p in details) {
      if (p.rearing) return p.id;
    }
    return null;
  }

  PetPetDetailModel? get _pet {
    for (final p in _details) {
      if (p.id == _petId) return p;
    }
    return null;
  }

  /// 拉当前宠下一阶段候选（换宠/进化后都要重拉）
  Future<void> _loadOptions() async {
    final pet = _pet;
    setState(() {
      _options = const [];
      _optionsLoading = pet?.chainId != null;
    });
    if (pet == null || pet.chainId == null) return;
    final (options, _) =
        await PetRpcP2.fetchEvoOptions(pet.chainId!, pet.stage + 1);
    if (!mounted) return;
    setState(() {
      _options = options;
      _optionsLoading = false;
    });
  }

  void _selectPet(String id) {
    if (id == _petId) return;
    setState(() => _petId = id);
    _loadOptions();
  }

  void _toast(String msg) => showSnackBar(context, msg);

  // ---------- 写操作 ----------

  Future<void> _evolve(PetEvoStageOptionModel option,
      {bool lockTarget = false}) async {
    final pet = _pet;
    if (pet == null || _busy) return;
    // 只有玩家自选（或唯一分支）才回传目标形态；概率分支传 null 交服务端掷取
    final byUser = lockTarget || option.pickMode == PetPickMode.userChoice;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认进化'),
        content: Text(byUser
            ? '「${pet.name}」将进化为「${option.name}」，此过程不可逆。'
            : '「${pet.name}」将进入下一阶段，形态由概率决定，此过程不可逆。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('进化')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final (result, err) = await PetRpcP2.evolve(pet.id,
        targetSpeciesId: byUser ? option.speciesId : null);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null || result == null) return _toast(petRpcErrorText(err));
    await _showEvolved(result);
    await _load(force: true);
  }

  Future<void> _wash(PetBagItemModel item) async {
    final pet = _pet;
    if (pet == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认洗练特性'),
        content: Text('使用「${item.name}」重掷「${pet.name}」的特性？'
            '新特性直接覆盖旧特性，不提供回退。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('洗练')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final (result, err) = await PetRpcP2.washTrait(pet.id, item.itemId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null || result == null) return _toast(petRpcErrorText(err));
    _toast(result.traitName == null
        ? '洗练完成：这次没掷出特性，伙伴暂时没有特性'
        : (result.changed
            ? '洗出了新特性「${result.traitName}」'
            : '掷回同一个特性「${result.traitName}」'));
    await _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('养成'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [for (final t in PetGrowthTab.values) Tab(text: t.label)],
        ),
      ),
      body: _loading
          ? const Center(child: LoadingWidget())
          : RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: TabBarView(
                controller: _tabs,
                children: [_evolveTab(cs), _traitTab(cs)],
              ),
            ),
    );
  }

  // ---------- 进化页签 ----------

  Widget _evolveTab(ColorScheme cs) {
    final pet = _pet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        petGrowthPetSelector(cs, _details, _petId, _selectPet),
        const SizedBox(height: 12),
        if (_error != null) _errorLine(cs),
        if (pet == null)
          const EmptyWidget(message: '还没有伙伴，先去孵一只吧')
        else ..._evolveBlocks(cs, pet),
      ],
    );
  }

  List<Widget> _evolveBlocks(ColorScheme cs, PetPetDetailModel pet) {
    return [
      petGrowthHeadCard(cs, pet),
      const SizedBox(height: 14),
      if (!pet.rearing) ...[
        Text('伙伴正在${pet.status?.label ?? '外出'}，回到身边后才能进化',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
      ] else if (pet.chainId == null)
        Text('这个形态还没有配置进化路线',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
      else if (_optionsLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4))),
        )
      else if (_options.isEmpty)
        Text('已经是最终形态了',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
      else
        ..._evolveOptions(cs, pet),
    ];
  }

  /// 候选形态：玩家自选分支各给一个按钮；概率分支合并成一个「由概率决定」入口
  ///
  /// 唯一分支时显式回传目标形态（与服务端「v_cnt=1 直取该行」等价）；
  /// 多分支的 weighted_random 一律回传 null，交服务端按 branch_weight 掷取。
  List<Widget> _evolveOptions(ColorScheme cs, PetPetDetailModel pet) {
    if (_options.length == 1) {
      final only = _options.first;
      return [
        petGrowthOptionCard(cs, pet, only,
            busy: _busy, onEvolve: () => _evolve(only, lockTarget: true))
      ];
    }
    final chosen =
        _options.where((o) => o.pickMode == PetPickMode.userChoice).toList();
    final rolled =
        _options.where((o) => o.pickMode != PetPickMode.userChoice).toList();
    return [
      for (final o in chosen)
        petGrowthOptionCard(cs, pet, o,
            busy: _busy, onEvolve: () => _evolve(o)),
      if (rolled.isNotEmpty) ...[
        const SizedBox(height: 10),
        petGrowthRollCard(cs, rolled,
            busy: _busy, onEvolve: () => _evolve(rolled.first)),
      ],
    ];
  }

  Future<void> _showEvolved(PetEvolveResultModel result) async {
    final img = petPortraitArt(result.speciesCode);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (img != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      Image.asset(img, height: 190, fit: BoxFit.contain),
                ),
              const SizedBox(height: 12),
              Text('✨ 进化完成！',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('${result.name} · ${result.rarity}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (result.goldSpent > 0)
                Text('消耗金币 ${result.goldSpent}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('太好了'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 特性页签 ----------

  Widget _traitTab(ColorScheme cs) {
    final pet = _pet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        petGrowthPetSelector(cs, _details, _petId, _selectPet),
        const SizedBox(height: 12),
        petGrowthHeadCard(cs, pet),
        const SizedBox(height: 14),
        if (pet != null && !pet.rearing)
          Text('伙伴正在${pet.status?.label ?? '外出'}，回到身边后才能洗练',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
        else if (_washItems.isEmpty)
          Text('背包里还没有特性洗练剂，可在商城「全部」里购买',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
        else
          for (final item in _washItems)
            petGrowthWashRow(cs, item,
                busy: _busy, onWash: () => _wash(item)),
        const SizedBox(height: 12),
        Text('洗练会重掷这只伙伴的特性，新结果直接覆盖旧特性、不可回退；'
            '也可能一次洗不出特性（属正常结果）。',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _errorLine(ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(_error ?? '',
            style: TextStyle(fontSize: 12, color: cs.error)),
      );
}
