import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/feedback_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';

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
      final response = await http.get(
        Uri.parse(
          '${SupabaseConfig.url}/rest/v1/feedback_flow_records?feedback_id=eq.${widget.feedback.id}&select=*&order=created_at.desc',
        ),
        headers: AuthService.instance.authHeaders,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _flowRecords = data.cast<Map<String, dynamic>>();
          _loadingFlow = false;
        });
      } else {
        setState(() => _loadingFlow = false);
      }
    } catch (e) {
      debugPrint('加载流转记录失败: $e');
      setState(() => _loadingFlow = false);
    }
  }

  /// 获取分类标签信息
  _CategoryInfo _getCategoryInfo(String category, BuildContext context) {
    switch (category) {
      case 'bug':
        return _CategoryInfo(label: 'Bug', color: Theme.of(context).colorScheme.error);
      case 'feature':
        return _CategoryInfo(label: '功能建议', color: Theme.of(context).colorScheme.primary);
      case 'improvement':
        return _CategoryInfo(label: '体验优化', color: Theme.of(context).colorScheme.primary);
      case 'other':
        return _CategoryInfo(label: '其他', color: Theme.of(context).colorScheme.onSurfaceVariant);
      default:
        return _CategoryInfo(label: category, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }

  /// 获取状态标签信息
  _StatusInfo _getStatusInfo(String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return _StatusInfo(label: '待确认', color: Theme.of(context).colorScheme.onSurfaceVariant);
      case 'confirmed':
        return _StatusInfo(label: '已确认', color: Theme.of(context).colorScheme.primary);
      case 'in_progress':
        return _StatusInfo(label: '处理中', color: Theme.of(context).colorScheme.secondary);
      case 'resolved':
        return _StatusInfo(label: '已完结', color: AppTheme.success);
      case 'rejected':
        return _StatusInfo(label: '已拒绝', color: Theme.of(context).colorScheme.error);
      case 'delayed':
        return _StatusInfo(label: '已滞后', color: Colors.orange);
      default:
        return _StatusInfo(label: status, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
  }

  /// 获取操作标签信息
  _ActionInfo _getActionInfo(String action, BuildContext context) {
    switch (action) {
      case 'confirmed':
        return _ActionInfo(label: '确认', icon: Icons.check_circle, color: Colors.blue);
      case 'in_progress':
        return _ActionInfo(label: '处理中', icon: Icons.sync, color: Colors.orange);
      case 'resolved':
        return _ActionInfo(label: '完成', icon: Icons.check_circle_outline, color: AppTheme.success);
      case 'rejected':
        return _ActionInfo(label: '拒绝', icon: Icons.cancel, color: Theme.of(context).colorScheme.error);
      case 'delayed':
        return _ActionInfo(label: '滞后', icon: Icons.schedule, color: Colors.orange);
      case 'deleted':
        return _ActionInfo(label: '删除', icon: Icons.delete_outline, color: Colors.grey);
      default:
        return _ActionInfo(label: action, icon: Icons.circle, color: Colors.grey);
    }
  }

  /// 格式化时间
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '未知';
    try {
      final dt = DateTime.parse(dateStr);
      return DateTimeUtils.formatStandard(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final categoryInfo = _getCategoryInfo(feedback.category, context);
    final statusInfo = _getStatusInfo(feedback.status, context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('反馈详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              feedback.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // 标签行：分类 + 状态 + 时间
            Row(
              children: [
                _buildTag(categoryInfo.label, categoryInfo.color),
                const SizedBox(width: 10),
                _buildTag(statusInfo.label, statusInfo.color),
                const Spacer(),
                Text(
                  _formatDate(feedback.createdAt?.toIso8601String()),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 问题描述
            _buildSectionTitle('问题描述'),
            const SizedBox(height: 8),
            Text(
              feedback.description ?? '无描述',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                height: 1.6,
              ),
            ),

            // 管理员回复
            if (feedback.adminReply != null && feedback.adminReply!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('管理员回复'),
              const SizedBox(height: 8),
              Card(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    feedback.adminReply!,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],

            // 流转记录
            const SizedBox(height: 24),
            _buildSectionTitle('流转记录'),
            const SizedBox(height: 12),
            if (_loadingFlow)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_flowRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '暂无流转记录',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ..._flowRecords.asMap().entries.map((entry) {
                final index = entry.key;
                final record = entry.value;
                final actionInfo = _getActionInfo(record['action'] ?? '', context);
                final isLast = index == _flowRecords.length - 1;

                return _buildTimelineItem(
                  actionInfo: actionInfo,
                  record: record,
                  isLast: isLast,
                  colorScheme: colorScheme,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildTimelineItem({
    required _ActionInfo actionInfo,
    required Map<String, dynamic> record,
    required bool isLast,
    required ColorScheme colorScheme,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Icon(actionInfo.icon, size: 20, color: actionInfo.color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 操作标签 + 时间 + 操作人
                  Row(
                    children: [
                      _buildTag(actionInfo.label, actionInfo.color),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(record['created_at']),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (record['operator_name'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          record['operator_name'],
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 备注
                  if (record['remark'] != null && record['remark'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record['remark'],
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类标签信息
class _CategoryInfo {
  final String label;
  final Color color;

  const _CategoryInfo({required this.label, required this.color});
}

/// 状态标签信息
class _StatusInfo {
  final String label;
  final Color color;

  const _StatusInfo({required this.label, required this.color});
}

/// 操作标签信息
class _ActionInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _ActionInfo({required this.label, required this.icon, required this.color});
}
