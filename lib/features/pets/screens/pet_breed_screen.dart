import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/pet_models.dart';
import '../models/pet_p2_breed_models.dart';
import '../models/pet_p2_models.dart';
import '../services/pet_rpc_p2.dart';
import '../services/pet_service.dart';
import '../utils/pet_errors.dart';
import 'pet_bag_screen.dart';
import 'pet_shop_screen.dart';

/// 繁育页（P2）
///
/// 裁决全在服务端 `rpc_pet_breed_start`（同系、异性、双亲在养、亲密度达
/// `pet_config.reserved.breeding.intimacy_min`、手续费扣金币）；本页只做
/// **候选引导**（同系异性才可选），门槛数值全部读后台配置，不写死（铁律 2）。
/// 领蛋 `rpc_pet_breed_claim` 的 `bag_full` 是 P2 **唯一的软失败**（不抛异常）：
/// 亲代已释放、单据停在 ready，清包后重调即可，故此处只引导去背包不清单。
class PetBreedScreen extends StatefulWidget {
  const PetBreedScreen({super.key});

  @override
  State<PetBreedScreen> createState() => _PetBreedScreenState();
}

class _PetBreedScreenState extends State<PetBreedScreen> {
  bool _loading = true;
  String? _error;
  PetSummaryModel? _summary;
  List<PetBreedOrderModel> _orders = const [];
  PetReservedModel _reserved = const PetReservedModel({});
  bool _unlocked = false;

