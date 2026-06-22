import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../../services/dict_service.dart';
import '../../../services/api_client.dart';
import '../../../core/utils/event_bus.dart';
import 'expense_list_screen.dart';
import 'mood_diary_screen.dart';
import 'note_list_screen.dart';
import 'weight_record_screen.dart';
import 'favorites_screen.dart';
import 'reminders_screen.dart';
import 'habits_screen.dart';
import 'anniversaries_screen.dart';


/// 生活模块主页面 - 展示最新记录 + 功能入口
class LifeScreen extends StatefulWidget {
  const LifeScreen({super.key});

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  bool _isLoading = true;

  // 最新记录数据
  Map<String, dynamic>? _latestExpense;
  Map<String, dynamic>? _latestWeight;

  StreamSubscription<void>? _expenseSubscription;
  StreamSubscription<void>? _weightSubscription;

  @override
  void initState() {
    super.initState();
    _loadLatestRecords();
    _listenEvents();
  }

  /// 监听全局事件，数据变更时自动刷新
  void _listenEvents() {
    _expenseSubscription = EventBus.instance.on(EventType.expenseUpdated).listen((_) {
      _loadLatestRecords();
    });
    _weightSubscription = EventBus.instance.on(EventType.weightRecordUpdated).listen((_) {
      _loadLatestRecords();
    });
  }

  @override
  void dispose() {
    _expenseSubscription?.cancel();
    _weightSubscription?.cancel();
    super.dispose();
  }

  /// 从 Supabase 加载各模块最新记录
  Future<void> _loadLatestRecords() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 并行请求两个模块的最新记录
      final results = await Future.wait([
        ApiClient.get(
          'expenses',
          filters: {'user_id': 'eq.$userId'},
          order: 'created_at.desc',
          limit: 1,
        ),
        ApiClient.get(
          'weight_records',
          filters: {'user_id': 'eq.$userId'},
          order: 'created_at.desc',
          limit: 1,
        ),
      ]);

      if (!mounted) return;

      final expenseList = results[0].isSuccess ? results[0].data! : [];
      final weightList = results[1].isSuccess ? results[1].data! : [];

      setState(() {
        _latestExpense =
            expenseList.isNotEmpty ? expenseList[0] as Map<String, dynamic> : null;
        _latestWeight =
            weightList.isNotEmpty ? weightList[0] as Map<String, dynamic> : null;
        _isLoading = false;
      });
    } catch (e) {
      print('加载最新记录失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 格式化日期显示
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('格式化日期失败: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // 监听滚动到顶部时刷新数据
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels <= 0) {
            _loadLatestRecords();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _loadLatestRecords,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ====== 顶部最新记录卡片 ======
              const SizedBox(height: 4),
              Text(
                '最新动态',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? _buildLoadingCards(colorScheme)
                  : _buildLatestRecordCards(colorScheme),

              const SizedBox(height: 24),

              // ====== 下方功能模块网格 ======
              Text(
                '更多功能',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: _gridFeatures.length,
                itemBuilder: (context, index) {
                  final feature = _gridFeatures[index];
                  return _LifeFeatureCard(
                    icon: feature.icon,
                    title: feature.title,
                    subtitle: feature.subtitle,
                    color: feature.color,
                    onTap: () => feature.onTap(context),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 加载中的占位卡片
  Widget _buildLoadingCards(ColorScheme colorScheme) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          _buildShimmerCard(colorScheme.primaryContainer),
          const SizedBox(width: 10),
          _buildShimmerCard(colorScheme.tertiaryContainer),
        ],
      ),
    );
  }

  /// 单个 shimmer 占位卡片
  Widget _buildShimmerCard(Color baseColor) {
    return Expanded(
      child: Card(
        color: baseColor.withOpacity(0.3),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: baseColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 60,
                height: 10,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 最新记录卡片行
  Widget _buildLatestRecordCards(ColorScheme colorScheme) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: _LatestRecordCard(
              icon: Icons.account_balance_wallet,
              title: '记账',
              backgroundColor: colorScheme.primaryContainer,
              summary: _latestExpense != null
                  ? () {
                      final categoryCode = _latestExpense!['category'] as String? ?? '';
                      final categoryLabel = categoryCode.isNotEmpty
                          ? DictService.instance.getLabelOrDefault('expense_category', categoryCode, defaultValue: categoryCode)
                          : '';
                      return '$categoryLabel ${_latestExpense!['amount'] ?? ''}';
                    }()
                  : null,
              description: _latestExpense?['note'] as String?,
              date: _formatDate(_latestExpense?['created_at'] as String?),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _LatestRecordCard(
              icon: Icons.monitor_weight,
              title: '体重',
              backgroundColor: colorScheme.tertiaryContainer,
              summary: _latestWeight != null
                  ? '${_latestWeight!['weight']} kg'
                  : null,
              description: null,
              date: _formatDate(_latestWeight?['created_at'] as String?),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeightRecordScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 下方网格功能列表（笔记、日记、收藏、提醒、习惯）
  List<_FeatureItem> get _gridFeatures => [
        _FeatureItem(
          icon: Icons.note,
          title: '笔记',
          subtitle: '记录想法和灵感',
          color: Theme.of(context).colorScheme.primaryContainer,
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteListScreen()),
            );
          },
        ),
        _FeatureItem(
          icon: Icons.mood,
          title: '日记',
          subtitle: '记录心情点滴',
          color: Theme.of(context).colorScheme.secondaryContainer,
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoodDiaryScreen()),
            );
          },
        ),
        _FeatureItem(
          icon: Icons.bookmark,
          title: '我的收藏',
          subtitle: '管理收藏链接',
          color: Theme.of(context).colorScheme.tertiaryContainer,
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            );
          },
        ),
        _FeatureItem(
          icon: Icons.notifications_active,
          title: '提醒事项',
          subtitle: '日程和待办',
          color: Theme.of(context).colorScheme.errorContainer,
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            );
          },
        ),
        _FeatureItem(
          icon: Icons.track_changes,
          title: '习惯打卡',
          subtitle: '培养好习惯',
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitsScreen()),
            );
          },
        ),

        _FeatureItem(
          icon: Icons.cake,
          title: '生日',
          subtitle: '记录亲友生日',
          color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.7),
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnniversariesScreen(filterType: 'birthday')),
            );
          },
        ),
        _FeatureItem(
          icon: Icons.celebration,
          title: '纪念日',
          subtitle: '记录重要日子',
          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.7),
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnniversariesScreen(filterType: 'anniversary')),
            );
          },
        ),
      ];
}

/// 最新记录卡片组件
class _LatestRecordCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color backgroundColor;
  final String? summary;
  final String? description;
  final String? date;
  final VoidCallback onTap;

  const _LatestRecordCard({
    required this.icon,
    required this.title,
    required this.backgroundColor,
    this.summary,
    this.description,
    this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: backgroundColor,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：图标 + 模块名
              Row(
                children: [
                  Icon(icon, size: 20, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              // 摘要信息
              if (summary != null)
                Text(
                  summary!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  '暂无记录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                ),
              // 描述（如有）
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // 时间
              if (date != null && date!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  date!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 功能项数据类
class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Function(BuildContext) onTap;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

/// 功能入口卡片
class _LifeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LifeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
