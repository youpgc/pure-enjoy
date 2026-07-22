import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../services/offline_sync_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../../utils/cache_helper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../../../core/utils/event_bus.dart';
import '../../../widgets/common_widgets.dart';
import '../models/expense_model.dart';
import 'expense_statistics_screen.dart';
import '../widgets/expense_form.dart';

part 'expense_list_parts.dart';

/// 支出列表页面 - Supabase 数据同步
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> with PaginatedListMixin {
  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  DateTime _displayedMonth = DateTime.now();
  double _totalAmount = 0.0;
  bool _isLoadingTotal = false;
  Timer? _monthUpdateDebounce;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    scrollController.addListener(_onScrollForMonth);
    _initLoad();
  }

  @override
  void dispose() {
    _monthUpdateDebounce?.cancel();
    scrollController.removeListener(_onScrollForMonth);
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadExpenses();
  }

  /// 初始化加载：先确保字典加载完成，再读缓存，最后静默刷新
  Future<void> _initLoad() async {
    try {
      await DictService.instance.initialize();
      await _loadCache();
      // 静默刷新须走整页刷新（refresh:true），否则 beginLoadMore 会从第 2 页开始取数，
      // 导致按 date.desc 排在最顶部的最新记录（第 1 页）永远不被重新拉取。
      await _loadExpenses(refresh: true);
      // 数据加载后，将显示月份更新为第一条数据的月份
      if (mounted && _expenses.isNotEmpty) {
        final firstMonth = DateTime(_expenses.first.date.year, _expenses.first.date.month);
        if (firstMonth != _displayedMonth) {
          setState(() => _displayedMonth = firstMonth);
        }
        _loadTotalAmountForMonth(firstMonth);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ExpenseListScreen _initLoad 异常');
        debugPrint('堆栈信息');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, '初始化失败，请稍后重试', isError: true);
      }
    }
  }

  /// 从 SharedPreferences 加载缓存数据
  Future<void> _loadCache() async {
    final userId = _userId;
    if (userId == null) return;
    final cached = await CacheHelper.instance.loadList(CacheHelper.keyExpenses);
    if (cached.isNotEmpty && mounted) {
      final allExpenses = cached.map((e) => ExpenseModel.fromJson(e)).toList();
      setState(() {
        _expenses = allExpenses;
        _isLoading = false;
      });
    }
  }

  /// 根据滚动位置检测当前视窗月份并更新统计
  void _onScrollForMonth() {
    if (!scrollController.hasClients || _expenses.isEmpty) return;
    _monthUpdateDebounce?.cancel();
    _monthUpdateDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final pixels = scrollController.position.pixels;
      const itemHeight = 72.0;
      final index = (pixels / itemHeight).floor().clamp(0, _expenses.length - 1);
      final expense = _expenses[index];
      final month = DateTime(expense.date.year, expense.date.month);
      if (month != _displayedMonth) {
        setState(() => _displayedMonth = month);
        _loadTotalAmountForMonth(month);
      }
    });
  }

  /// 加载指定月份总支出（服务端 RPC SUM 聚合，不受分页限制）
  Future<void> _loadTotalAmountForMonth(DateTime month) async {
    final userId = _userId;
    if (userId == null) return;

    setState(() => _isLoadingTotal = true);

    try {
      final result = await ApiClient.rpc('fn_get_monthly_expense_total', params: {
        'p_user_id': userId,
        'p_year': month.year,
        'p_month': month.month,
        'p_category': _selectedCategory,
      });

      double total = 0.0;
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final value = result.data!.first['total'];
        if (value != null) {
          total = (value as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _totalAmount = total;
          _isLoadingTotal = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 加载总支出失败: $e');
      }
      if (mounted) {
        setState(() => _isLoadingTotal = false);
      }
    }
  }

  Future<void> _loadExpenses({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '请先登录');
      }
      return;
    }

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      if (_selectedCategory != 'all') {
        filters['category'] = 'eq.$_selectedCategory';
      }

      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'expenses',
        filters: filters,
        order: 'date.desc',
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final newExpenses = data.map((e) => ExpenseModel.fromJson(e)).toList();

        // date 排序优先，相同 date 时 created_at 优先
        newExpenses.sort((a, b) {
          final dateCmp = b.date.compareTo(a.date);
          if (dateCmp != 0) return dateCmp;
          final aTime = a.createdAt ?? a.date;
          final bTime = b.createdAt ?? b.date;
          return bTime.compareTo(aTime);
        });

        setState(() {
          if (refresh) {
            _expenses = newExpenses;
          } else {
            // 追加后重新全局排序（保证跨页合并后顺序正确）
            _expenses.addAll(newExpenses);
            _expenses.sort((a, b) {
              final dateCmp = b.date.compareTo(a.date);
              if (dateCmp != 0) return dateCmp;
              final aTime = a.createdAt ?? a.date;
              final bTime = b.createdAt ?? b.date;
              return bTime.compareTo(aTime);
            });
          }
          _isLoading = false;
          onPaginationDataLoaded(newExpenses.length);
        });

        // 刷新后更新顶部月份统计为当前视窗月份
        if (refresh && _expenses.isNotEmpty) {
          final firstMonth = DateTime(_expenses.first.date.year, _expenses.first.date.month);
          if (firstMonth != _displayedMonth) {
            setState(() => _displayedMonth = firstMonth);
          }
          _loadTotalAmountForMonth(firstMonth);
        }

        // 写入缓存（保存全部数据，不按月筛选）
        if (refresh) {
          await CacheHelper.instance.saveList(
            CacheHelper.keyExpenses,
            _expenses.map((e) => e.toJson()).toList(),
          );
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showSnackBar(context, '加载失败，请稍后重试', isError: true);
      }
    }
  }

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
    final confirm = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这条记录吗？');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账'),
        actions: [
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
            displayedMonth: _displayedMonth,
            totalAmount: _totalAmount,
            isLoadingTotal: _isLoadingTotal,
          ),

          // 分类筛选
          _ExpenseCategoryFilter(
            selectedCategory: _selectedCategory,
            onSelected: (category) {
              setState(() => _selectedCategory = category);
              _loadExpenses(refresh: true);
            },
          ),
          const SizedBox(height: 8),

          // 支出列表
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _expenses.isEmpty
                    ? _ExpenseEmptyState(
                        onRefresh: () => _loadExpenses(refresh: true),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadExpenses(refresh: true),
                        child: ListView.builder(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemExtent: 72.0,
                          itemCount: _expenses.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _expenses.length) {
                              return buildLoadMoreIndicator();
                            }

                            final expense = _expenses[index];
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
                              onEdit: () => _showEditExpenseForm(expense),
                              onDelete: () => _deleteExpense(expense.id),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
