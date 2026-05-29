import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../config.dart';
import '../../../services/supabase_service.dart';
import 'expense_list_screen.dart';
import 'mood_diary_screen.dart';
import 'note_list_screen.dart';
import 'weight_record_screen.dart';
import 'favorites_screen.dart';
import 'reminders_screen.dart';
import 'habits_screen.dart';
import 'statistics_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLatestRecords();
  }

  /// 从 Supabase 加载各模块最新记录
  Future<void> _loadLatestRecords() async {
    final userId = AuthService.instance.currentUserId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final headers = {
      'apikey': AppConfig.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
    };

    try {
      // 并行请求两个模块的最新记录
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/expenses?user_id=eq.$userId&select=*&order=date.desc&limit=1',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/weight_records?user_id=eq.$userId&select=*&order=date.desc&limit=1',
          ),
          headers: headers,
        ),
      ]);

      if (!mounted) return;

      final expenseList = jsonDecode(results[0].body) as List;
      final weightList = jsonDecode(results[1].body) as List;

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
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final recordDate = DateTime(date.year, date.month, date.day);
      final diff = today.difference(recordDate).inDays;

      if (diff == 0) {
        return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff == 1) {
        return '昨天';
      } else if (diff < 7) {
        return '$diff天前';
      } else {
        return '${date.month}/${date.day}';
      }
    } catch (_) {
      return '';
    }
  }

  /// 心情 emoji 映射
  String _moodEmoji(String? mood) {
    switch (mood) {
      case 'happy':
        return '\u{1F60A}';
      case 'sad':
        return '\u{1F622}';
      case 'angry':
        return '\u{1F621}';
      case 'anxious':
        return '\u{1F630}';
      case 'calm':
        return '\u{1F60C}';
      case 'excited':
        return '\u{1F929}';
      case 'tired':
        return '\u{1F634}';
      default:
        return '\u{1F60A}';
    }
  }

  /// 心情文字映射
  String _moodText(String? mood) {
    switch (mood) {
      case 'happy':
        return '开心';
      case 'sad':
        return '难过';
      case 'angry':
        return '生气';
      case 'anxious':
        return '焦虑';
      case 'calm':
        return '平静';
      case 'excited':
        return '兴奋';
      case 'tired':
        return '疲惫';
      default:
        return '开心';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
      ),
      body: ListView(
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
                  ? '${_latestExpense!['category'] ?? ''} ${_latestExpense!['amount'] ?? ''}'
                  : null,
              description: _latestExpense?['note'] as String?,
              date: _formatDate(_latestExpense?['date'] as String?),
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
              date: _formatDate(_latestWeight?['date'] as String?),
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
          icon: Icons.bar_chart,
          title: '数据统计',
          subtitle: '消费/体重/心情图表',
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          onTap: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
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
