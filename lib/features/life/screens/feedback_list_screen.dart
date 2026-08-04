import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../utils/date_time_utils.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../models/feedback_model.dart';
import './feedback_submit_screen.dart';
import './feedback_detail/feedback_detail_screen.dart';

/// 问题反馈列表页面
class FeedbackListScreen extends StatefulWidget {
  const FeedbackListScreen({super.key});

  @override
  State<FeedbackListScreen> createState() => _FeedbackListScreenState();
}

class _FeedbackListScreenState extends State<FeedbackListScreen> with PaginatedListMixin {
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = true;
  bool _isFirstLoad = true;

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadFeedbacks();
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadFeedbacks();
  }

  /// 加载反馈列表
  Future<void> _loadFeedbacks({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _feedbacks = [];
        _isLoading = false;
      });
      return;
    }

    if (refresh) {
      resetPagination();
      _isFirstLoad = false;
    } else if (_isFirstLoad) {
      // 首次加载必须从第 1 页（offset 0）开始。beginLoadMore() 会自增 _currentPage 到 2，
      // 使 offset=10，导致反馈 ≤10 条时首页读不到、进入页面无数据（刷新时才复位为第 1 页）。
      resetPagination();
      _isFirstLoad = false;
    } else {
      if (!beginLoadMore()) return;
    }

    try {
      final (limit, offset) = paginationParams;

      final result = await ApiClient.get(
        'user_feedback',
        filters: {
          'user_id': 'eq.$userId',
          'is_deleted': 'eq.false',
        },
        order: 'created_at.desc',
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess) {
        final feedbacks = result.data!.map((e) => FeedbackModel.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            if (refresh) {
              _feedbacks = feedbacks;
            } else {
              _feedbacks.addAll(feedbacks);
            }
            _isLoading = false;
            onPaginationDataLoaded(feedbacks.length);
          });
        }
      } else {
        throw Exception(result.errorMessage ?? '请求失败');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_feedbacks.isEmpty) {
          showSnackBar(context, '加载失败，请稍后重试', isError: true);
        }
      }
    }
  }

  /// 获取分类标签信息
  _CategoryInfo _getCategoryInfo(String category) {
    final label = DictService.instance.getLabelOrDefault('feedback_category', category, defaultValue: category);
    final Color color;
    switch (category) {
      case 'bug':
        color = Theme.of(context).colorScheme.error;
      case 'feature':
        color = Theme.of(context).colorScheme.primary;
      case 'improvement':
        color = Theme.of(context).colorScheme.primary;
      case 'other':
        color = Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return _CategoryInfo(label: label, color: color);
  }

  /// 获取状态标签信息
  _StatusInfo _getStatusInfo(String status) {
    final label = DictService.instance.getLabelOrDefault('feedback_status', status, defaultValue: status);
    final Color color;
    switch (status) {
      case 'pending':
        color = Theme.of(context).colorScheme.onSurfaceVariant;
      case 'confirmed':
        color = Theme.of(context).colorScheme.primary;
      case 'in_progress':
        color = Theme.of(context).colorScheme.secondary;
      case 'resolved':
        color = AppTheme.success;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return _StatusInfo(label: label, color: color);
  }

  /// 格式化时间（固定北京时区，与详情屏口径一致）
  /// created_at 为 UTC，需先转北京墙钟；now 用 nowBeijing() 取北京自然日，
  /// 否则本机时区非 UTC+8 时「今天/昨天」边界会偏移（如 UTC 模拟器偏 8 小时）。
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final nowBj = DateTimeUtils.nowBeijing();
    final dtBj = DateTimeUtils.toBeijingWallClock(dateTime);
    final diff = nowBj.difference(dtBj).inDays;
    if (diff == 0) {
      return '${dtBj.hour.toString().padLeft(2, '0')}:${dtBj.minute.toString().padLeft(2, '0')}';
    } else if (diff == 1) {
      return '昨天';
    } else if (diff < 7) {
      return '$diff天前';
    } else {
      return '${dtBj.month}/${dtBj.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('问题反馈'),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _feedbacks.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadFeedbacks(refresh: true),
                  child: const CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyWidget(
                          icon: Icons.feedback_outlined,
                          message: '暂无反馈记录',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadFeedbacks(refresh: true),
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _feedbacks.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _feedbacks.length) {
                        return buildLoadMoreIndicator();
                      }
                      final feedback = _feedbacks[index];
                      final categoryInfo = _getCategoryInfo(feedback.category);
                      final statusInfo = _getStatusInfo(feedback.status);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(feedback.title),
                          subtitle: Row(
                            children: [
                              // 分类标签
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryInfo.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  categoryInfo.label,
                                  style: TextStyle(
                                    color: categoryInfo.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 状态标签
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusInfo.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  statusInfo.label,
                                  style: TextStyle(
                                    color: statusInfo.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // 创建时间
                              Text(
                                _formatDate(feedback.createdAt),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeedbackDetailScreen(
                                  feedback: feedback,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FeedbackSubmitScreen(),
            ),
          );
          _loadFeedbacks(refresh: true); // 返回后刷新列表
        },
        child: const Icon(Icons.add),
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
