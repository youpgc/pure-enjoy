import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import 'pet_checkin_style.dart';
import 'pet_item_icon.dart';

/// 签到面板视觉子组件（统计条 + 日签格）
///
/// 自 pet_checkin_screen 拆出（500 行硬底线）；纯展示组件
/// 签到/补签动作经回调回到面板状态层。

/// 统计条：N 月已累计签到 N 天 + 漏签提示 + 补签入口
class PetCheckinStatsBar extends StatelessWidget {
  const PetCheckinStatsBar({
    super.key,
    required this.st,
    required this.today,
    required this.missed,
    required this.onOpenMakeupPicker,
  });

  final PetCheckinStatusModel st;
  final DateTime today;
  final List<DateTime> missed;
  final void Function(PetCheckinStatusModel st, List<DateTime> missed) onOpenMakeupPicker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: '${today.month}月已累计签到 ',
                      style: const TextStyle(
                          fontSize: 13.5, color: PetCheckinStyle.textDark)),
                  TextSpan(
                      text: '${st.totalSigned}',
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: PetCheckinStyle.goldDeep)),
                  const TextSpan(
                      text: ' 天',
                      style: TextStyle(
                          fontSize: 13.5, color: PetCheckinStyle.textDark)),
                ],
              ),
            ),
          ),
          Text('漏签 ${missed.length} 天',
              style: TextStyle(
                  fontSize: 12,
                  color: missed.isEmpty
                      ? PetCheckinStyle.textLight
                      : PetCheckinStyle.stampText)),
          const SizedBox(width: 8),
          Material(
            color: missed.isEmpty
                ? PetCheckinStyle.badgeFaintBg
                : PetCheckinStyle.gold,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: missed.isEmpty
                  ? null
                  : () => onOpenMakeupPicker(st, missed),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('补签',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: missed.isEmpty
                            ? PetCheckinStyle.textFaint
                            : Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日签格（4 列等分竖卡）：圆形奖励图 + ×数量 + 第 N 天名牌；
/// 已签浅底盖半透明绿勾；今日待签金框高亮；漏签格可点补签
class PetCheckinDayCell extends StatelessWidget {
  const PetCheckinDayCell({
    super.key,
    required this.st,
    required this.today,
    required this.day,
    required this.itemIcons,
    required this.signing,
    required this.onSign,
    required this.onMakeup,
  });

  final PetCheckinStatusModel st;
  final DateTime today;
  final int day;

  /// 道具图标键映射（pet_items.icon 原始值，icon/ 前缀在组件内剥离）
  final Map<String, String> itemIcons;

  /// 签到/补签请求进行中（防重复提交，禁用整格点击）
  final bool signing;
  final void Function(DateTime date) onSign;
  final void Function(DateTime date, PetCheckinStatusModel st) onMakeup;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 图标资源键（pet_items.icon 形如 icon/<key>，剥前缀取 key；其余原样）
  String _iconOf(String code) {
    final v = itemIcons[code] ?? '';
    return v.startsWith('icon/') ? v.substring(5) : v;
  }

  /// 奖励图标：金币 → 金币图；道具 → 道具图；未配置 → 问号
  Widget _rewardIcon(PetCheckinReward? r) {
    if (r == null || (r.gold <= 0 && r.items.isEmpty)) {
      return const Icon(Icons.help_outline,
          size: 26, color: PetCheckinStyle.textFaint);
    }
    if (r.gold > 0) {
      return const PetItemIcon(
          iconKey: 'ui_coin', fallback: Icons.paid, size: 40);
    }
    final code = r.items.first.$1;
    // 图标键兜底链：pet_items.icon → 资产按 item_code 命名直用 → Material 兜底
    // （库里未配 icon 且无同名资产时给暖金兜底色，避免默认黑）
    final iconKey = _iconOf(code).isNotEmpty ? _iconOf(code) : code;
    return IconTheme(
      data: const IconThemeData(color: PetCheckinStyle.goldDeep),
      child: PetItemIcon(
          iconKey: iconKey, fallback: Icons.redeem_outlined, size: 40),
    );
  }

  /// 数量文案（金币 ×N / 道具 ×N）
  String _rewardCount(PetCheckinReward? r) {
    if (r == null) return '';
    if (r.gold > 0) return '×${r.gold}';
    if (r.items.isNotEmpty) return '×${r.items.first.$2}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime(today.year, today.month, day);
    final signed = st.isSigned(date);
    final isToday = _sameDay(date, today);
    final reward = st.days[day];
    final isNext = isToday && !signed;

    final Color cardBg;
    final Color borderColor;
    if (signed) {
      cardBg = const Color(0xFFEFEBE0); // 浅底 = 已签（参考样式）
      borderColor = const Color(0xFFE2D8C4);
    } else if (isNext) {
      // 今日待签：陶土橙实底 + 右上红点（参考样式），无描边
      cardBg = PetCheckinStyle.cellTodayBg;
      borderColor = PetCheckinStyle.cellTodayBg;
    } else {
      cardBg = const Color(0xFFC6BCAB); // 深底 = 未签
      borderColor = const Color(0xFFA79D8B);
    }

    final circleStack = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PetCheckinStyle.cellNextBg,
          ),
          alignment: Alignment.center,
          child: _rewardIcon(reward),
        ),
        // 已签：半透明绿勾盖在圆框中心（透过勾可见奖励）
        if (signed)
          const Icon(Icons.check_rounded,
              size: 46, color: Color(0xCC61B05E)),
      ],
    );

    final card = Material(
      color: cardBg,
      // 整格描边：与面板底色区分（待签橙底描边同色即无描边观感）
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 今日待签 → 签到；漏签 → 补签确认；已签/未来不可点
        onTap: signing
            ? null
            : isToday && !signed
                ? () => onSign(date)
                : (!signed && date.isBefore(today))
                    ? () => onMakeup(date, st)
                    : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 4),
              child: Column(
                children: [
                  circleStack,
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 15,
                    child: Text(_rewardCount(reward),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: signed
                                ? PetCheckinStyle.textMid
                                : const Color(0xFFF3EEE2))),
                  ),
                ],
              ),
            ),
            // 名牌通栏占满格宽（参考样式）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: PetCheckinStyle.cellNextBg,
              child: Text('第$day天',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PetCheckinStyle.textMid)),
            ),
          ],
        ),
      ),
    );

    // 今日待签：陶土橙实底 + 右上红点徽标（参考样式），不再用金色虚线框
    return Stack(
      children: [
        card,
        if (isNext)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PetCheckinStyle.todayDot,
              ),
            ),
        ),
      ],
    );
  }
}
