import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_adventure_cards.dart';
import '../widgets/pet_claim_result_dialog.dart';
import '../widgets/pet_home_adventure.dart';

/// 历险页
///
/// 状态机（与 pet_adventures.status 对齐）：
/// - 无进行中 → 历险地列表 → 选档位（config.adventure_tiers）→ 出发；
///   等级 = 硬门槛（不达标灰置）；属性 = 结算判据（不达标红显「有风险」，
///   仍可出发，claim 时判 failed 执行惩罚）；健康 = 出发门槛（阈值提示）；
///   「为你匹配」推荐卡来自 rpc_pet_adventure_match（可忽略）；
/// - ongoing  → 倒计时，结束出现「查看结果」（claim roll 四类结果）；
/// - awaiting_rescue → 自救窗口内用救援道具 / 超时 NPC 兜底。
class PetAdventureScreen extends StatefulWidget {
  const PetAdventureScreen({
    super.key,
    required this.petId,
    required this.petName,
    required this.adventure,
    required this.tiers,
    required this.petLevel,
    required this.petAttrs,
    required this.petHealth,
    required this.healthThreshold,
  });

  final String petId;
  final String petName;

  /// 主页传入的进行中历险（null = 无进行中，直接列出险地）
  final PetAdventureBriefModel? adventure;

  /// pet_config.adventure_tiers：[{tier,minutes,label}]
  final List<Map<String, dynamic>> tiers;

  /// 宠物等级（历险地等级硬门槛灰置依据）
  final int petLevel;

  /// 四维属性当前值（属性要求行对比红显；最终结算在服务端 claim）
  final Map<String, int> petAttrs;

  /// 健康状态值（出发门槛提示数据源）
  final int petHealth;

  /// 健康出发门槛（config.adventure_health_threshold；0 = 未配置不提示）
  final int healthThreshold;

  @override
  State<PetAdventureScreen> createState() => _PetAdventureScreenState();
}

class _PetAdventureScreenState extends State<PetAdventureScreen> {
  bool _loading = true;
  String? _error;
  List<PetSpotModel> _spots = const [];
  PetAdventureBriefModel? _adv;
  Timer? _tick;
  bool _busy = false;

  /// 「为你匹配」推荐历险地 id（rpc_pet_adventure_match；静默降级为 null）
  String? _matchedSpotId;

