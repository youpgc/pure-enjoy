import 'dart:async';

import 'package:flutter/material.dart';

import '../../../pets/models/pet_models.dart';
import '../../../pets/screens/pet_home_screen.dart';
import '../../../../constants/pet.dart';
import '../../../pets/services/pet_service.dart';
import '../../../pets/utils/pet_decay_display.dart';
import '../../../pets/utils/pet_gold_format.dart';

/// 首页「宠物状态卡」常驻区块（宠物系统主入口）
///
/// 门控策略（pet_enabled 关闭时入口隐藏）：
/// - 未登录 / 总开关关闭 / 总览拉取失败 → 不渲染任何内容（零占位）；
/// - 有宠物 → 头像 + 名字/等级 + 饱食/心情 + 金币余额，点击进入宠物主页；
/// - 无宠物 → 领养引导（初始蛋按 pet_config 配置在首次进入时幂等发放）。
///
/// 数据走 PetService SWR：缓存秒开 + 静默刷新；从宠物主页返回后 force 刷新。
class PetStatusCardSection extends StatefulWidget {
  const PetStatusCardSection({super.key});

  @override
  State<PetStatusCardSection> createState() => _PetStatusCardSectionState();
}

class _PetStatusCardSectionState extends State<PetStatusCardSection> {
  bool _loading = true;
  PetSummaryModel? _summary;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    // 首页下拉刷新等外部 force 拉取成功后自动重载（20261021 用户需求）
    PetService.summaryForceRefreshed.addListener(_onForcedRefresh);
    // 展示层实时衰减：每分钟按速率插值重绘（寄养冻结不衰减；服务端结算为准）
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onForcedRefresh() {
    // 非 force 读：触发方（下拉刷新等）刚以 force 拉取并写回缓存，
    // 这里再 force 会自增通知形成无限强刷循环（20261021 审查 P0）
    if (mounted) _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    PetService.summaryForceRefreshed.removeListener(_onForcedRefresh);
    super.dispose();
  }

  /// 拉取总览并刷新状态卡（force=跳过缓存）
  ///
  /// 先过 `pet_enabled` 门控再调 RPC：`rpc_pet_summary` 有副作用（首次进入幂等
  /// 发放初始包），后台关闭宠物系统时不应白跑一次写库。门控走 pet_config 轻量
  /// GET（1 分钟新鲜度缓存），成本低于一次 RPC。
  Future<void> _load({bool force = false}) async {
    if (!await PetService.instance.isPetEnabled()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // 状态卡按设计「拉不到就不渲染」，故错误文案在此不展示（错误态由宠物主页承担）
    final (summary, _) =
        await PetService.instance.fetchSummary(forceRefresh: force);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  void _openPetHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetHomeScreen()),
    ).then((_) => _load(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 加载中 / 功能关闭 / 拉取失败：不渲染（门控隐藏，不留占位）
    if (_loading || _summary == null) return const SizedBox.shrink();

    final summary = _summary!;
    final pet = summary.primaryPet;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: _openPetHome,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    pet == null ? Icons.pets_outlined : Icons.pets,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pet != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pet.name} · Lv.${pet.level}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Builder(builder: (_) {
                              // 虚弱阈值与历险出发门槛同源；缺键不判定不造默认值
                              final weakAt = (_summary!.config[
                                          'adventure_health_threshold']
                                      as num?)
                                  ?.toInt();
                              // 展示层实时衰减（寄养冻结；速率缺省 0=不衰减）
                              final anchor = _summary!.fetchedAt;
                              final fostered =
                                  pet.status == PetPetStatus.fostered;
                              final hunger = fostered || anchor == null
                                  ? pet.hunger
                                  : petDecayedStat(
                                      pet.hunger,
                                      anchor,
                                      (_summary!.config[
                                                  'decay_hunger_per_hour']
                                              as num?)
                                          ?.toInt() ??
                                          0,
                                      DateTime.now());
                              final mood = fostered || anchor == null
                                  ? pet.mood
                                  : petDecayedStat(
                                      pet.mood,
                                      anchor,
                                      (_summary!.config[
                                                  'decay_mood_per_hour']
                                              as num?)
                                          ?.toInt() ??
                                          0,
                                      DateTime.now());
                              final weak = weakAt != null && pet.health < weakAt;
                              return Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                        text:
                                            '饱食 $hunger · 心情 $mood · '),
                                    TextSpan(
                                      text: weak
                                          ? '健康 ${pet.health}（虚弱）'
                                          : '健康 ${pet.health}',
                                      style: weak
                                          ? TextStyle(
                                              color: colorScheme.error,
                                              fontWeight: FontWeight.bold)
                                          : null,
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            }),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '还没有宠物',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '点击领取你的第一只萌宠',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                // 金币余额徽标（pet_wallets.gold_balance）
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.paid_outlined,
                          size: 14, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        petGoldLabel(summary.wallet.goldBalance),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
