import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/dict_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/offline_sync_service.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../../utils/cache_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/paginated_list_mixin.dart';
import '../../../../core/utils/event_bus.dart';
import '../../../../widgets/common_widgets.dart';
import '../../models/expense_model.dart';
import '../expense_statistics/expense_statistics_screen.dart';
import '../../widgets/expense_form.dart';

part 'expense_list_parts.dart';
part 'expense_list_ui_part.dart';

/// 支出列表页面 - Supabase 数据同步
class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({
    super.key,
    this.initialCategory = 'all',
    this.initialStartMonth,
    this.initialEndMonth,
    this.readOnly = false,
  });

  /// 从统计页跳转带入的预选分类，默认 'all'（不限分类）。
  final String initialCategory;

  /// 从统计页跳转带入的预置日期区间（月份），为空表示不限日期。
  final DateTime? initialStartMonth;
  final DateTime? initialEndMonth;

  /// 是否为只读明细模式：统计页按分类查看对应消费记录时传入 true。
  /// 只读模式下隐藏全部交互控件（统计跳转 / 分类筛选 / 时间区间 / 新增 / 编辑删除），
  /// 仅保留下拉刷新与触底加载等数据加载能力；普通记账列表页保持默认 false，逻辑不受影响。
  final bool readOnly;

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

/// 抽象宿主类：声明 CRUD mixin 需要调用的成员，避免 mixin 自引用约束导致整条
/// `with` 子句失效（膨胀修复）。
abstract class _ExpenseListActionsHost extends State<ExpenseListScreen> {
  Future<void> _loadExpenses({bool refresh = false});
  String? get _userId;
}

class _ExpenseListScreenState extends _ExpenseListActionsHost
    with PaginatedListMixin, _ExpenseListActionsMixin {
  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _displayedMonth = DateTime.now();
  double _totalAmount = 0.0;
  bool _isLoadingTotal = false;
  Timer? _monthUpdateDebounce;

  @override
  String? get _userId => AuthService.instance.currentUserId;

  /// 统计页跳转带入的筛选区间提示文案
  String get _rangeHint {
    final cat = _selectedCategory == 'all'
        ? '全部分类'
        : DictService.instance.getLabelOrDefault(
            'expense_category',
            _selectedCategory,
            defaultValue: _selectedCategory,
          );
    final range = (_rangeStart != null && _rangeEnd != null)
        ? '${_rangeStart!.year}年${_rangeStart!.month}月 - ${_rangeEnd!.year}年${_rangeEnd!.month}月'
        : _rangeStart != null
            ? '${_rangeStart!.year}年${_rangeStart!.month}月起'
            : '至${_rangeEnd!.year}年${_rangeEnd!.month}月';
    return '统计区间：$range · $cat';
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _rangeStart = widget.initialStartMonth;
    _rangeEnd = widget.initialEndMonth;
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
      final double itemHeight = AppTheme.scaledHeight(context, 72.0);
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

  @override
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

      // 预置日期区间（统计页跳转带入）：与统计页取数口径一致
      // [startMonth 当月1号, endMonth 下月1号)
      if (_rangeStart != null && _rangeEnd != null) {
        final gte = DateTime(_rangeStart!.year, _rangeStart!.month, 1);
        final lt = DateTime(_rangeEnd!.year, _rangeEnd!.month + 1, 1);
        filters['and'] =
            '(date.gte.${DateFormat('yyyy-MM-dd').format(gte)},date.lt.${DateFormat('yyyy-MM-dd').format(lt)})';
      } else if (_rangeStart != null) {
        final gte = DateTime(_rangeStart!.year, _rangeStart!.month, 1);
        filters['date'] = 'gte.${DateFormat('yyyy-MM-dd').format(gte)}';
      } else if (_rangeEnd != null) {
        final lt = DateTime(_rangeEnd!.year, _rangeEnd!.month + 1, 1);
        filters['date'] = 'lt.${DateFormat('yyyy-MM-dd').format(lt)}';
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

  /// 顶部统计卡片标题：区间生效时显示区间文案，否则显示当前视窗月份。
  String get _headlineLabel {
    if (_rangeStart != null && _rangeEnd != null) {
      return '${_rangeStart!.year}年${_rangeStart!.month}月 - ${_rangeEnd!.year}年${_rangeEnd!.month}月';
    } else if (_rangeStart != null) {
      return '${_rangeStart!.year}年${_rangeStart!.month}月起';
    } else if (_rangeEnd != null) {
      return '至${_rangeEnd!.year}年${_rangeEnd!.month}月';
    }
    return '${_displayedMonth.year}年${_displayedMonth.month.toString().padLeft(2, '0')}月';
  }

  /// 顶部统计卡片金额：区间生效时显示区间内已加载记录的合计（与统计页本地聚合口径一致），
  /// 否则显示服务端 RPC 的当月合计（_totalAmount）。
  double get _headlineTotal {
    if (_rangeStart != null || _rangeEnd != null) {
      return _expenses.fold(0.0, (sum, e) => sum + e.amount);
    }
    return _totalAmount;
  }

  @override
  Widget build(BuildContext context) {
    return _buildExpenseListBody(
      context: context,
      isLoading: _isLoading,
      isLoadingTotal: _isLoadingTotal,
      expenses: _expenses,
      displayedMonth: _displayedMonth,
      headlineTotal: _headlineTotal,
      headlineLabel: _headlineLabel,
      rangeHint: _rangeHint,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      selectedCategory: _selectedCategory,
      readOnly: widget.readOnly,
      scrollController: scrollController,
      onClearRange: () {
        setState(() {
          _rangeStart = null;
          _rangeEnd = null;
        });
        _loadExpenses(refresh: true);
      },
      onSelectCategory: (category) {
        setState(() => _selectedCategory = category);
        _loadExpenses(refresh: true);
      },
      onEditExpense: _showEditExpenseForm,
      onDeleteExpense: _deleteExpense,
      onLoadExpenses: () => _loadExpenses(refresh: true),
      onShowExpenseForm: _showExpenseForm,
      onBuildLoadMore: buildLoadMoreIndicator,
    );
  }
}