  @override
  void initState() {
    super.initState();
    _adv = widget.adventure;
    _load();
    _loadMatch();
    // 每分钟刷新倒计时（结束即触发领奖按钮出现）
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// 为你匹配（静默）：门槛不达标/调用失败均降级为无推荐，不打扰用户
  Future<void> _loadMatch() async {
    final (data, err) = await PetRpc.adventureMatch(widget.petId);
    if (err != null || data == null || !mounted) return;
    final spots = data['spots'];
    if (spots is List) {
      for (final s in spots) {
        if (s is Map && s['recommended'] == true) {
          setState(() => _matchedSpotId = s['id'] as String?);
          return;
        }
      }
    }
  }

  PetSpotModel? get _matchedSpot {
    if (_matchedSpotId == null) return null;
    for (final s in _spots) {
      if (s.id == _matchedSpotId) return s;
    }
    return null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (spots, err) = await PetRpc.fetchSpots();
    if (mounted) {
      setState(() {
        _spots = spots;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  Future<void> _start(PetSpotModel spot, Map<String, dynamic> tier) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await PetRpc.adventureStart(
      petId: widget.petId,
      spotId: spot.id,
      tier: tier['tier'] as String? ?? '',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      return;
    }
    await _reloadSummary();
    if (mounted) Navigator.pop(context);
  }

  /// 出发后/领取后重取总览拿最新 ongoing 状态
  Future<void> _reloadSummary() async {
    final summary = await PetService.instance.fetchSummary();
    if (mounted) {
      setState(() => _adv = summary?.ongoingAdventure);
    }
  }

  Future<void> _claim() async {
    if (_busy || _adv == null) return;
    setState(() => _busy = true);
    final (data, err) = await PetRpc.adventureClaim(_adv!.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      await _reloadSummary();
      return;
    }
    final status = PetAdventureStatus.fromCode(data?['status'] as String?);
    if (status == PetAdventureStatus.awaitingRescue) {
      await _reloadSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('遭遇险情！请在自救窗口内使用救援道具')),
        );
      }
      return;
    }
    if (status == PetAdventureStatus.failed) {
      // 属性未达标结算：终态失败（宠物已回家），展示实际生效惩罚明细
      if (mounted) {
        await showPetPenaltyDialog(context,
            penalty: (data?['penalty'] as Map?)?.cast<String, dynamic>());
      }
      await _reloadSummary();
      return;
    }
    final gold = (data?['gold'] as num?)?.toInt() ?? 0;
    final exp = (data?['exp'] as num?)?.toInt() ?? 0;
    final result = data?['result_type'] as String? ?? 'play';
    // 掉落明细（fix_pet_adventure_claim_items：claim 返回 items: [{code,name,qty}]）
    final items = <({String name, int qty})>[];
    final rawItems = data?['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          items.add((
            name: (it['name'] as String?) ?? (it['code'] as String? ?? '道具'),
            qty: (it['qty'] as num?)?.toInt() ?? 1,
          ));
        }
      }
    }
    // 结算弹窗：结果类型 + 金币/经验 + 掉落明细，关闭后再刷新总览
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => PetClaimResultDialog(
          result: result,
          gold: gold,
          exp: exp,
          items: items,
        ),
      );
    }
    await _reloadSummary();
  }

  /// 召回确认：复用主页共享 helper（AlertDialog 二次确认 → 无奖励中断），
  /// 返回 true 表示状态已变化需刷新总览
  Future<void> _confirmRecall() async {
    if (_busy || _adv == null) return;
    final changed = await recallAdventureConfirmed(context, _adv!.id);
    if (changed && mounted) await _reloadSummary();
  }

  Future<void> _rescue({String? itemId}) async {
    if (_busy || _adv == null) return;
    setState(() => _busy = true);
    final err = await PetRpc.adventureRescue(_adv!.id, itemId: itemId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(itemId == null ? 'NPC 已救助，平安归来' : '自救成功，平安归来')),
      );
    }
    await _reloadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历险')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: LoadingWidget());
    final adv = _adv;
    if (adv != null && adv.status == PetAdventureStatus.ongoing) {
      return _ongoingView(adv);
    }
    if (adv != null && adv.status == PetAdventureStatus.awaitingRescue) {
      return _rescueView(adv);
    }
    return _spotsView();
  }

  // ---------- 出发前：历险地列表 ----------

  Widget _spotsView() {
    final cs = Theme.of(context).colorScheme;
    if (_error != null && _spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_spots.isEmpty) {
      return const EmptyWidget(message: '暂无开放的历险地，敬请期待新地点');
    }
    // 健康出发门槛提示（历险失败惩罚会扣健康；阈值 0 = 未配置不提示）
    final healthLow = widget.healthThreshold > 0 &&
        widget.petHealth < widget.healthThreshold;
    final matched = _matchedSpot;
    final cards = <Widget>[
      if (healthLow)
        Card(
          color: cs.errorContainer,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('宠物健康状况不佳，恢复健康后再出发吧'),
          ),
        ),
      if (matched != null)
        PetMatchBanner(
            spotName: matched.name, onTap: () => _showTierSheet(matched)),
      for (final spot in _spots)
        petSpotCard(
          context,
          spot: spot,
          petLevel: widget.petLevel,
          petAttrs: widget.petAttrs,
          onTap: () => _showTierSheet(spot),
        ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => cards[i],
    );
  }

  void _showTierSheet(PetSpotModel spot) {
    if (widget.tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('历险档位未配置，请联系管理员')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择「${spot.name}」的历险时长',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final t in widget.tiers)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(t['label'] as String? ?? t['tier'] as String? ?? ''),
                subtitle: Text('${t['minutes'] ?? '-'} 分钟'),
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                onTap: _busy ? null : () => _start(spot, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------- 进行中：倒计时 + 领取 ----------

  Widget _ongoingView(PetAdventureBriefModel adv) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final end = adv.endAt;
    final finished = end == null || !now.isBefore(end);
    final remaining = end?.difference(now);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('${widget.petName} 正在外出历险',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (!finished) ...[
              Text(
                '预计 ${remaining!.inMinutes > 0 ? '${remaining.inMinutes} 分钟后' : '即将'}归来',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              const Text('历险结束后回来查看结果', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _confirmRecall,
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('召回'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _claim,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.redeem_outlined),
                label: const Text('查看历险结果'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- 遇险：自救 ----------

  Widget _rescueView(PetAdventureBriefModel adv) {
    final cs = Theme.of(context).colorScheme;
    final deadline = adv.rescueDeadline;
    final expired = deadline != null && !DateTime.now().isBefore(deadline);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 72, color: cs.error),
            const SizedBox(height: 16),
            Text('${widget.petName} 遇到险情！',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              expired
                  ? '已超出自救窗口，将由 NPC 兜底救助'
                  : '自救窗口截止：${deadline == null ? '-' : DateTimeUtils.formatToMinute(deadline)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (!expired)
              FilledButton.icon(
                onPressed: _busy ? null : () => _rescueWithItem(),
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('使用救援道具自救'),
              ),
            const SizedBox(height: 8),
            Text(
              expired ? '点击下方按钮完成 NPC 救助' : '没有救援道具？等待窗口结束由 NPC 救助',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (expired) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _rescue(),
                child: const Text('等待 NPC 救助'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rescueWithItem() async {
    // 从背包找救援道具（effect.type=rescue）
    final (bag, err) = await PetRpc.fetchBag();
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(petRpcErrorText(err))));
      }
      return;
    }
    PetBagItemModel? rescueItem;
    for (final b in bag) {
      if (b.effectType == 'rescue') {
        rescueItem = b;
        break;
      }
    }
    if (rescueItem == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('背包中没有救援道具，可去商城购买或等待 NPC 救助')),
        );
      }
      return;
    }
    await _rescue(itemId: rescueItem.itemId);
  }
}
