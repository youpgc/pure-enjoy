import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/api_client.dart';
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
      final result = await ApiClient.get(
        'feedback_flow_records',
        filters: {'feedback_id': 'eq.${widget.feedback.id}'},
        order: 'created_at.desc',
      );

      if (!mounted) return;
      if (result.isSuccess) {
        setState(() {
          _flowRecords = result.data!;
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
