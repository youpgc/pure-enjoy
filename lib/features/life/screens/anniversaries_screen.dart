import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../services/api_client.dart';
import '../../../services/notification_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/paginated_list_mixin.dart';
import '../models/anniversary_model.dart';
import '../widgets/anniversary_card.dart';
import '../widgets/anniversary_edit_dialog.dart';
import '../helpers/anniversary_cache_helper.dart';
import './anniversary_helpers.dart';

/// 纪念日/生日列表页面 - Supabase 数据同步
class AnniversariesScreen extends StatefulWidget {
  /// 类型过滤：'anniversary' 或 'birthday'
  final String filterType;

  const AnniversariesScreen({super.key, this.filterType = 'anniversary'});

  @override
  State<AnniversariesScreen> createState() => _AnniversariesScreenState();
}

class _AnniversariesScreenState extends State<AnniversariesScreen> with PaginatedListMixin {
  List<AnniversaryModel> _anniversaries = [];
  bool _isLoading = true;

  String? get _userId => AuthService.instance.currentUserId;
  String? get _userNickname => AuthService.instance.currentUserName;

  // 按用户隔离：键加 userId 前缀，防止切换账号后旧账号纪念日被新账号加载
  // （同类 annotation_local_service 泄露修复；未登录用 'guest' 占位键）
  String get _cacheKey =>
      'cached_anniversaries_${_userId ?? 'guest'}_${widget.filterType}';

  @override
  void initState() {
    super.initState();
    initPagination();
    _loadAnniversaries(refresh: true);
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  void onLoadMore() {
    _loadAnniversaries();
  }

  Future<void> _loadAnniversaries({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _anniversaries = [];
        _isLoading = false;
      });
      return;
    }

    if (refresh) {
      resetPagination();
    }
    if (!refresh && !beginLoadMore()) return;

    // 1. 先加载本地缓存（仅 refresh 时）
    if (refresh) {
      final cachedData = await loadAnniversaryCache(_cacheKey);
      if (cachedData.isNotEmpty && mounted) {
        setState(() {
          _anniversaries =
              cachedData.map((e) => AnniversaryModel.fromJson(e)).toList();
          _sortAnniversaries();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    }

    // 2. 静默从网络刷新
    try {
      final (limit, offset) = paginationParams;
      final result = await ApiClient.get(
        'user_anniversaries',
        filters: {
          'user_id': 'eq.$userId',
          'type': 'eq.${widget.filterType}',
        },
        order: 'date.asc',
        limit: limit,
        offset: offset,
      );

      if (!result.isSuccess) {
        throw Exception('HTTP ${result.statusCode}');
      }

      final data = result.data!;
      final items = data.map((e) => AnniversaryModel.fromJson(e)).toList();

      // 保存缓存（只保存当前用户、当前类型的数据，仅 refresh 时）
      if (refresh) {
        await saveAnniversaryCache(_cacheKey, data);
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _anniversaries = items;
          } else {
            _anniversaries.addAll(items);
          }
          _sortAnniversaries();
          _isLoading = false;
          onPaginationDataLoaded(items.length);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_anniversaries.isEmpty) {
          _showError('加载纪念日失败，请稍后重试');
        }
      }
    }
  }

  /// 按距离下一个纪念日的天数排序（最近的排在前面）
  void _sortAnniversaries() {
    _anniversaries.sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));
  }

  void _showError(String message) {
    showSnackBar(context, message, isError: true);
  }

  Future<void> _deleteAnniversary(String id) async {
    final userId = _userId;
    if (userId == null) {
      _showError('请先登录后再删除');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      content: '确定要删除这个纪念日吗？',
    );

    if (confirmed == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'user_anniversaries',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          // 删除后取消对应的本地横幅提醒
          NotificationService.instance.cancelAnniversaryReminder(id);
          _loadAnniversaries(refresh: true);
          if (mounted) {
            showSnackBar(context, '删除成功');
          }
        } else {
          throw Exception('HTTP ${result.statusCode}');
        }
      } catch (e) {
        _showError('删除失败，请稍后重试');
      }
    }
  }

  Future<void> _showEditDialog({AnniversaryModel? anniversary}) async {
    await showAnniversaryEditDialog(
      context,
      anniversary: anniversary,
      filterType: widget.filterType,
      userId: _userId,
      userNickname: _userNickname,
      onSaved: () => _loadAnniversaries(refresh: true),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isBirthday = widget.filterType == 'birthday';
    final title = isBirthday ? '生日' : '纪念日';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _anniversaries.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadAnniversaries(refresh: true),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyWidget(
                          icon: isBirthday ? Icons.cake_outlined : Icons.celebration_outlined,
                          message: '还没有$title',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAnniversaries(refresh: true),
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _anniversaries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _anniversaries.length) {
                        return buildLoadMoreIndicator();
                      }
                      final item = _anniversaries[index];
                      return AnniversaryCard(
                        item: item,
                        daysText: getAnniversaryDaysText(item),
                        formatDate: formatAnniversaryDate(item),
                        onEdit: () => _showEditDialog(anniversary: item),
                        onDelete: () => _deleteAnniversary(item.id),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

