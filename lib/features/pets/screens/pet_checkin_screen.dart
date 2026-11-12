import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_checkin_window.dart';
import '../utils/pet_errors.dart';
import '../widgets/pet_checkin_cells.dart';
import '../widgets/pet_checkin_style.dart';
import '../widgets/pet_loading.dart';
import '../widgets/pet_toast.dart';
import 'pet_shop_screen.dart';

/// 主页「签到」入口弹窗（宠物模块独享签到体系）。
///
/// 展示口径（参考主流签到页样式一比一还原）：**4 列 flex 等分网格**铺排
/// 奖励槽（每 4 格一组，总数按当月天数钳制），收起显示待签槽所在组及其后一组，可展开全部；
/// 列宽恒定相等；已签格加深并盖绿色对勾，待签格橙底红点高亮，漏签补签
/// 走统计条按日历日选择（每自然月 4 次，服务端校验）。奖励锚点 = 累计
/// 签到次数（含补签），当月第 N 次签到获得模板第 N 槽奖励，与日历日期无关。
Future<void> showPetCheckinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 透明底:isScrollControlled 下 sheet 本体为全屏,若给背景色会整屏涂满;
    // 可见面板由内层 Container 自绘(与游历弹窗同款结构)
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    isDismissible: true,
    // 点击弹窗外空白关闭:margin 区属于 sheet 自身布局而非 barrier
    // 命中到不了 ModalBarrier,必须显式捕获
    builder: (sheetCtx) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Navigator.of(sheetCtx).pop(),
      child: SafeArea(
        child: Container(
          // 顶部预留 300px:内容不顶到状态栏/主页横幅区;
          // 高度上限 0.7:内容超出时面板内滚动
          margin: const EdgeInsets.fromLTRB(12, 300, 12, 12),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(
            color: PetCheckinStyle.sheetBg,
            borderRadius: BorderRadius.circular(26),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const PetCheckinPanel(),
          ),
        ),
      ),
    ),
  );
}

/// 签到面板（弹窗内容）：标题 + 累计统计行 + 4 列日签网格 + 里程碑。
class PetCheckinPanel extends StatefulWidget {
  const PetCheckinPanel({super.key});

  @override
  State<PetCheckinPanel> createState() => _PetCheckinPanelState();
}

class _PetCheckinPanelState extends State<PetCheckinPanel> {
  PetCheckinStatusModel? _status;
  bool _loading = true;

  /// 签到/补签请求进行中（防重复提交）
  bool _signing = false;


  /// 奖励网格展开态（收起 = 待签槽所在组 + 后一组，展开 = 模板全槽）
  bool _expanded = false;
  String? _error;

  /// item_code → 中文名 / 图标键（pet_items 服务端真源）
  Map<String, String> _itemNames = const {};
  Map<String, String> _itemIcons = const {};

