import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_p2_progress_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';

/// 任务页（每日 + 每周两个页签）
///
/// 日任务：进入即调 `rpc_pet_daily_quests_draw`（幂等：当日已抽直接返回）；
/// 周任务（P2）：**首次切到该页签才调** `rpc_pet_weekly_quests_draw`，
/// 与日任务同一惰性语义——进度从「本周首次抽取」起算，本周之前的行为不追溯计入，
/// 所以不切页签就不会提前锁定本周的起算点。
/// 两者的 target/progress/claimed 全部由服务端下发（铁律 1），
/// 周任务复用 `pet_daily_quests`（assign_date 存本北京周一），客户端无需感知。
class PetQuestsScreen extends StatefulWidget {
  const PetQuestsScreen({super.key});

  @override
  State<PetQuestsScreen> createState() => _PetQuestsScreenState();
}

class _PetQuestsScreenState extends State<PetQuestsScreen>
    with SingleTickerProviderStateMixin {
  static const int _weeklyTab = 1;

  late final TabController _tabs;

  // 每日
  bool _loading = true;
  String? _error;
  List<PetQuestModel> _daily = const [];

  // 每周（惰性抽取）
  bool _weeklyLoading = false;
  bool _weeklyDrawn = false;
  String? _weeklyError;
  List<PetWeeklyQuestModel> _weekly = const [];
  String? _weekStart;

  /// 正在领取的任务 id（日/周共用一个集合，id 均为 pet_quests 行 uuid）
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChange);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (_tabs.index == _weeklyTab && !_weeklyDrawn) _loadWeekly();
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
        _daily = quests;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
  }

  Future<void> _loadWeekly({bool showLoading = true}) async {
    if (showLoading) setState(() => _weeklyLoading = true);
    final (quests, weekStart, err) = await PetRpcP2.weeklyQuestsDraw();
    if (!mounted) return;
    setState(() {
      _weekly = quests;
      _weekStart = weekStart;
      _weeklyError = err == null ? null : petRpcErrorText(err);
      _weeklyDrawn = true;
      _weeklyLoading = false;
    });
  }

  Future<void> _claimDaily(PetQuestModel q) async {
    if (_claiming.contains(q.questId)) return;
    setState(() => _claiming.add(q.questId));
    final reward = await PetRpc.questClaim(q.questId);
    if (!mounted) return;
    setState(() => _claiming.remove(q.questId));
    if (reward == null) {
      // 失败：重载以拿到服务端错误语义（由 claim 的错误返回路径统一提示）
      showSnackBar(context, '领取失败，请稍后重试');
      return;
    }
    showSnackBar(context, _claimToast(_rewardParts(reward.gold, reward.points, const [])));
    _load();
  }

  Future<void> _claimWeekly(PetWeeklyQuestModel q) async {
    if (_claiming.contains(q.questId)) return;
    setState(() => _claiming.add(q.questId));
    final (result, err) = await PetRpcP2.weeklyQuestClaim(q.questId);
    if (!mounted) return;
    setState(() => _claiming.remove(q.questId));
    if (err != null || result == null) {
      return showSnackBar(context, petRpcErrorText(err));
    }
    showSnackBar(context,
        _claimToast(_rewardParts(result.gold, result.points, result.items)));
    await _loadWeekly(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '每日'),
            Tab(text: '每周'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_dailyTab(cs), _weeklyTabView(cs)],
      ),
    );
  }

  // ---------- 每日 ----------

  Widget _dailyTab(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _daily.isEmpty) {
      return _errorView(cs, _error!, _load);
    }
    if (_daily.isEmpty) {
      return const EmptyWidget(message: '今日暂无任务，明天再来看看吧');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _daily.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _daily.length) return _footer(cs, '每日任务每天 0 点（北京时间）换新。');
          final q = _daily[i];
          return _questCard(
            cs,
            title: q.title,
            progress: q.progress,
            target: q.target,
            claimed: q.claimed,
            rewardText: _rewardText(q.rewardGold, q.rewardPoints, const []),
            busy: _claiming.contains(q.questId),
            onClaim: q.done ? () => _claimDaily(q) : null,
          );
        },
      ),
    );
  }

  // ---------- 每周 ----------

  Widget _weeklyTabView(ColorScheme cs) {
    // 切到本页签才抽取（见 _onTabChange）；未抽取前不占位显示空态
    if (_weeklyLoading || !_weeklyDrawn) {
      return const Center(child: LoadingWidget());
    }
    if (_weeklyError != null && _weekly.isEmpty) {
      return _errorView(cs, _weeklyError!, () => _loadWeekly());
    }
    if (_weekly.isEmpty) {
      return const EmptyWidget(message: '本周还没有开放中的周任务');
    }
    return RefreshIndicator(
      onRefresh: () => _loadWeekly(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _weekly.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _weekly.length) return _footer(cs, _weeklyFootnote());
          final q = _weekly[i];
          return _questCard(
            cs,
            title: '${q.difficultyLabel} · ${q.conditionLabel}',
            progress: q.progress,
            target: q.target,
            claimed: q.claimed,
            rewardText:
                _rewardText(q.rewardGold, q.rewardPoints, q.rewardItems),
            busy: _claiming.contains(q.questId),
            onClaim: q.done ? () => _claimWeekly(q) : null,
          );
        },
      ),
    );
  }

  String _weeklyFootnote() {
    final start = _weekStart;
    return '周任务按北京周一为锚点'
        '${start == null ? '' : '（本周自 $start 起）'}；'
        '进度从本周第一次打开本页签起算，之前的行为不追溯计入。';
  }

  // ---------- 公共小块 ----------

  Widget _questCard(
    ColorScheme cs, {
    required String title,
    required int progress,
    required int target,
    required bool claimed,
    required String rewardText,
    required bool busy,
    VoidCallback? onClaim,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${progress.clamp(0, target)}/$target',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        trailing: claimed
            ? const Text('已领取', style: TextStyle(fontSize: 12))
            : onClaim == null
                ? Text(rewardText,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant))
                : FilledButton.tonal(
                    onPressed: busy ? null : onClaim,
                    child: Text(busy ? '领取中' : '领取'),
                  ),
      ),
    );
  }

  Widget _errorView(ColorScheme cs, String text, VoidCallback onRetry) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );

  Widget _footer(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      );

  static String _claimToast(String summary) =>
      summary.isEmpty ? '奖励已领取' : '奖励已领取：$summary';

  static String _rewardText(int gold, int points, List<dynamic> items) {
    final parts = [
      if (gold > 0) '🪙 $gold',
      if (points > 0) '⭐ $points',
      if (items.isNotEmpty) '道具 ×${items.length}',
    ];
    return parts.isEmpty ? '' : '奖励 ${parts.join(' · ')}';
  }

  static String _rewardParts(int gold, int points, List<dynamic> items) {
    final parts = [
      if (gold > 0) '金币 +$gold',
      if (points > 0) '积分 +$points',
      if (items.isNotEmpty) '道具 ×${items.length}',
    ];
    return parts.isEmpty ? '奖励已发放' : parts.join('，');
  }
}
