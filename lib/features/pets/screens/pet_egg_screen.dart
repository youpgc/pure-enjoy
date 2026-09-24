import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_p2_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../services/pet_service.dart';
import '../utils/pet_art.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_home_overlays.dart';
import '../widgets/pet_item_icon.dart';

/// 孵蛋页（P2：即开 + 等待孵化双通道）
///
/// 状态机与服务端一致（[PetEggStatus]）：
/// - instant 蛋：unopened →（rpc_pet_hatch_instant）出宠；
/// - wait 蛋：unopened →（rpc_pet_hatch_wait）waiting →（到点或加速）ready
///   →（rpc_pet_hatch_instant）出宠；服务端闸门 PET_EGG_NOT_READY。
/// 加速两档（rpc_pet_hatch_accelerate）：道具档读 pet_items.effect.minutes，
/// 金币档读 pet_config.reserved.hatch.accel_gold——**均不在客户端写死**。
class PetEggScreen extends StatefulWidget {
  const PetEggScreen({super.key});

  @override
  State<PetEggScreen> createState() => _PetEggScreenState();
}

class _PetEggScreenState extends State<PetEggScreen> {
  bool _loading = true;
  String? _error;
  List<PetEggModel> _eggs = const [];
  List<PetBagItemModel> _accelItems = const [];
  PetReservedModel _reserved = const PetReservedModel({});
  int _gold = 0;
  String? _busyId;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    // 倒计时逐秒刷新（仅在有 waiting 蛋时重绘，避免无谓 setState）
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _eggs.any((e) => e.isWaiting)) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh) await PetService.instance.invalidateSummary();
    final (summary, summaryErr) = await PetService.instance.fetchSummary();
    final (eggs, err) = await PetRpc.fetchEggs();
    final (bag, _) = await PetRpc.fetchBag();
    final (reserved, _) = await PetRpcP2.fetchReserved();
    if (!mounted) return;
    setState(() {
      _eggs = eggs;
      // 金币余额取自总览：总览失败虽不影响蛋列表，也必须报出来（否则兑换/加速
      // 按钮上的金币恒为 0 却没有任何解释）
      _error = err != null ? petRpcErrorText(err) : summaryErr;
      _accelItems = bag
          .where((e) => e.effectType == PetItemEffectType.hatchAccel.code)
          .toList();
      _reserved = reserved;
      _gold = summary?.wallet.goldBalance ?? 0;
      _loading = false;
    });
  }

  void _toast(String msg) {
    if (mounted) showSnackBar(context, msg);
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    await action();
    if (mounted) setState(() => _busyId = null);
  }

  /// 出宠（instant 蛋直接孵 / wait 蛋到点领取），服务端同一函数
  Future<void> _hatch(PetEggModel egg) => _run(egg.id, () async {
        final (result, err) = await PetRpc.hatchEgg(egg.id);
        if (!mounted) return;
        if (err != null || result == null) {
          return _toast(petRpcErrorText(err));
        }
        await showPetBirthDialog(
          context,
          img: petBirthArt(result.speciesCode),
          result: result,
        );
        await _load(forceRefresh: true);
      });

  /// 让 wait 蛋开始计时（幂等：已在计时中直接回当前状态）
  Future<void> _startWaiting(PetEggModel egg) => _run(egg.id, () async {
        final (data, err) = await PetRpcP2.hatchWait(egg.id);
        if (!mounted) return;
        if (err != null || data == null) {
          return _toast(petRpcErrorText(err));
        }
        _toast(data.waitHours == null
            ? '已开始孵化'
            : '已开始孵化，约 ${data.waitHours} 小时后出壳');
        await _load();
      });

  Future<void> _accelerate(PetEggModel egg) async {
    final picked = await showDialog<({String? itemId, bool gold})>(
      context: context,
      builder: (ctx) => _AccelDialog(
        items: _accelItems,
        goldCost: _reserved.accelGold,
        balance: _gold,
      ),
    );
    if (picked == null || !mounted) return;
    await _run(egg.id, () async {
      final (data, err) = await PetRpcP2.hatchAccelerate(
        egg.id,
        mode: picked.itemId == null ? PetAccelMode.gold : PetAccelMode.item,
        itemId: picked.itemId,
      );
      if (!mounted) return;
      if (err != null || data == null) return _toast(petRpcErrorText(err));
      _toast(data.isReady ? '到点了，快领出你的伙伴' : '已加速');
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('孵蛋')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _eggs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _load(), child: const Text('重试')),
          ],
        ),
      );
    }
    if (_eggs.isEmpty) {
      return const EmptyWidget(message: '背包里还没有蛋，去商城看看吧');
    }
    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _eggs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _eggCard(cs, _eggs[i]),
      ),
    );
  }

  Widget _eggCard(ColorScheme cs, PetEggModel egg) {
    final status = egg.status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PetItemIcon(
                    iconKey: egg.iconKey,
                    fallback: Icons.egg_outlined,
                    size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(egg.itemName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (status != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(status.label,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSecondaryContainer)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              egg.isWaiting
                  ? '正在孵化中，倒计时结束即可领取'
                  : egg.isReady
                      ? '已经成熟了，点下面的按钮领出伙伴'
                      : egg.isInstant
                          ? '即开型：点开立刻见到伙伴'
                          : '传说蛋：需要先开始孵化计时',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _primaryButton(cs, egg)),
                if (egg.isWaiting) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busyId == null ? () => _accelerate(egg) : null,
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('加速'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(ColorScheme cs, PetEggModel egg) {
    final busy = _busyId == egg.id;
    final VoidCallback? onPressed;
    final String label;
    if (egg.isWaiting) {
      // 倒计时中：主按钮位只作计时显示，加速走右侧按钮
      onPressed = null;
      label = _countdown(egg.remaining);
    } else if (egg.isReady) {
      onPressed = _busyId == null ? () => _hatch(egg) : null;
      label = '领取';
    } else if (egg.isInstant) {
      onPressed = _busyId == null ? () => _hatch(egg) : null;
      label = '立即孵化';
    } else {
      onPressed = _busyId == null ? () => _startWaiting(egg) : null;
      label = '开始孵化';
    }
    return FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: egg.isReady ? cs.primary : cs.tertiary),
      onPressed: onPressed,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }

  static String _countdown(Duration? left) {
    if (left == null) return '--:--:--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }
}

/// 加速选择弹窗：道具档（读背包 hatch_accel 行）与金币档（读 reserved）。
///
/// 回传 `({String? itemId, bool gold})`：itemId 非空即道具档，null 即金币档。
/// 两档都无可用项（无道具且后台未配 accel_gold）时只给提示文案。
class _AccelDialog extends StatelessWidget {
  const _AccelDialog(
      {required this.items, required this.goldCost, required this.balance});

  final List<PetBagItemModel> items;
  final int? goldCost;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cost = goldCost;
    final goldOk = cost != null && balance >= cost;
    return AlertDialog(
      title: const Text('加速孵化'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('背包里还没有孵化加速剂，可去商城「全部」里购买',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            for (final it in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: PetItemIcon(
                    iconKey: it.iconKey, fallback: Icons.speed, size: 24),
                title: Text('${it.name} ×${it.quantity}'),
                subtitle: Text(it.effect['minutes'] is num
                    ? '提前 ${(it.effect['minutes'] as num).toInt()} 分钟'
                    : '提前时长见后台配置'),
                trailing: const Text('使用'),
                onTap: () =>
                    Navigator.pop(context, (itemId: it.itemId, gold: false)),
              ),
            if (cost != null) ...[
              const Divider(height: 20),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.monetization_on_outlined, color: cs.tertiary),
                title: Text(cost == 0 ? '金币加速（本次免费）' : '金币加速 · $cost 金币'),
                subtitle: Text(
                  goldOk ? '余额 $balance' : '余额不足（$balance）',
                  style: TextStyle(
                      fontSize: 11, color: goldOk ? cs.onSurfaceVariant : cs.error),
                ),
                trailing: const Text('立即到点'),
                onTap: goldOk
                    ? () => Navigator.pop(context, (itemId: null, gold: true))
                    : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
      ],
    );
  }
}