  static DateTime _beijingToday() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  /// 当月天数（北京时间口径下的公历月末）
  static int _daysInMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0).day;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _load();
    _loadItemMeta();
  }

  /// [silent] 静默刷新：签到/补签成功后只更新数据不整页转圈
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final today = _beijingToday();
    final (status, err) =
        await PetRpc.fetchCheckinStatus(today.year, today.month);
    if (!mounted) return;
    setState(() {
      _status = status;
      _error = err == null ? null : petRpcErrorText(err);
      _loading = false;
    });
  }

  Future<void> _loadItemMeta() async {
    final (names, icons) = (
      await PetRpc.fetchItemNames(),
      await PetRpc.fetchItemIcons(),
    );
    if (mounted) {
      setState(() {
        _itemNames = names;
        _itemIcons = icons;
      });
    }
  }

  String _nameOf(String code) => _itemNames[code] ?? code;


  Future<void> _sign(DateTime day) async {
    if (_signing) return;
    setState(() => _signing = true);
    final today = _beijingToday();
    // 今日签到（无 makeup 参数）；其余日期为补签
    final isMakeup = !_sameDay(day, today);
    final (result, err) =
        await PetRpc.checkinSign(makeupDate: isMakeup ? day : null);
    if (!mounted) return;
    setState(() => _signing = false);
    if (err != null || result == null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    showPetToast(context, _signResultText(result));
    await _load(silent: true);
  }

  String _signResultText(PetCheckinSignResultModel r) {
    final parts = <String>[
      if (r.gold > 0) '金币 +${r.gold}',
      for (final (c, n) in r.items) '${_nameOf(c)}×$n',
    ];
    final head = r.makeup ? '补签成功' : '签到成功';
    return parts.isEmpty ? head : '$head：${parts.join('，')}';
  }

  /// 当月漏签日（已过未签的日历日；补签以日历日为目标、奖励按累计次数推进）
  List<DateTime> _missedDays(PetCheckinStatusModel st, DateTime today) {
    final missed = <DateTime>[];
    for (var d = 1; d < today.day; d++) {
      final day = DateTime(today.year, today.month, d);
      if (!st.isSigned(day)) missed.add(day);
    }
    return missed;
  }

  /// 无卡引导：取钱包余额后跳商城购卡；返回后静默刷新补签卡持有数
  Future<void> _goShop() async {
    final (summary, _) = await PetService.instance.fetchSummary();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PetShopScreen(goldBalance: summary?.wallet.goldBalance ?? 0)));
    if (!mounted) return;
    await _load(silent: true);
  }

  /// 补签确认弹窗（持卡→确认；无卡→跳商城购卡）
  void _confirmMakeup(DateTime day, PetCheckinStatusModel st) {
    final card = st.makeupCardCount;
    final remain = st.makeupLimit - st.makeupCount;
    // 补签计入累计次数：补得「下一次签到」对应的模板天奖励
    final nextSlot = st.totalSigned + 1;
    final reward = st.days[nextSlot];
    final canMakeup = card > 0 && remain > 0 && !_signing;
    final canGoShop = card <= 0 && !_signing;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: PetCheckinStyle.sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('补签 ${day.month} 月 ${day.day} 日',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PetCheckinStyle.textDark)),
              const SizedBox(height: 8),
              Text(
                reward == null
                    ? '第 $nextSlot 天奖励未配置。'
                    : '补得累计第 $nextSlot 天奖励：${reward.summary(_nameOf)}',
                style: const TextStyle(
                    fontSize: 13, color: PetCheckinStyle.textMid),
              ),
              const SizedBox(height: 4),
              Text(
                card > 0
                    ? '将消耗 1 张补签卡（持有 $card 张，本月剩余补签额度 $remain 次）'
                    : '补签卡不足，可到商城用金币购买',
                style: const TextStyle(
                    fontSize: 12, color: PetCheckinStyle.textLight),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: canMakeup
                    ? () {
                        Navigator.pop(sheetCtx);
                        _sign(day);
                      }
                    : canGoShop
                        ? () {
                            Navigator.pop(sheetCtx);
                            _goShop();
                          }
                        : null,
                style: FilledButton.styleFrom(
                    backgroundColor: PetCheckinStyle.gold,
                    foregroundColor: Colors.white),
                child: Text(card > 0 ? '确认补签' : '去商城买补签卡'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 补签日期选择（右上「补签」入口；漏签日列表）
  void _openMakeupPicker(
      PetCheckinStatusModel st, List<DateTime> missed) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: PetCheckinStyle.sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('选择补签日期',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PetCheckinStyle.textDark)),
              ),
            ),
            for (final day in missed)
              ListTile(
                dense: true,
                title: Text('${day.month} 月 ${day.day} 日',
                    style: const TextStyle(
                        fontSize: 14, color: PetCheckinStyle.textDark)),
                trailing: Text(
                    st.makeupCardCount > 0 ? '消耗 1 张补签卡' : '需补签卡',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: PetCheckinStyle.textLight)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmMakeup(day, st);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 视觉层
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 60,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE5D5BC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const Center(
          child: Text('🐾 每日签到',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: PetCheckinStyle.textDark)),
        ),
        const SizedBox(height: 10),
        Flexible(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final today = _beijingToday();
    if (_loading) {
      // 加载态：同构骨架栅格撑住高度（与成功态严格一致，零跳变），loading
      // 半透明浮层盖在两行栅格上，加载完成消失露出真数据。
      // IgnorePointer 防骨架期误触签到/补签
      return IgnorePointer(
        child: _buildStatusBody(_skeletonStatus(today), today,
            gridOverlay: const ColoredBox(
              color: Color(0x8CFFFDF8),
              child: Center(child: PetPawLoading(color: PetCheckinStyle.gold)),
            )),
      );
    }
    if (_error != null && _status == null) {
      return ListView(shrinkWrap: true, children: [
        const SizedBox(height: 40),
        Center(
            child: Text(_error!,
                style: const TextStyle(
                    color: PetCheckinStyle.stampText, fontSize: 13))),
        const SizedBox(height: 20),
      ]);
    }
    final st = _status;
    if (st == null) return const SizedBox.shrink();
    return _buildStatusBody(st, today);
  }

  /// 加载态骨架模型：空奖励表（格内问号占位）+ 全勤 signedDates
  /// （漏签 0 天最平静视觉）。累计 0 次 → 收起窗口 1-8 两行，
  /// 与成功态收起版式严格一致 → 高度零跳变
  PetCheckinStatusModel _skeletonStatus(DateTime today) {
    String key(int day) =>
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return PetCheckinStatusModel(
      monthKey: '',
      days: const {},
      totalSigned: 0,
      makeupCount: 0,
      makeupLimit: 4,
      makeupCardCount: 0,
      signedDates: {
        // 键格式对齐 PetCheckinStatusModel._key（私有不可引用，就地同式生成）；
        // 含今日全部置已签 → 漏签 0 天、待签橙底不透出浮层，骨架期最平静
        for (var d = 1; d <= today.day; d++) key(d): true,
      },
    );
  }

  /// 签到主内容（加载骨架与成功态共用同一版式）；
  /// [gridOverlay] 非空时以 Stack 浮层盖住网格区（骨架高度不变）
  Widget _buildStatusBody(PetCheckinStatusModel st, DateTime today,
      {Widget? gridOverlay}) {
    final missed = _missedDays(st, today);
    final totalSlots =
        petCheckinTotalSlots(st, _daysInMonth(today));
    // 签到后 totalSigned 递增，窗口随下一个待签槽主动前移
    final next = st.totalSigned + 1 > totalSlots
        ? totalSlots
        : st.totalSigned + 1;
    final (winStart, winEnd) =
        petCheckinCollapsedWindow(next, totalSlots);
    final slots = _expanded
        ? [for (var s = 1; s <= totalSlots; s++) s]
        : [for (var s = winStart; s <= winEnd; s++) s];
    final gridRows = <Widget>[
        // 4 列 flex 等分网格：列宽恒定相等、占满整行（行尾空槽留白）
        for (var row = 0;
            row <
                (slots.length + kPetCheckinGroupSize - 1) ~/
                    kPetCheckinGroupSize;
            row++) ...[
          if (row > 0) const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              children: [
                for (var col = 0; col < kPetCheckinGroupSize; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: row * kPetCheckinGroupSize + col < slots.length
                        ? PetCheckinDayCell(
                            st: st,
                            today: today,
                            day: slots[row * kPetCheckinGroupSize + col],
                            itemIcons: _itemIcons,
                            signing: _signing,
                            onSign: _sign)
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
    ];
    final gridBlock = gridOverlay == null
        ? Column(mainAxisSize: MainAxisSize.min, children: gridRows)
        : Stack(children: [
            Column(mainAxisSize: MainAxisSize.min, children: gridRows),
            Positioned.fill(child: gridOverlay),
          ]);
    return ListView(
      padding: const EdgeInsets.only(bottom: 6),
      shrinkWrap: true,
      children: [
        PetCheckinStatsBar(
          st: st,
          today: today,
          missed: missed,
          onOpenMakeupPicker: _openMakeupPicker,
        ),
        const SizedBox(height: 10),
        gridBlock,
        const SizedBox(height: 6),
        // 展开/收起（模板超出收起窗口时出现）
        if (totalSlots >
            kPetCheckinCollapsedGroups * kPetCheckinGroupSize)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: PetCheckinStyle.textMid),
                const SizedBox(width: 4),
                Text(_expanded ? '收起' : '查看全部奖励',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: PetCheckinStyle.textMid)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color: PetCheckinStyle.softCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            '奖励按累计签到次数发放，与日历日期无关；补签计入次数（每月 4 次，'
            '消耗补签卡）。',
            style: TextStyle(
                fontSize: 11, height: 1.5, color: PetCheckinStyle.textRule),
          ),
        ),
      ],
    );
  }
}
