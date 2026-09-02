import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/achievement_service.dart';

/// 成就图标资源路径（App 端按 code 派生，不依赖 game_achievements.icon 旧名）。
String _achAssetPath(String code) => 'assets/games/achievements/ach_$code.svg';

/// 我的成就页
///
/// 展示当前用户已获得的成就（按类目合并为最高级别），网格呈现图标 + 名称；
/// 点击某项弹窗展示大图标、成就名称与获取时间（北京时区，YYYY-MM-DD HH:mm:ss）。
/// 同类（重复类型）已获取的不同等级可通过左右按钮切换查看。
class AchievementListScreen extends StatefulWidget {
  /// {@macro achievement_list_screen}
  const AchievementListScreen({super.key});

  @override
  State<AchievementListScreen> createState() => _AchievementListScreenState();
}

class _AchievementListScreenState extends State<AchievementListScreen> {
  List<AchievementGroupView> _items = const <AchievementGroupView>[];
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

  void _showDetail(AchievementGroupView group) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _AchievementDetailDialog(group: group),
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
                    final group = _items[i];
                    final view = group.highest; // 网格仅展示最高等级
                    return Card(
                      child: InkWell(
                        onTap: () => _showDetail(group),
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
                                _achAssetPath(view.achievement.code),
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

/// 成就详情弹窗（透明背景）。
///
/// 同类（重复类型）已获取的多个等级可通过左右按钮切换；仅展示已获取成就，
/// 未获取等级不展示（预留分支见下方注释）。底部按钮居中、文案「关闭」。
class _AchievementDetailDialog extends StatefulWidget {
  final AchievementGroupView group;
  const _AchievementDetailDialog({required this.group});

  @override
  State<_AchievementDetailDialog> createState() =>
      _AchievementDetailDialogState();
}

class _AchievementDetailDialogState extends State<_AchievementDetailDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    // 默认展示最高等级（列表末尾）。
    _index = widget.group.obtained.length - 1;
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next >= 0 && next < widget.group.obtained.length) {
      setState(() => _index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtained = widget.group.obtained;
    final view = obtained[_index];
    final showArrows = obtained.length > 1;
    final canPrev = _index > 0;
    final canNext = _index < obtained.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                showArrows
                    ? _arrow(canPrev, Icons.chevron_left, () => _step(-1))
                    : const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SvgPicture.asset(
                        _achAssetPath(view.achievement.code),
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
                      // 仅展示获取时间（文案仅时间，不带「获取时间：」前缀）。
                      Text(
                        formatBeijing(view.unlockedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // 预留：未获取等级的展示分支（文案「未获取」）。
                      // 当前仅展示已获取成就（obtained），故此分支不触发：
                      // if (!obtained) ... const Text('未获取')
                    ],
                  ),
                ),
                showArrows
                    ? _arrow(canNext, Icons.chevron_right, () => _step(1))
                    : const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrow(bool enabled, IconData icon, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.25),
      splashRadius: 20,
    );
  }
}
