import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../../../utils/date_time_utils.dart';
import '../../../../utils/cache_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../services/dict_service.dart';
import '../../models/favorite_model.dart';

part 'favorites_screen_parts.dart';

/// 收藏夹页面 - Supabase 数据同步
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with _FavoritesScreenDialogMixin {
  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  String? get _userId => AuthService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFavorites();
    // 预加载字典缓存，避免下拉框首次打开时为空
    DictService.instance.ensureInitialized();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadFavorites();
      }
    }
  }

  Future<void> _loadFavorites({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _favorites = [];
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final isFirstPage = _offset == 0;

    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
        _favorites = [];
        _isLoading = true;
      });
    } else if (isFirstPage) {
      // 1. 先加载本地缓存（仅在初始第一页时）
      final cached = await CacheHelper.instance.loadList(CacheHelper.keyFavorites);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _favorites = cached.map((e) => FavoriteModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } else {
      setState(() => _isLoadingMore = true);
    }

    // 2. 从网络分页加载
    try {
      final filters = <String, String>{
        'user_id': 'eq.$userId',
      };

      final result = await ApiClient.get(
        'user_favorites',
        filters: filters,
        order: 'created_at.desc',
        limit: _limit,
        offset: _offset,
      );

      if (result.isSuccess) {
        final data = result.data!;
        final items = data.map((e) => FavoriteModel.fromJson(e)).toList();
        // 仅第一页时保存缓存
        if (_offset == 0) {
          await CacheHelper.instance.saveList(CacheHelper.keyFavorites, data);
        }
        if (mounted) {
          setState(() {
            if (refresh || isFirstPage) {
              _favorites = items;
            } else {
              _favorites.addAll(items);
            }
            _offset += _limit;
            _hasMore = items.length >= _limit;
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception('HTTP ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        // 如果已有缓存数据，静默失败不提示
        if (_favorites.isEmpty) {
          _showError('加载收藏失败，请稍后重试');
        }
      }
    }
  }

  void _showError(String message) {
    showSnackBar(context, message, isError: true);
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('无法打开链接');
      }
    } catch (e) {
      _showError('打开链接失败，请稍后重试');
    }
  }

  Future<void> _deleteFavorite(String id) async {
    final confirmed = await showConfirmDialog(context, title: '确认删除', content: '确定要删除这个收藏吗？');

    if (confirmed == true) {
      try {
        final result = await ApiClient.batchDeleteByFilter(
          'user_favorites',
          filters: {'id': 'eq.$id'},
        );

        if (result.isSuccess) {
          _loadFavorites(refresh: true);
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _favorites.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadFavorites(refresh: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const Center(
                          child: EmptyWidget(icon: Icons.bookmark_border, message: '暂无收藏'),
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadFavorites(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _favorites.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: LoadingWidget()),
                        );
                      }
                      final favorite = _favorites[index];
                      final categoryLabel = DictService.instance.getLabelOrDefault('favorite_category', favorite.category ?? '', defaultValue: favorite.category ?? '其他');

                      return _FavoriteListItem(
                        favorite: favorite,
                        categoryLabel: categoryLabel,
                        onTap: () => _openUrl(favorite.url),
                        onEdit: () => _showEditDialog(favorite: favorite),
                        onDelete: () => _deleteFavorite(favorite.id),
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