  /// 已选宠物 id（最多两只，点第三只时提示先取消一只）
  final List<String> _picked = [];
  bool _busy = false;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (force) await PetService.instance.invalidateSummary();
    final (summary, summaryErr) =
        await PetService.instance.fetchSummary(forceRefresh: force);
    final (features, _) = await PetRpcP2.fetchUnlockedFeatures();
    final (orders, ordersErr) = await PetRpcP2.fetchBreedOrders();
    final (reserved, _) = await PetRpcP2.fetchReserved();
    if (!mounted) return;
    // 结配后双亲转 breeding（不再是在养候选），选中项自动失效
    final rearing = (summary?.pets ?? const <PetBriefModel>[])
        .where((p) => p.status == PetPetStatus.rearing)
        .map((p) => p.id)
        .toSet();
    setState(() {
      _summary = summary;
      _unlocked = features.any(
          (f) => f.featureKey == PetFeatureKey.breeding.code);
      _orders = orders;
      _reserved = reserved;
      _picked.removeWhere((id) => !rearing.contains(id));
      _error = summary == null
          ? (summaryErr ?? '数据加载失败，请稍后重试')
          : (ordersErr == null ? null : petRpcErrorText(ordersErr));
      _loading = false;
    });
  }

  void _toast(String msg) => showSnackBar(context, msg);

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _load());
  }

  // ---------- 候选与配对判定（仅引导，服务端仍会复核） ----------

  List<PetBriefModel> get _candidates => (_summary?.pets ??
          const <PetBriefModel>[])
      .where((p) => p.status == PetPetStatus.rearing)
      .toList();

  List<PetBriefModel>? get _pair {
    if (_picked.length != 2) return null;
    final pets =
        _candidates.where((p) => _picked.contains(p.id)).toList();
    return pets.length == 2 ? pets : null;
  }

  /// 配对不可结配的原因（null = 可以点结配）
  String? get _pairProblem {
    final pair = _pair;
    if (pair == null) return _picked.isEmpty ? '请选择两只伙伴' : '再选一只伙伴';
    final a = pair[0];
    final b = pair[1];
    if (a.family != b.family) return '需要同一系别（例如猫 × 猫）';
    if (a.gender == null || b.gender == null) {
      return '性别信息缺失，请下拉刷新后重试';
    }
    if (a.gender == b.gender) return '需要一公一母';
    final min = _reserved.breedIntimacyMin;
    if (min != null && (a.intimacy < min || b.intimacy < min)) {
      return '亲密度需达到 $min（多喂养互动会涨）';
    }
    return null;
  }

  void _toggle(PetBriefModel pet) {
    setState(() {
      if (_picked.contains(pet.id)) {
        _picked.remove(pet.id);
      } else if (_picked.length >= 2) {
        _toast('一次只能安排两只伙伴结配');
      } else {
        _picked.add(pet.id);
      }
    });
  }

  // ---------- 写操作 ----------

  Future<void> _start() async {
    final pair = _pair;
    if (pair == null || _busy) return;
    final a = pair[0];
    final b = pair[1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认结配'),
        content: Text(
            '让「${a.name}」与「${b.name}」结配？\n'
            '完成后会得一枚蛋${_feeText()}\n'
            '孕期约 ${_reserved.breedGestationHours ?? '--'} 小时，期间两只伙伴不可喂食互动。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('结配')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final (result, err) =
        await PetRpcP2.breedStart(a.id, b.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null || result == null) {
      return _toast(petRpcErrorText(err));
    }
    _toast('结配成功，约 ${result.gestationHours} 小时后可领蛋'
        '${result.feeGold > 0 ? '（已扣 ${result.feeGold} 金币）' : ''}');
    await _load(force: true);
  }

  /// 手续费文案（读 reserved，未配置不猜数值）
  String _feeText() {
    final fee = _reserved.breedFeeGold;
    if (fee == null) return '（手续费见后台配置）';
    return fee == 0 ? '（本次免费）' : '，需付 $fee 金币';
  }

  Future<void> _claim(PetBreedOrderModel order) async {
    if (_claimingId != null || _busy) return;
    setState(() => _claimingId = order.id);
    final (result, err) = await PetRpcP2.breedClaim(order.id);
    if (!mounted) return;
    setState(() => _claimingId = null);
    if (err != null || result == null) {
      return _toast(petRpcErrorText(err));
    }
    if (result.bagFull) {
      _toast('背包已满（${result.used}/${result.capacity}），先清理再回来领蛋');
      return _push(const PetBagScreen(petId: null));
    }
    _toast('领到「${result.eggName}」'
        '${result.rarity.isEmpty ? '' : ' · ${result.rarity}'}，在背包里点它就能孵');
    await _load(force: true);
  }

  // ---------- 布局 ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('繁育')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? '数据加载失败', style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => _load(force: true), child: const Text('重试')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!_unlocked)
            _unlockCard(cs)
          else ...[
            _ruleCard(cs),
            const SizedBox(height: 14),
            _title(cs, '挑选两只伙伴'),
            const SizedBox(height: 8),
            if (_candidates.length < 2)
              Text('在养的伙伴不足两只，先去接回伙伴或领一只新的吧',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final p in _candidates) _petTile(cs, p)],
              ),
            const SizedBox(height: 14),
            _startRow(cs),
            const SizedBox(height: 20),
          ],
          _title(cs, '繁育记录'),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            Text(_unlocked ? '还没有结配记录' : '',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
          else
            for (final o in _orders) _orderCard(cs, o),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(fontSize: 12, color: cs.error)),
          ],
        ],
      ),
    );
  }

  Widget _title(ColorScheme cs, String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      );

  /// 未解锁繁育功能：给商城直达路径（不在客户端造解锁道具名）
  Widget _unlockCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: cs.tertiary),
                const SizedBox(width: 8),
                const Text('繁育尚未解锁',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text('在商城购买「解锁」类道具，使用后即刻开放繁育与结配。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _push(
                  PetShopScreen(goldBalance: _summary?.wallet.goldBalance ?? 0)),
              child: const Text('去商城看看'),
            ),
          ],
        ),
      ),
    );
  }

  /// 门槛说明（全部取自 pet_config.reserved，未配置的项不显示也不猜）
  Widget _ruleCard(ColorScheme cs) {
    final rows = <String>[
      '同一系别、一公一母',
      if (_reserved.breedIntimacyMin != null)
        '双方亲密度 ≥ ${_reserved.breedIntimacyMin}',
      if (_reserved.breedGestationHours != null)
        '孕期约 ${_reserved.breedGestationHours} 小时',
      if (_reserved.breedFeeGold != null)
        '手续费 ${_reserved.breedFeeGold} 金币',
    ];
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $r',
                    style: TextStyle(
                        fontSize: 12.5, color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _petTile(ColorScheme cs, PetBriefModel pet) {
    final selected = _picked.contains(pet.id);
    final min = _reserved.breedIntimacyMin;
    final intimacyOk = min == null || pet.intimacy >= min;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _toggle(pet),
      child: Container(
        width: 112,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: selected ? cs.secondaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${pet.gender?.label ?? ''} ${pet.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${pet.rarity} · Lv${pet.level}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            Text('亲密 ${pet.intimacy}',
                style: TextStyle(
                    fontSize: 11,
                    color: intimacyOk ? cs.onSurfaceVariant : cs.error)),
          ],
        ),
      ),
    );
  }

  Widget _startRow(ColorScheme cs) {
    final problem = _pairProblem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: problem == null && !_busy ? _start : null,
          icon: const Icon(Icons.favorite_outline, size: 18),
          label: Text(_busy ? '处理中' : '开始结配'),
        ),
        if (problem != null) ...[
          const SizedBox(height: 6),
          Text(problem,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _orderCard(ColorScheme cs, PetBreedOrderModel order) {
    return Card(
      child: ListTile(
        title: Text(_namesOf(order),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(_orderHint(order),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: _orderTrailing(cs, order),
      ),
    );
  }

  /// 亲代展示名（单据只存 pet id，名字从总览的 pets 里按 id 取）
  String _namesOf(PetBreedOrderModel order) {
    String label(String id) {
      for (final p in _summary?.pets ?? const <PetBriefModel>[]) {
        if (p.id == id) return p.name;
      }
      return '伙伴';
    }

    return '${label(order.petAId)} × ${label(order.petBId)}';
  }

  String _orderHint(PetBreedOrderModel order) {
    final at = order.readyAt;
    if (order.isOngoing) {
      return at == null ? '孕期进行中' : '孕期 · ${DateTimeUtils.formatToMinute(at)} 可领蛋';
    }
    if (order.isReady) return '蛋已就绪，点右侧领取';
    return at == null ? '已产蛋' : '已产蛋 · ${DateTimeUtils.formatMonthDayTime(at)}';
  }

  Widget _orderTrailing(ColorScheme cs, PetBreedOrderModel order) {
    if (!order.isReady) {
      return Text(order.status?.label ?? '',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant));
    }
    return FilledButton.tonal(
      onPressed: _claimingId == null && !_busy ? () => _claim(order) : null,
      child: Text(_claimingId == order.id ? '领取中' : '领蛋'),
    );
  }
}
