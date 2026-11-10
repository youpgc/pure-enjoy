
// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 中，分析器对本库内跨文件隐式调用的私有成员
// 引用计数有漏计（unused_element 误报）；extension 语境调 setState 触发
// protected 提示（运行时语义安全）。两处均为工具链误报，文件级压制。
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_adventure.dart';
import '../services/pet_service.dart';
import '../utils/pet_art_resolver.dart';
import '../utils/pet_duration_text.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_adventure_cards.dart';
import '../widgets/pet_claim_result_dialog.dart';
import '../widgets/pet_home_adventure.dart';
import 'pet_odds_screen.dart';
import '../widgets/pet_toast.dart';
import '../widgets/pet_loading.dart';

part 'pet_adventure_views.dart';

/// 历险页
///
/// 交互形态：**浮卡弹窗**（参考属性面板），不再整页跳转——
/// 主页右列历险钮/顶部历险横幅点击均弹出本面板。
/// 状态机（与 pet_adventures.status 对齐）
/// - 无进行中 → 历险地列表 → 选档位（config.adventure_tiers）→ 出发；
/// 等级 = 硬门槛（不达标灰置）；属性 = 结算判据（不达标红显「有风险」
///  仍可出发，claim 时判 failed 执行惩罚）；健康 = 出发门槛（阈值提示）；
/// 「为你匹配」推荐卡来自 rpc_pet_adventure_match（可忽略）；
/// **出发成功即关闭弹窗**（等待期在主页横幅查看，弹窗内不展示等待时间）；
/// - ongoing → 弹窗内倒计时 + **历险地图信息**（spotId 匹配历险地名）+
/// 召回；结束出现「查看结果」（claim roll 四类结果）；
/// - awaiting_rescue → 自救窗口内用救援道具 / 超时 NPC 兜底。
Future<void> showPetAdventureSheet(
  BuildContext context, {
  required String petId,
  required String petName,
  required String petSpeciesCode,
  required int petStage,
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
    // 主题把手关闭:弹窗内自绘把手,避免双把手
    showDragHandle: false,
    isDismissible: true,
    // 点击弹窗外空白(顶部预留/左右边距)关闭弹窗:margin 区属于 sheet 自身
    // 布局而非 barrier,命中到不了 ModalBarrier,必须显式捕获
    builder: (sheetCtx) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Navigator.of(sheetCtx).pop(),
      child: SafeArea(
        child: Container(
          // 顶部预留 300px:内容不顶到状态栏/主页横幅区
          margin: const EdgeInsets.fromLTRB(12, 300, 12, 12),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          // 吸收层只包内容区(不含 margin):点击弹窗内部空白不关闭
          // 点击弹窗外空白由外层捕获关闭
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: PetAdventureScreen(
              petId: petId,
              petName: petName,
              petSpeciesCode: petSpeciesCode,
              petStage: petStage,
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
    required this.petSpeciesCode,
    required this.petStage,
    required this.adventure,
    required this.tiers,
    required this.petLevel,
    required this.petAttrs,
    required this.petHealth,
    required this.healthThreshold,
  });

  final String petId;
  final String petName;

  /// 形象展示用（进行中/遇险视图 c1_neutral 中性帧）
  final String petSpeciesCode;
  final int petStage;

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

  /// 推荐地图卡片 key：列表加载后自动滚动到推荐位置
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
    final (data, err) = await PetRpcAdventure.adventureMatch(widget.petId);
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

  /// 自动滚动到推荐地图（幂等）：_load/_loadMatch 两路请求谁后就绪谁触发
  /// 补齐单侧等待竞态
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
    final (spots, err) = await PetRpcAdventure.fetchSpots();
    final unlocked = await PetRpcAdventure.fetchUnlockedHiddenSpots();
    if (mounted) {
      setState(() {
        _spots = spots;
        _hiddenUnlocked = unlocked;
        _error = err == null ? null : petRpcErrorText(err);
        _loading = false;
      });
    }
    // 自动滚动到推荐地图：列表就绪后跳到推荐卡位置；
    // match 接口后返回时由 _loadMatch 侧补触发
    if (mounted) _scrollToMatched();
  }

  Future<void> _start(PetSpotModel spot, Map<String, dynamic> tier) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await PetRpcAdventure.adventureStart(
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
      // 本屏按 petId 私有：直接取该宠自己的历险态（summary 逐宠下发；
      // 旧单槽被他宠占据时本宠状态取不到）。usable=false = 形状异常，按无进行中处理
      final mine = summary?.adventureFor(widget.petId);
      setState(() => _adv = (mine != null && mine.usable) ? mine : null);
    }
  }

  Future<void> _claim() async {
    if (_busy || _adv == null) return;
    setState(() => _busy = true);
    final (data, err) = await PetRpcAdventure.adventureClaim(_adv!.id);
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

  /// 召回确认：复用主页共享 helper（AlertDialog 二次确认 → 无奖励中断）
  /// 返回 true 表示状态已变化需刷新总览
  Future<void> _confirmRecall() async {
    if (_busy || _adv == null) return;
    final changed = await recallAdventureConfirmed(context, _adv!.id);
    if (changed && mounted) await _reloadSummary();
  }

  Future<void> _rescue({String? itemId}) async {
    if (_busy || _adv == null) return;
    setState(() => _busy = true);
    final err = await PetRpcAdventure.adventureRescue(_adv!.id, itemId: itemId);
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
                  child: Text('游历',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              // 规则说明（结果/掉落概率/危险惩罚与珍稀保护边界）
              IconButton(
                tooltip: '游历规则说明',
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
    if (_loading) return const Center(child: PetPawLoading());
    final adv = _adv;
    if (adv != null && adv.status == PetAdventureStatus.ongoing) {
      return _ongoingView(adv);
    }
    if (adv != null && adv.status == PetAdventureStatus.awaitingRescue) {
      return _rescueView(adv);
    }
    return _spotsView();
  }
}
