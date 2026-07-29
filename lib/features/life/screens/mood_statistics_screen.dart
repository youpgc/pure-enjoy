import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import 'mood_statistics_content.dart';

/// 心情统计页面
class MoodStatisticsScreen extends StatefulWidget {
  const MoodStatisticsScreen({super.key});

  @override
  State<MoodStatisticsScreen> createState() => _MoodStatisticsScreenState();
}

class _MoodStatisticsScreenState extends State<MoodStatisticsScreen> {
  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
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
      // 获取最近30天记录
      final result = await ApiClient.get(
        'mood_diaries',
        filters: {'user_id': 'eq.$userId'},
        order: 'date.desc',
        limit: 30,
      );

      if (!mounted) return;
      if (result.isSuccess) {
        final List<dynamic> data = result.data!;
        setState(() {
          _diaries = data.cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情统计'),
      ),
      body: MoodStatisticsContent(
        diaries: _diaries,
        isLoading: _isLoading,
        error: _error,
      ),
    );
  }
}
