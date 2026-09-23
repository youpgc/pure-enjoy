import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../../../constants/pet.dart';
import '../models/pet_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_errors.dart';
import 'pet_shop_screen.dart';

/// 寄养仓库页（P0-3 补齐：宠物在「养育格 <-> 寄养格」之间搬运）
///
/// 数据源：`rpc_pet_summary` 的 `pets`（含 status）与 `capacities`，
/// 不额外查表——占用量与容量与服务端判据同源（status='fostered' 计数 /
/// coalesce(capacity, config_init)），避免双真相源。
///
/// 写路径：唯一入口 `rpc_pet_foster_move`（feature_pet_foster_20260921.sql）。
/// 寄养中的宠物不吃离线衰减（补算只作用于 rearing），也不参与喂养/互动/历险
/// ——那些 RPC 都带 status='rearing' 门槛，客户端无需重复判定。
class PetFosterScreen extends StatefulWidget {
  const PetFosterScreen({super.key});

  @override
  State<PetFosterScreen> createState() => _PetFosterScreenState();
}

class _PetFosterScreenState extends State<PetFosterScreen> {
  PetSummaryModel? _summary;
  bool _loading = true;
  bool _enabled = true;
  String? _error;

  /// 正在搬运的宠物 id（服务端为串行锁，客户端只需防连点）
  String? _movingId;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _error = summary == null ? '数据加载失败，请稍后重试' : null;
      _loading = false;
    });
  }

  Future<void> _move(PetBriefModel pet, String action) async {
    if (_movingId != null) return;
    setState(() => _movingId = pet.id);
    final err = await PetRpc.fosterMove(pet.id, action);
    if (!mounted) return;
    if (err != null) {
      _toast(petRpcErrorText(err));
      setState(() => _movingId = null);
      return;
    }
    // 成功后失效总览缓存并重拉（养育/寄养两栏与格位徽标一起刷新）
    await _load(force: true);
    if (!mounted) return;
    setState(() => _movingId = null);
    _toast(action == 'to_foster' ? '${pet.name} 已安置进寄养仓库' : '${pet.name} 接回身边啦');
  }

  void _toast(String msg) => showSnackBar(context, msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('寄养仓库')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: LoadingWidget());
    if (!_enabled) return const EmptyWidget(message: '宠物功能暂未开放');
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
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

    final summary = _summary;
    if (summary == null) return const EmptyWidget(message: '暂无宠物');

    final rearing =
        summary.pets.where((p) => p.status == PetPetStatus.rearing).toList();
    final fostered =
        summary.pets.where((p) => p.status == PetPetStatus.fostered).toList();
    final fosterCap = summary.capacities?.foster ?? 0;
    final rearingCap = summary.capacities?.rearing ?? 0;
    // 历险/繁育中的宠物既不在养育也不在寄养，单独一行说明避免"我的宠物少了"的误解
    final other = summary.pets.length - rearing.length - fostered.length;

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _capacityCard(
            title: '寄养格',
            used: fostered.length,
            capacity: fosterCap,
            icon: Icons.luggage_outlined,
            colorScheme: colorScheme,
            hint: fosterCap <= 0
                ? '寄养格尚未开启：在商城「扩容」分类购买寄养扩容即可解锁'
                : '寄养中的宠物不消耗饱食与心情，也不会受伤，随时可接回',
            onOpenShop: fosterCap <= 0,
          ),
          const SizedBox(height: 12),
          _capacityCard(
            title: '养育格',
            used: rearing.length,
            capacity: rearingCap,
            icon: Icons.home_outlined,
            colorScheme: colorScheme,
            hint: '养育格满时无法接回寄养宠物，可先寄养其他伙伴腾位',
            onOpenShop: false,
          ),
          if (other > 0) ...[
            const SizedBox(height: 8),
            Text(
              '另有 $other 只伙伴正在历险/繁育中，不出现在以下列表',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('身边养育中（${rearing.length}/$rearingCap）', colorScheme),
          if (rearing.isEmpty)
            _emptyRow('当前没有在养的宠物', colorScheme)
          else
            ...rearing.map(
              (p) => _petRow(
                p,
                colorScheme,
                actionLabel: '送去寄养',
                actionIcon: Icons.luggage_outlined,
                enabled: fostered.length < fosterCap,
                action: 'to_foster',
              ),
            ),
          const SizedBox(height: 18),
          _sectionTitle('寄养仓库中（${fostered.length}/$fosterCap）', colorScheme),
          if (fostered.isEmpty)
            _emptyRow('仓库还空着，把伙伴寄养进来吧', colorScheme)
          else
            ...fostered.map(
              (p) => _petRow(
                p,
                colorScheme,
                actionLabel: '接回身边',
                actionIcon: Icons.home_outlined,
                enabled: rearing.length < rearingCap,
                action: 'from_foster',
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _emptyRow(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// 容量卡：已用/上限 + 说明；需要时挂「去商城」按钮（寄养格未开启）
  Widget _capacityCard({
    required String title,
    required int used,
    required int capacity,
    required IconData icon,
    required ColorScheme colorScheme,
    required String hint,
    required bool onOpenShop,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '$used/$capacity',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (onOpenShop) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openShop,
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text('去商城购买扩容'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openShop() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PetShopScreen(
            goldBalance: _summary?.wallet.goldBalance ?? 0,
          ),
        ),
      );

  Widget _petRow(
    PetBriefModel pet,
    ColorScheme colorScheme, {
    required String actionLabel,
    required IconData actionIcon,
    required bool enabled,
    required String action,
  }) {
    final moving = _movingId == pet.id;
    final busy = _movingId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pet.rarity} · Lv.${pet.level} · 饱食 ${pet.hunger} · 心情 ${pet.mood}',
                    style: TextStyle(
                      fontSize: 12,
                      color: pet.status == PetPetStatus.fostered
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 104,
              child: FilledButton.tonalIcon(
                onPressed: (enabled && !busy) ? () => _move(pet, action) : null,
                icon: moving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(actionIcon, size: 18),
                label: Text(moving ? '搬运中' : actionLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
