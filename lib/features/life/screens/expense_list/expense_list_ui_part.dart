part of './expense_list_screen.dart';

/// 支出列表页主体 [Scaffold] 构建逻辑抽为顶层函数（UI 层搬运），
/// 避免 [_ExpenseListScreenState.build] 超长导致整个 State 文件逼近 500 行（膨胀修复）。
///
/// 纯 UI：所有状态值 / 回调由主 State 透传，渲染结果与原 build 逐字节等价。
/// 注意：区间清除 / 分类切换需回写 State，故以 `onClearRange` / `onSelectCategory` 回调透传，
/// 不能在此函数内直接对入参赋值（那不会作用于真实状态）。
Widget _buildExpenseListBody({
  required BuildContext context,
  required bool isLoading,
  required bool isLoadingTotal,
  required List<ExpenseModel> expenses,
  required DateTime displayedMonth,
  required double headlineTotal,
  required String headlineLabel,
  required String rangeHint,
  required DateTime? rangeStart,
  required DateTime? rangeEnd,
  required String selectedCategory,
  required bool readOnly,
  required ScrollController scrollController,
  required void Function() onClearRange,
  required void Function(String) onSelectCategory,
  required void Function(ExpenseModel) onEditExpense,
  required void Function(String) onDeleteExpense,
  required void Function() onLoadExpenses,
  required void Function() onShowExpenseForm,
  required Widget Function() onBuildLoadMore,
}) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('记账'),
      actions: [
        if (!readOnly)
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '消费统计',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseStatisticsScreen()),
              );
            },
          ),
      ],
    ),
    body: Column(
      children: [
        // 统计卡片（服务端聚合查询，不受分页限制）
        _ExpenseStatCard(
          displayedMonth: displayedMonth,
          totalAmount: headlineTotal,
          isLoadingTotal: rangeStart != null ? false : isLoadingTotal,
          overrideLabel: rangeStart != null ? headlineLabel : null,
        ),

        // 统计页跳转带入的筛选区间提示（可清除，清除后恢复不限日期）
        // 只读明细模式下隐藏，避免修改时间区间
        if (!readOnly && (rangeStart != null || rangeEnd != null))
          _ExpenseRangeBar(
            hint: rangeHint,
            onClear: onClearRange,
          ),
        const SizedBox(height: 8),

        // 分类筛选（只读明细模式下隐藏，避免修改消费分类）
        if (!readOnly)
          _ExpenseCategoryFilter(
            selectedCategory: selectedCategory,
            onSelected: onSelectCategory,
          ),
        if (!readOnly) const SizedBox(height: 8),

        // 支出列表
        Expanded(
          child: isLoading
              ? const LoadingWidget()
              : expenses.isEmpty
                  ? _ExpenseEmptyState(
                      onRefresh: onLoadExpenses,
                    )
                  : RefreshIndicator(
                      onRefresh: onLoadExpenses,
                      child: ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemExtent: AppTheme.scaledHeight(context, 72.0),
                        itemCount: expenses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == expenses.length) {
                            return onBuildLoadMore();
                          }

                          final expense = expenses[index];
                          final categoryLabel = DictService.instance.getLabelOrDefault(
                            'expense_category',
                            expense.category,
                            defaultValue: expense.category,
                          );
                          // date 与 created_at 日期相同时展示 created_at（含时间），不同时展示 date
                          final isSameDate = expense.createdAt != null &&
                              expense.date.year == expense.createdAt!.year &&
                              expense.date.month == expense.createdAt!.month &&
                              expense.date.day == expense.createdAt!.day;
                          final displayDate = (isSameDate && expense.createdAt != null)
                              ? expense.createdAt!
                              : expense.date;

                          return _ExpenseListItem(
                            expense: expense,
                            categoryLabel: categoryLabel,
                            displayDate: displayDate,
                            onEdit: readOnly ? null : () => onEditExpense(expense),
                            onDelete: readOnly ? null : () => onDeleteExpense(expense.id),
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
    floatingActionButton: !readOnly
        ? FloatingActionButton(
            onPressed: onShowExpenseForm,
            child: const Icon(Icons.add),
          )
        : null,
  );
}
