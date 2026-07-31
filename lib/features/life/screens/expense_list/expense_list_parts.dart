part of './expense_list_screen.dart';

/// 支出统计卡片（服务端聚合查询，不受分页限制）
class _ExpenseStatCard extends StatelessWidget {
  final DateTime displayedMonth;
  final double totalAmount;
  final bool isLoadingTotal;
  final String? overrideLabel;

  const _ExpenseStatCard({
    required this.displayedMonth,
    required this.totalAmount,
    required this.isLoadingTotal,
    this.overrideLabel,
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
            overrideLabel ??
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

/// 统计页跳转带入的筛选区间提示条
class _ExpenseRangeBar extends StatelessWidget {
  final String hint;
  final VoidCallback onClear;

  const _ExpenseRangeBar({required this.hint, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ),
            TextButton(onPressed: onClear, child: const Text('清除')),
          ],
        ),
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

/// 记账 CRUD 动作抽取为 mixin，避免 [_ExpenseListScreenState] 超 500 行（膨胀修复）。
///
/// 约束 `on _ExpenseListScreenState`：可直接调用其 [_loadExpenses] / [_userId] 等成员。
mixin _ExpenseListActionsMixin on _ExpenseListActionsHost {
  Future<void> _addExpense(ExpenseModel expense) async {
    try {
      final result = await ApiClient.post(
        'expenses',
        expense.toJson(),
      );

      if (result.isSuccess) {
        await _loadExpenses(refresh: true);
        EventBus.instance.fire(EventType.expenseUpdated);
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          showSnackBar(context, '添加成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.create,
          table: 'expenses',
          data: expense.toJson(),
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.create,
        table: 'expenses',
        data: expense.toJson(),
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '确定要删除这条记录吗？',
    );

    if (confirm == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'expenses',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          await _loadExpenses(refresh: true);
          EventBus.instance.fire(EventType.expenseUpdated);
          OfflineSyncService.instance.syncPending();
          if (mounted) {
            showSnackBar(context, '删除成功');
          }
        } else {
          await OfflineSyncService.instance.enqueue(
            action: OfflineAction.delete,
            table: 'expenses',
            filters: {'id': 'eq.$id'},
          );
          if (mounted) {
            showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
          }
        }
      } catch (e) {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.delete,
          table: 'expenses',
          filters: {'id': 'eq.$id'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    }
  }

  Future<void> _updateExpense(ExpenseModel expense) async {
    try {
      final body = {
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'note': expense.note,
        'date': expense.date.toIso8601String().split('T').first,
      };
      final result = await ApiClient.patchByFilter(
        'expenses',
        filters: {'id': 'eq.${expense.id}'},
        body: body,
      );

      if (result.isSuccess) {
        await _loadExpenses(refresh: true);
        EventBus.instance.fire(EventType.expenseUpdated);
        OfflineSyncService.instance.syncPending();
        if (mounted) {
          showSnackBar(context, '更新成功');
        }
      } else {
        await OfflineSyncService.instance.enqueue(
          action: OfflineAction.update,
          table: 'expenses',
          data: body,
          filters: {'id': 'eq.${expense.id}'},
        );
        if (mounted) {
          showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
        }
      }
    } catch (e) {
      final body = {
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'note': expense.note,
        'date': expense.date.toIso8601String().split('T').first,
      };
      await OfflineSyncService.instance.enqueue(
        action: OfflineAction.update,
        table: 'expenses',
        data: body,
        filters: {'id': 'eq.${expense.id}'},
      );
      if (mounted) {
        showSnackBar(context, '网络异常，已加入离线队列，恢复后自动同步');
      }
    }
  }

  void _showEditExpenseForm(ExpenseModel expense) {
    _showExpenseFormSheet(
      context: context,
      userId: _userId ?? 'local_user',
      expense: expense,
      onSave: _updateExpense,
    );
  }

  void _showExpenseForm() {
    _showExpenseFormSheet(
      context: context,
      userId: _userId ?? 'local_user',
      onSave: _addExpense,
    );
  }
}
