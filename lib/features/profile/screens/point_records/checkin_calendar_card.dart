import 'package:flutter/material.dart';
import '../../services/point_service_utils.dart';
import '../../services/point_service.dart';

/// 会员积分打卡日历卡片（重新设计版）。
///
/// 结构：顶部品牌色头部（可用积分 + 右上角签到按钮）/ 浅色身体（月份导航 + 签到网格 + 连续进度）。
/// 网格状态：已签(实心圆+勾) / 今日(主色描边) / 未来(置灰) / 历史漏签(可点触发补签)。
/// 主题感知（仅用 colorScheme 语义色，不硬编码配色），不触碰 checkin() 奖励公式、不动后端。
class CheckinCalendarCard extends StatelessWidget {
  const CheckinCalendarCard({
    super.key,
    required this.availablePoints,
    required this.isLoadingPoints,
    required this.hasCheckedInToday,
    required this.isCheckingIn,
    required this.consecutiveCheckinDays,
    required this.displayMonth,
    required this.checkedDates,
    required this.isLoadingCalendar,
    required this.onCheckin,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onMakeup,
    required this.canGoNext,
    required this.canGoPrev,
    required this.makeupCardCount,
  });

  final int availablePoints;
  final bool isLoadingPoints;
  final bool hasCheckedInToday;
  final bool isCheckingIn;
  final int consecutiveCheckinDays;
  final DateTime displayMonth;
  final Set<String> checkedDates;
  final bool isLoadingCalendar;
  final VoidCallback onCheckin;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime) onMakeup;
  final bool canGoNext;
  final bool canGoPrev;
  final int makeupCardCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = beijingToday();
    final isCurrentMonth =
        displayMonth.year == today.year && displayMonth.month == today.month;

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== 顶部品牌色头部：积分 + 右上角签到按钮 =====
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.88),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$availablePoints',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '可用积分',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isCurrentMonth) _buildCheckinButton(colorScheme),
              ],
            ),
          ),

          // ===== 浅色身体：月份导航 + 日历网格 + 连续进度 =====
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMonthNav(context, colorScheme),
                const SizedBox(height: 14),
                _buildWeekdayHeader(colorScheme),
                const SizedBox(height: 8),
                // 优先渲染日历网格（即使 checkedDates 为空也展示当月骨架 + 今日高亮），
                // 接口请求中的 loading 以「遮罩层」覆盖在网格之上，不替换网格、不改变模块高度。
                Stack(
                  children: [
                    _buildDayGrid(colorScheme, today, isCurrentMonth),
                    if (isLoadingCalendar)
                      Positioned.fill(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '点击漏签日期可补签（持有 $makeupCardCount 张补签卡，仅支持近 3 个月内）',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.8),
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStreakProgress(context, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 右上角签到按钮（仅当前月展示），玻璃质感的浅色按钮置于品牌头部之上
  Widget _buildCheckinButton(ColorScheme cs) {
    final onPrimary = cs.onPrimary;
    return SizedBox(
      height: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: onPrimary.withValues(alpha: 0.18),
          foregroundColor: onPrimary,
          disabledBackgroundColor: onPrimary.withValues(alpha: 0.12),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: (hasCheckedInToday || isCheckingIn) ? null : onCheckin,
        child: isCheckingIn
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onPrimary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasCheckedInToday ? Icons.check_circle : Icons.edit_calendar,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(hasCheckedInToday ? '已签到' : '签到'),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthNav(BuildContext context, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: canGoPrev ? onPrevMonth : null,
          icon: const Icon(Icons.chevron_left),
          color: cs.onSurface,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          '${displayMonth.year}年${displayMonth.month}月',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        IconButton(
          onPressed: canGoNext ? onNextMonth : null,
          icon: const Icon(Icons.chevron_right),
          color: cs.onSurface,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(ColorScheme cs) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayGrid(
      ColorScheme cs, DateTime today, bool isCurrentMonth) {
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final daysInMonth =
        DateTime(displayMonth.year, displayMonth.month + 1, 1)
            .difference(firstDay)
            .inDays;
    final leading = firstDay.weekday - 1; // 周一开头
    final total = ((leading + daysInMonth) / 7).ceil() * 7;

    final cells = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i < leading || i >= leading + daysInMonth) {
        cells.add(const Expanded(child: SizedBox.shrink()));
        continue;
      }
      final day = i - leading + 1;
      cells.add(Expanded(
          child: _buildDayCell(cs, today, day, isCurrentMonth)));
    }

    return Column(
      children: List.generate(
        total ~/ 7,
        (r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: cells.sublist(r * 7, r * 7 + 7)),
        ),
      ),
    );
  }

  Widget _buildDayCell(
      ColorScheme cs, DateTime today, int day, bool isCurrentMonth) {
    final key =
        '${displayMonth.year}-${displayMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final isToday = displayMonth.year == today.year &&
        displayMonth.month == today.month &&
        day == today.day;
    final isChecked = checkedDates.contains(key);
    final cellDate = DateTime(displayMonth.year, displayMonth.month, day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final isFuture = cellDate.isAfter(todayDate);
    final isPastMissed = !isToday && !isFuture && !isChecked;
    // 仅在「过去日 + 未签到 + 处于可补签时间窗口（最近3个月）」内才允许点击补签
    final canMakeup = isPastMissed && PointService.isMakeupDateAllowed(cellDate);

    final onTap = canMakeup ? () => onMakeup(cellDate) : null;

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isChecked ? cs.primary : null,
            border: (!isChecked && (isToday || canMakeup))
                ? Border.all(
                    color: isToday
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    width: isToday ? 1.5 : 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isChecked)
                Icon(Icons.check, size: 16, color: cs.onPrimary)
              else
                Text(
                  '$day',
                  style: TextStyle(
                    color: isFuture
                        ? cs.onSurface.withValues(alpha: 0.3)
                        : (isToday ? cs.primary : cs.onSurface),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              if (canMakeup)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakProgress(BuildContext context, ColorScheme cs) {
    const cap = 7;
    final reached =
        consecutiveCheckinDays >= cap ? cap : consecutiveCheckinDays;
    final progress = reached / cap;
    final maxed = consecutiveCheckinDays >= cap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department, color: cs.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              '已连续签到 $consecutiveCheckinDays 天',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              maxed ? '已享满额 7分/天' : '满7天每日得7分',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: cs.primary,
            backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}
