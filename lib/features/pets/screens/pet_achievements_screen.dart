import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../models/pet_p2_progress_models.dart';
import '../services/pet_rpc_p2.dart';
import '../services/pet_service.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_item_icon.dart';
import '../widgets/pet_toast.dart';
import '../widgets/pet_loading.dart';

/// 成就页（P2）
///
/// 数据源 `rpc_pet_achievement_check`：**服务端单调推进、永不回退**，
/// 每次进入页面即对齐一次进度（幂等，无副作用）；target/progress/completed
/// 全部由服务端下发，客户端不做任何达成判定（铁律 1）。
/// 领取走 `rpc_pet_achievement_claim`，背包不足整单回滚
/// （PET_BAG_FULL_CLAIM_RETRY），清包后可重领。
class PetAchievementsScreen extends StatefulWidget {
  const PetAchievementsScreen({super.key});

  @override
  State<PetAchievementsScreen> createState() => _PetAchievementsScreenState();
}

class _PetAchievementsScreenState extends State<PetAchievementsScreen> {
  bool _loading = true;
  String? _error;
  List<PetAchievementModel> _achs = const [];
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (achs, err) = await PetRpcP2.achievementCheck();
    if (!mounted) return;
    setState(() {
      _achs = achs;
      _error = err == null ? null : petRpcErrorText(err);
      _loading = false;
    });
  }

  Future<void> _claim(PetAchievementModel a) async {
    if (_claiming.contains(a.id)) return;
    setState(() => _claiming.add(a.id));
    final (result, err) = await PetRpcP2.achievementClaim(a.id);
    if (!mounted) return;
    setState(() => _claiming.remove(a.id));
    if (err != null || result == null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    final parts = <String>[
      if (result.gold > 0) '金币 +${result.gold}',
      // 道具逐个具名(领取结果 items 由服务端 claim 下发;无名回落 code)
      for (final it in result.items) '${it.name ?? it.code} ×${it.count}',
    ];
    showPetToast(context,
        '已领取「${result.title}」：${parts.isEmpty ? '奖励已发放' : parts.join('，')}');
    await PetService.instance.invalidateSummary();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('成就'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: PetPawLoading());
    if (_error != null && _achs.isEmpty) {
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
    if (_achs.isEmpty) {
      return const EmptyWidget(message: '成就还在准备中，过阵子再来看看吧');
    }
    // 渐进揭示：前置未全部领取的成就不进入列表（树状逐级现身；
    // 领取前置后下一次 check 刷新即现身），服务端 PREREQ_LOCKED 为兜底闸
    final claimedCodes =
        _achs.where((a) => a.claimed).map((a) => a.code).toSet();
    final visible =
        _achs.where((a) => !a.prereqLocked(claimedCodes)).toList();
    final done = visible.where((a) => a.completed).length;
    // 2026-09-24 定版排序：按「领取状态」分三段（可领取置顶 → 进行中 → 已领取沉底），
    // 段内保持服务端原序（tier.sort_order + code），不再按档位分组打标题——
    // 置顶诉求要的是全局次序，档位标题会把可领取的成就拆散到各档下面。
    // 档位信息改由卡片的达成条件行前缀展示，不丢。
    final claimable = visible.where((a) => a.completed && !a.claimed).toList();
    final doing = visible.where((a) => !a.completed && !a.claimed).toList();
    final claimed = visible.where((a) => a.claimed).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('已达成 $done / ${visible.length}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          for (final (label, list) in <(String, List<PetAchievementModel>)>[
            ('可领取', claimable),
            ('进行中', doing),
            ('已领取', claimed),
          ])
            if (list.isNotEmpty) ...[
              _sectionHeader(cs, label, list.length),
              const SizedBox(height: 8),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _card(cs, a),
                ),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String label, int count) => Row(
        children: [
          Icon(
            label == '可领取'
                ? Icons.card_giftcard
                : label == '进行中'
                    ? Icons.timelapse
                    : Icons.check_circle_outline,
            size: 18,
            color: cs.tertiary,
          ),
          const SizedBox(width: 6),
          Text('$label · $count',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: cs.tertiary)),
        ],
      );

  Widget _card(ColorScheme cs, PetAchievementModel a) {
    final tierLabel = a.tier?.label;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 成就图标位（pet_achievements.icon = icon/<key>，服务端已下发）；
                // 未达成做灰度处理，与右侧进度语义一致
                Opacity(
                  opacity: a.completed ? 1 : .55,
                  child: PetItemIcon(
                    iconKey: a.iconKey,
                    fallback: a.tier == PetAchTier.legendary
                        ? Icons.workspace_premium
                        : Icons.emoji_events_outlined,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(a.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (a.claimed)
                  const Text('已领取', style: TextStyle(fontSize: 12))
                else if (a.completed)
                  FilledButton.tonal(
                    onPressed: _claiming.contains(a.id) ? null : () => _claim(a),
                    child: Text(_claiming.contains(a.id) ? '领取中' : '领取'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // 档位 + 条件 + 进度拼一行；已领的继续报累计进度（只增不减）
            Text(
              tierLabel == null
                  ? '${a.conditionLabel}  ${a.progress}/${a.target}'
                  : '$tierLabel · ${a.conditionLabel}  ${a.progress}/${a.target}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: a.ratio,
                  minHeight: 7,
                  backgroundColor: cs.surfaceContainerHighest),
            ),
            const SizedBox(height: 8),
            // 奖励行:数据为空时不渲染(20261022 拍板:不向用户展示内部兜底措辞)
            if (_rewardText(a).isNotEmpty)
              Text(_rewardText(a),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.tertiary)),
          ],
        ),
      ),
    );
  }

  /// 奖励摘要（读服务端下发的 reward_package,缺项即不展示,不补默认值;
  /// 道具逐个具名——name 由成就列表 SQL join pet_items 下发,20261022 起）
  static String _rewardText(PetAchievementModel a) {
    final parts = <String>[
      if (a.rewardGold > 0) '🪙 ${a.rewardGold}',
      for (final it in a.rewardItems) '${it.name ?? it.code} ×${it.count}',
    ];
    return parts.isEmpty ? '' : '奖励 ${parts.join(' · ')}';
  }
}
