import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/achievement_service.dart';

/// 我的成就页
///
/// 展示当前用户已获得的成就（按类目合并为最高级别），网格呈现图标 + 名称；
/// 点击某项弹窗展示大图标、成就名称与获取时间（北京时区）。
class AchievementListScreen extends StatefulWidget {
  /// {@macro achievement_list_screen}
  const AchievementListScreen({super.key});

  @override
  State<AchievementListScreen> createState() => _AchievementListScreenState();
}

class _AchievementListScreenState extends State<AchievementListScreen> {
  List<UserAchievementView> _items = const <UserAchievementView>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await AchievementService.instance.fetchUserAchievements();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (kDebugMode) debugPrint('[AchievementListScreen] 加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _assetPath(String code) =>
      'assets/games/achievements/ach_$code.svg';

  void _showDetail(UserAchievementView view) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.asset(
              _assetPath(view.achievement.code),
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 16),
            Text(
              view.achievement.name,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '获取时间：${formatBeijing(view.unlockedAt)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('我的成就')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty(colorScheme)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final view = _items[i];
                    return Card(
                      child: InkWell(
                        onTap: () => _showDetail(view),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SvgPicture.asset(
                                _assetPath(view.achievement.code),
                                width: 64,
                                height: 64,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                view.achievement.name,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有获得成就',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '去游戏里挑战，解锁你的第一个成就吧',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
