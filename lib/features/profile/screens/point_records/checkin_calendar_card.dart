import 'package:flutter/material.dart';
import '../../services/point_service_utils.dart';

/// 支付宝式「会员积分打卡日历」卡片。
///
/// 形态：可用积分概览 + 月份导航 + 当月签到日网格 + 连续天数/满额进度 + 大签到按钮。
/// 网格状态：已签(打勾) / 今日(高亮描边) / 未来(置灰不可点) / 历史漏签(可点触发补签占位)。
/// 主题感知（不硬编码配色），仅展示与当日签到，不触碰 checkin() 奖励公式、不动后端。
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.primaryContainer.withValues(alpha: 0.65),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 积分概览
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '可用积分',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                if (isLoadingPoints)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 月份导航
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                  color: colorScheme.onPrimaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  '${displayMonth.year}年${displayMonth.month}月',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                IconButton(
                  onPressed: canGoNext ? onNextMonth : null,
                  icon: const Icon(Icons.chevron_right),
                  color: colorScheme.onPrimaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // 星期表头（周一开头）
            _weekdayHeader(colorScheme),
            const SizedBox(height: 8),

            // 日期网格
            isLoadingCalendar
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _dayGrid(colorScheme, today, isCurrentMonth),

            const SizedBox(height: 12),
            Center(
              child: Text(
                '点击漏签日期可补签（持有 $makeupCardCount 张补签卡）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.55),
                    ),
              ),
            ),

            const SizedBox(height: 16),

            // 连续签到 + 满额进度
            _streakProgress(context, colorScheme),

            const SizedBox(height: 16),

            // 签到按钮（仅当前月展示）
            if (isCurrentMonth)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (hasCheckedInToday || isCheckingIn) ? null : onCheckin,
                  child: isCheckingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasCheckedInToday
                                  ? Icons.check_circle
                                  : Icons.edit_calendar,
                            ),
                            const SizedBox(width: 6),
                            Text(hasCheckedInToday ? '今日已签到' : '签到'),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayHeader(ColorScheme cs) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: TextStyle(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.65),
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

  Widget _dayGrid(ColorScheme cs, DateTime today, bool isCurrentMonth) {
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
      cells.add(Expanded(child: _dayCell(cs, today, day, isCurrentMonth)));
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

  Widget _dayCell(ColorScheme cs, DateTime today, int day, bool isCurrentMonth) {
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

    final onTap = isPastMissed ? () => onMakeup(cellDate) : null;

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isChecked ? cs.primary : null,
            border: (!isChecked && (isToday || isPastMissed))
                ? Border.all(
                    color: isToday
                        ? cs.primary
                        : cs.onPrimaryContainer.withValues(alpha: 0.3),
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
                        ? cs.onPrimaryContainer.withValues(alpha: 0.3)
                        : (isToday ? cs.primary : cs.onPrimaryContainer),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              if (isPastMissed)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _streakProgress(BuildContext context, ColorScheme cs) {
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
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              maxed ? '已享满额 7分/天' : '满7天每日得7分',
              style: TextStyle(
                color: cs.onPrimaryContainer.withValues(alpha: 0.7),
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
            backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
