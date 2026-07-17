part of 'expense_list_screen.dart';

/// 支出统计卡片（服务端聚合查询，不受分页限制）
class _ExpenseStatCard extends StatelessWidget {
  final DateTime displayedMonth;
  final double totalAmount;
  final bool isLoadingTotal;

  const _ExpenseStatCard({
    required this.displayedMonth,
    required this.totalAmount,
    required this.isLoadingTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${displayedMonth.year}年${displayedMonth.month.toString().padLeft(2, '0')}月',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '总支出: ¥${totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isLoadingTotal) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 分类筛选条
class _ExpenseCategoryFilter extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _ExpenseCategoryFilter({
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          CategoryChip(
            label: '全部',
            isSelected: selectedCategory == 'all',
            onTap: () => onSelected('all'),
          ),
          ...DictService.instance.getItemsSync('expense_category').map((cat) => CategoryChip(
            label: cat.label,
            isSelected: selectedCategory == cat.code,
            onTap: () => onSelected(cat.code),
          )),
        ],
      ),
    );
  }
}

/// 支出列表空状态
class _ExpenseEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _ExpenseEmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyWidget(icon: Icons.receipt_long_outlined, message: '暂无记录'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 支出列表单项卡片
class _ExpenseListItem extends StatelessWidget {
  final ExpenseModel expense;
  final String categoryLabel;
  final DateTime displayDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseListItem({
    required this.expense,
    required this.categoryLabel,
    required this.displayDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt),
        title: Text(categoryLabel),
        subtitle: Text(
          '${DateTimeUtils.formatStandard(displayDate)}${expense.description != null ? ' - ${expense.description}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${expense.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            EditDeletePopupMenu(
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出记账/编辑表单底部弹窗
void _showExpenseFormSheet({
  required BuildContext context,
  required String userId,
  ExpenseModel? expense,
  required Future<void> Function(ExpenseModel) onSave,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ExpenseForm(
      userId: userId,
      expense: expense,
      onSave: (newExpense) {
        Navigator.pop(context);
        onSave(newExpense);
      },
    ),
  );
}
