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
import 'pet_odds_screen.dart';
import '../widgets/pet_toast.dart';

/// 历险页
///
/// 交互形态（20261021 用户拍板）：**浮卡弹窗**（参考属性面板），不再整页跳转——
/// 主页右列历险钮/顶部历险横幅点击均弹出本面板。
/// 状态机（与 pet_adventures.status 对齐）：
/// - 无进行中 → 历险地列表 → 选档位（config.adventure_tiers）→ 出发；
///   等级 = 硬门槛（不达标灰置）；属性 = 结算判据（不达标红显「有风险」，
///   仍可出发，claim 时判 failed 执行惩罚）；健康 = 出发门槛（阈值提示）；
///   「为你匹配」推荐卡来自 rpc_pet_adventure_match（可忽略）；
///   **出发成功即关闭弹窗**（等待期在主页横幅查看，弹窗内不展示等待时间）；
/// - ongoing  → 弹窗内倒计时 + **历险地图信息**（spotId 匹配历险地名）+
///   召回；结束出现「查看结果」（claim roll 四类结果）；
/// - awaiting_rescue → 自救窗口内用救援道具 / 超时 NPC 兜底。
Future<void> showPetAdventureSheet(
  BuildContext context, {
  required String petId,
  required String petName,
  PetAdventureBriefModel? adventure,
  required List<Map<String, dynamic>> tiers,
  required int petLevel,
  required Map<String, int> petAttrs,
  required int petHealth,
  required int healthThreshold,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // 主题把手关闭:弹窗内自绘把手,避免双把手(20261021 用户反馈)
    showDragHandle: false,
    isDismissible: true,
    // 点击弹窗外空白(顶部预留/左右边距)关闭弹窗:margin 区属于 sheet 自身
    // 布局而非 barrier,命中到不了 ModalBarrier,必须显式捕获
    builder: (sheetCtx) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Navigator.of(sheetCtx).pop(),
      child: SafeArea(
        child: Container(
          // 顶部预留 300px:内容不顶到状态栏/主页横幅区(20261022 用户拍板)
          margin: const EdgeInsets.fromLTRB(12, 300, 12, 12),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          // 吸收层只包内容区(不含 margin):点击弹窗内部空白不关闭,
          // 点击弹窗外空白由外层捕获关闭
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: PetAdventureScreen(
              petId: petId,
              petName: petName,
              adventure: adventure,
              tiers: tiers,
              petLevel: petLevel,
              petAttrs: petAttrs,
              petHealth: petHealth,
              healthThreshold: healthThreshold,
            ),
          ),
        ),
      ),
    ),
  );
}

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

  /// 已解锁隐秘境 code 集（spot_hidden:<code>；隐藏图未解锁的渲染为锁定卡）
  Set<String> _hiddenUnlocked = const {};
  String? _unlockingCode;
  PetAdventureBriefModel? _adv;
  Timer? _tick;
  bool _busy = false;

  /// 「为你匹配」推荐历险地 id（rpc_pet_adventure_match；静默降级为 null）
  String? _matchedSpotId;

  /// 推荐地图卡片 key：列表加载后自动滚动到推荐位置（20261021 用户拍板）
  final GlobalKey _matchedCardKey = GlobalKey();

  /// 自动定位只执行一次：已滚动过（或用户手动滚开）不再拉回
  bool _scrolledToMatch = false;

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
          _scrollToMatched();
          return;
        }
      }
    }
  }

  /// 自动滚动到推荐地图（幂等）：_load/_loadMatch 两路请求谁后就绪谁触发，
  /// 补齐单侧等待竞态（此前只在 _load 侧触发，match 慢于列表时定位丢失）
  void _scrollToMatched() {
    if (_scrolledToMatch || _matchedSpotId == null || _spots.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrolledToMatch) return;
      final ctx = _matchedCardKey.currentContext;
      if (ctx == null) return;
      _scrolledToMatch = true;
      // alignment 0 = 推荐卡顶到视口顶,上方仅剩横幅底距(与卡间距一致)
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0);
    });
  }

  PetSpotModel? get _matchedSpot {
    if (_matchedSpotId == null) return null;
    for (final s in _spots) {
      if (s.id == _matchedSpotId) {
        // 未解锁的秘境不作推荐：横幅会泄露秘境名称，锁定卡也无定位锚点
        if (s.hidden && !_hiddenUnlocked.contains(s.code)) return null;
        return s;
      }
    }
    return null;
  }

  /// 历险地名（spotId → 历险地列表匹配；列表未加载/未命中返回 null）
  String? _spotName(String? spotId) {
    if (spotId == null) return null;
    for (final s in _spots) {
      if (s.id == spotId) return s.name;
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
    final unlocked = await PetRpc.fetchUnlockedHiddenSpots();
    if (mounted) {
      setState(() {
        _spots = spots;
        _hiddenUnlocked = unlocked;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
    // 自动滚动到推荐地图（20261021 用户拍板）：列表就绪后跳到推荐卡位置；
    // match 接口后返回时由 _loadMatch 侧补触发
    if (mounted) _scrollToMatched();
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
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    await _reloadSummary();
    if (mounted) Navigator.pop(context);
  }

  /// 出发后/领取后重取总览拿最新 ongoing 状态
  ///
  /// 拉不到时保持当前状态即可（本次操作的结果已单独提示过），故不打扰用户。
  Future<void> _reloadSummary() async {
    final (summary, _) = await PetService.instance.fetchSummary();
    if (mounted) {
      // 本屏按 petId 私有：直接取该宠自己的历险态（summary 2026-10-15 起逐宠下发；
      // 旧单槽被他宠占据时本宠状态取不到）。usable=false = 形状异常，按无进行中处理
      final mine = summary?.adventureFor(widget.petId);
      setState(() => _adv = (mine != null && mine.usable) ? mine : null);
    }
  }

  Future<void> _claim() async {
    if (_busy || _adv == null) return;
    setState(() => _busy = true);
    final (data, err) = await PetRpc.adventureClaim(_adv!.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showPetToast(context, petRpcErrorText(err));
      await _reloadSummary();
      return;
    }
    final status = PetAdventureStatus.fromCode(data?['status'] as String?);
    if (status == PetAdventureStatus.awaitingRescue) {
      await _reloadSummary();
      if (mounted) {
        showPetToast(context, '遭遇险情！在救援时间内使用救援道具，马上接它回家');
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
    // 掉落明细(含长途独占 long_drops;共享 helper 与主页弹窗同源)
    final items = buildClaimItems(data);
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
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    if (mounted) {
      showPetToast(context,
          itemId == null ? 'NPC 已救助，平安归来' : '自救成功，平安归来');
    }
    await _reloadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 浮卡容器（参考属性面板）：把手 + 标题 + 弹性内容区
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // 与右侧问号按钮等宽的占位：标题在整行居中，不被按钮挤偏
              const SizedBox(width: 48),
              Expanded(
                child: Center(
                  child: Text('历险',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              // 规则说明（结果/掉落概率/危险惩罚与珍稀保护边界）
              IconButton(
                tooltip: '历险规则说明',
                onPressed: _showRulesSheet,
                icon: Icon(Icons.help_outline,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Flexible(child: _buildBody()),
      ],
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

  /// 隐秘境锁定卡：与普通卡同构（左星星图标 + 右锁标），名称保密；
  /// 点卡片确认后消耗罗盘解锁（等级未达也先展示，解锁与等级门槛独立）
  Widget _hiddenLockedCard(PetSpotModel spot) {
    final lv = spot.requiredLevel;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: cs.tertiary),
        title: const Text('未解锁的秘境'),
        subtitle: Text(
          '深处藏着独有的珍藏${lv != null && widget.petLevel < lv ? '（需 Lv.$lv）' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _unlockingCode == spot.code
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_outline, size: 18),
        onTap: _unlockingCode == spot.code
            ? null
            : () => _confirmUnlockHidden(spot),
      ),
    );
  }

  /// 解锁确认：罗盘是稀有道具，点卡片先确认再消耗
  Future<void> _confirmUnlockHidden(PetSpotModel spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解锁秘境'),
        content: const Text('将消耗 1 个「星辰罗盘」解锁这座秘境，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('解锁')),
        ],
      ),
    );
    if (ok == true) await _unlockHidden(spot);
  }

  /// 罗盘解锁：服务端消耗 1 个星辰罗盘（无罗盘由服务端报错转文案）
  Future<void> _unlockHidden(PetSpotModel spot) async {
    setState(() => _unlockingCode = spot.code);
    final err = await PetRpc.unlockHiddenSpot(spot.code);
    if (!mounted) return;
    setState(() => _unlockingCode = null);
    showPetToast(context,
        err != null ? petRpcErrorText(err) : '秘境已解锁：「${spot.name}」');
    if (err == null) await _load();
  }

  /// 历险规则说明（问号弹窗）：结果类型权重、掉落概率、长途独占与保底、
  /// 危险惩罚（含珍稀保护的丢物边界）——具体数值按图各异，引导去概率公示页
  void _showRulesSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.explore_outlined, size: 20),
                SizedBox(width: 8),
                Text('历险规则说明',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              _ruleLine('归来结果', '每次归来可能遇到求助、游玩、回忆或危险事件，收获各不相同'),
              _ruleLine('收获', '归来可获得经验与金币，走得越远收获越丰厚；长途出行还有机会获得稀有宝贝'),
              _ruleLine('独占掉落与保底', '进化石/星辰罗盘/系收藏品等仅长途概率获得，80 次未中必得（保底后清零）'),
              _ruleLine('危险', '可能受伤、心情变差，深处还会掉落金币或一件普通道具'),
              _ruleLine('珍稀保护', '珍贵收藏和进化材料受特别保护，永远不会丢失'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const PetOddsScreen())),
                  child: const Text('查看完整概率公示 →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleLine(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(body,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      );

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
    // 全量构建(历险地仅 30 张):惰性列表下未构建项的 ctx 为 null,
    // ensureVisible 会静默跳过——全量构建后推荐卡定位才可靠(20261021)
    // 推荐横幅/健康提示钉在弹窗上部固定展示,滚动体仅地图列表(20261022 用户拍板)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (healthLow)
          Card(
            color: cs.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('宠物健康状况不佳，恢复健康后再出发吧'),
            ),
          ),
        if (matched != null)
          Padding(
            // 底距与地图卡间距一致(Card margin 4×2):定位后推荐卡上方留白同卡间
            padding: const EdgeInsets.only(bottom: 8),
            child: PetMatchBanner(
                spotName: matched.name, onTap: () => _showTierSheet(matched)),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final spot in _spots)
                  spot.hidden && !_hiddenUnlocked.contains(spot.code)
                      ? _hiddenLockedCard(spot)
                      : petSpotCard(
                          context,
                          spot: spot,
                          petLevel: widget.petLevel,
                          petAttrs: widget.petAttrs,
                          // 推荐卡挂 key:列表就绪后自动滚动到推荐位置;高亮边框
                          key: spot.id == _matchedSpotId ? _matchedCardKey : null,
                          highlight: spot.id == _matchedSpotId,
                          onTap: () => _showTierSheet(spot),
                        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTierSheet(PetSpotModel spot) {
    if (widget.tiers.isEmpty) {
      showPetToast(context, '历险时长还在准备中，稍后再来');
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
    // 历险地图信息（20261021 用户拍板：弹窗展示具体历险地图）
    final spotName = _spotName(adv.spotId);
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
            if (spotName != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('历险地图：$spotName',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
            ],
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
    // 遇险地图信息（与进行中视图同源,20261021 用户拍板）
    final spotName = _spotName(adv.spotId);
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
            if (spotName != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('遇险地图：$spotName',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              expired
                  ? '救援时间已过，NPC 会安全护送它回家'
                  : '救援时间截止：${deadline == null ? '-' : DateTimeUtils.formatToMinute(deadline)}',
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
              expired ? '点击下方按钮完成 NPC 救助' : '没有救援道具也没关系，时间到了 NPC 会去接它',
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
        showPetToast(context, petRpcErrorText(err));
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
        showPetToast(context, '背包中没有救援道具，可去商城购买或等待 NPC 救助');
      }
      return;
    }
    await _rescue(itemId: rescueItem.itemId);
  }
}
