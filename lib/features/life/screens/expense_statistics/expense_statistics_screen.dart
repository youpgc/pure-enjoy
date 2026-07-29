import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../widgets/app_date_picker.dart';
import './expense_statistics_content.dart';

/// 消费统计页面
class ExpenseStatisticsScreen extends StatefulWidget {
  const ExpenseStatisticsScreen({super.key});

  @override
  State<ExpenseStatisticsScreen> createState() => _ExpenseStatisticsScreenState();
}

class _ExpenseStatisticsScreenState extends State<ExpenseStatisticsScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _error = '';
  DateTime _startMonth = DateTime.now();
  DateTime _endMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startMonth = DateTime.now();
    _endMonth = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = AuthService.instance.currentUserId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '请先登录';
      });
      return;
    }

    try {
      final startOfRange = DateTime(_startMonth.year, _startMonth.month, 1);
      final firstOfNextMonth = DateTime(_endMonth.year, _endMonth.month + 1, 1);

      final result = await ApiClient.get(
        'expenses',
        filters: {
          'user_id': 'eq.$userId',
          'and': '(date.gte.${DateFormat('yyyy-MM-dd').format(startOfRange)},date.lt.${DateFormat('yyyy-MM-dd').format(firstOfNextMonth)})',
        },
        order: 'date.desc',
        limit: 500,
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _expenses = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickStartMonth() async {
    final picked = await AppDatePicker.show(
      context,
      type: DateTimeType.yearMonth,
      initialDate: _startMonth,
      minDate: DateTime(2020),
      maxDate: DateTime.now(),
      title: '选择起始月份',
    );
    if (picked != null) {
      final newStart = DateTime(picked.year, picked.month);
      // 限制最多6个月
      final maxEnd = DateTime(newStart.year, newStart.month + 6, 0);
      setState(() {
        _startMonth = newStart;
        if (_endMonth.isBefore(_startMonth)) {
          _endMonth = _startMonth;
        } else if (_endMonth.isAfter(maxEnd)) {
          _endMonth = maxEnd;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  Future<void> _pickEndMonth() async {
    final picked = await AppDatePicker.show(
      context,
      type: DateTimeType.yearMonth,
      initialDate: _endMonth,
      minDate: DateTime(2020),
      maxDate: DateTime.now(),
      title: '选择结束月份',
    );
    if (picked != null) {
      final newEnd = DateTime(picked.year, picked.month);
      // 限制最多6个月
      final minStart = DateTime(newEnd.year, newEnd.month - 5, 1);
      setState(() {
        _endMonth = newEnd;
        if (_startMonth.isAfter(_endMonth)) {
          _startMonth = _endMonth;
        } else if (_startMonth.isBefore(minStart)) {
          _startMonth = minStart;
        }
        _isLoading = true;
      });
      _loadData();
    }
  }

  String get _rangeText {
    final sameYear = _startMonth.year == _endMonth.year;
    if (_startMonth.year == _endMonth.year && _startMonth.month == _endMonth.month) {
      return '${_startMonth.year}年${_startMonth.month}月';
    }
    if (sameYear) {
      return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.month}月';
    }
    return '${_startMonth.year}年${_startMonth.month}月 - ${_endMonth.year}年${_endMonth.month}月';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费统计'),
      ),
      body: ExpenseStatisticsContent(
        expenses: _expenses,
        isLoading: _isLoading,
        error: _error,
        startMonth: _startMonth,
        endMonth: _endMonth,
        rangeText: _rangeText,
        onPickStartMonth: _pickStartMonth,
        onPickEndMonth: _pickEndMonth,
      ),
    );
  }
}
