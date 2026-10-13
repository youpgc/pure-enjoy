import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/backend_api.dart';
import '../../models/feedback_model.dart';
import './feedback_detail_content.dart';

/// 问题反馈详情页面（含流转记录）
class FeedbackDetailScreen extends StatefulWidget {
  final FeedbackModel feedback;

  const FeedbackDetailScreen({super.key, required this.feedback});

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  List<Map<String, dynamic>> _flowRecords = [];
  bool _loadingFlow = true;

  @override
  void initState() {
    super.initState();
    _loadFlowRecords();
  }

  Future<void> _loadFlowRecords() async {
    try {
      // change-server：改走后端反馈详情端点，流转记录随详情一并返回（VO.flow）
      final result = await BackendApi.get(
        '/users/feedbacks/${widget.feedback.id}',
      );

      if (!mounted) return;
      if (result.success && result.data is Map<String, dynamic>) {
        final flow =
            (result.data as Map<String, dynamic>)['flow'] as List<dynamic>? ??
                [];
        setState(() {
          _flowRecords = flow.cast<Map<String, dynamic>>();
          _loadingFlow = false;
        });
      } else {
        setState(() => _loadingFlow = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载流转记录失败');
      }
      if (mounted) {
        setState(() => _loadingFlow = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈详情'),
      ),
      body: FeedbackDetailContent(
        feedback: widget.feedback,
        flowRecords: _flowRecords,
        loadingFlow: _loadingFlow,
      ),
    );
  }
}
