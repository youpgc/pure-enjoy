import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';

/// 每日任务页
///
/// 进入即调 questsDraw（幂等：当日已抽直接返回；未抽按配置抽取），
/// 列表展示进度条与领取状态；奖励发放走 rpc_pet_daily_quests_claim。
class PetQuestsScreen extends StatefulWidget {
  const PetQuestsScreen({super.key});

  @override
  State<PetQuestsScreen> createState() => _PetQuestsScreenState();
}

class _PetQuestsScreenState extends State<PetQuestsScreen> {
  bool _loading = true;
  String? _error;
  List<PetQuestModel> _quests = const [];
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final drawErr = await PetRpc.questsDraw();
    if (drawErr != null) {
      if (mounted) {
        setState(() {
          _error = petRpcErrorText(drawErr);
          _loading = false;
        });
      }
      return;
    }
    final (quests, err) = await PetRpc.fetchTodayQuests();
    if (mounted) {
      setState(() {
        _quests = quests;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  Future<void> _claim(PetQuestModel q) async {
    if (_claiming.contains(q.questId)) return;
    setState(() => _claiming.add(q.questId));
    final reward = await PetRpc.questClaim(q.questId);
    if (!mounted) return;
    setState(() => _claiming.remove(q.questId));
    if (reward == null) {
      // 失败：重载以拿到服务端错误语义（由 claim 的错误返回路径统一提示）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('领取失败，请稍后重试')),
      );
      return;
    }
    final parts = <String>[
      if (reward.gold > 0) '金币 +${reward.gold}',
      if (reward.points > 0) '积分 +${reward.points}',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('奖励已领取：${parts.isEmpty ? '道具已入背包' : parts.join('，')}')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('每日任务')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _quests.isEmpty) {
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
    if (_quests.isEmpty) {
      return const EmptyWidget(message: '今日暂无任务，明天再来看看吧');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _quests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final q = _quests[i];
          return Card(
            child: ListTile(
              title: Text(q.title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (q.progress / q.target).clamp(0.0, 1.0),
                          minHeight: 7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${q.progress.clamp(0, q.target)}/${q.target}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing: _buildTrailing(q, cs),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailing(PetQuestModel q, ColorScheme cs) {
    final rewardText = [
      if (q.rewardGold > 0) '🪙${q.rewardGold}',
      if (q.rewardPoints > 0) '⭐${q.rewardPoints}',
    ].join(' ');
    if (q.claimed) {
      return const Text('已领取', style: TextStyle(fontSize: 12));
    }
    if (!q.done) {
      return Text(
        rewardText,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      );
    }
    return FilledButton.tonal(
      onPressed: () => _claim(q),
      child: Text(_claiming.contains(q.questId) ? '领取中' : '领取'),
    );
  }
}
