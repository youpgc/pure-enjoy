import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/game_achievement_model.dart';
import '../services/achievement_service.dart';
import '../shared/achievement_icon.dart';
import '../shared/game_local_loading.dart';

/// 我的成就页
///
/// 展示当前用户已获得的成就（按类目合并为最高级别），网格呈现图标 + 名称；
/// 点击某项弹窗展示大图标、成就名称、达成条件与获取时间（北京时区）。
/// 同类全部档位（含未获取）可通过左右按钮切换浏览，未获取档位置灰展示。
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
      // 网格区局部 loading（规范：禁止整页 loading）
      body: _loading
          ? ListView(children: const <Widget>[GameLocalLoading(label: '成就加载中…')])
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
                              AchievementIcon(view.achievement.icon, size: 64),
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
/// 浏览该类目全部档位（含未获取，配置快照补全）：已获取展示图标 + 名称 +
/// 达成条件（DB description）+ 获取时间；未获取档位图标置灰、标注「未获取」。
/// v2 结算只解锁最高档（每类目常仅 1 条已获取记录），左右切换必须基于
/// 全档位列表而非已获取集合，否则按钮结构性消失。
class _AchievementDetailDialog extends StatefulWidget {
  final AchievementGroupView group;
  const _AchievementDetailDialog({required this.group});

  @override
  State<_AchievementDetailDialog> createState() =>
      _AchievementDetailDialogState();
}

class _AchievementDetailDialogState extends State<_AchievementDetailDialog> {
  late int _index;

  /// 全档位列表（配置缺失时兜底退回已获取集合）。
  List<GameAchievementModel> get _tiers => widget.group.tiers.isNotEmpty
      ? widget.group.tiers
      : widget.group.obtained.map((o) => o.achievement).toList();

  /// 已获取档位的解锁时间（achievement_id → 时间）。
  Map<String, DateTime> get _unlockedAt => <String, DateTime>{
        for (final o in widget.group.obtained) o.achievement.id: o.unlockedAt,
      };

  @override
  void initState() {
    super.initState();
    // 默认展示最高已获取档；无匹配（兜底）取末位。
    final unlocked = _unlockedAt;
    var index = _tiers.length - 1;
    for (var i = _tiers.length - 1; i >= 0; i--) {
      if (unlocked.containsKey(_tiers[i].id)) {
        index = i;
        break;
      }
    }
    _index = index;
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next >= 0 && next < _tiers.length) {
      setState(() => _index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiers = _tiers;
    final achievement = tiers[_index];
    final unlockedAt = _unlockedAt[achievement.id];
    final showArrows = tiers.length > 1;
    final canPrev = _index > 0;
    final canNext = _index < tiers.length - 1;

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
                      // 未获取档位图标置灰。
                      Opacity(
                        opacity: unlockedAt != null ? 1 : 0.35,
                        child: AchievementIcon(achievement.icon, size: 96),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        achievement.name,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // 达成条件（DB description，与真实判定口径一致）。
                      if (achievement.description != null &&
                          achievement.description!.isNotEmpty)
                        Text(
                          achievement.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 10),
                      // 已获取：获取时间（仅时间，不带前缀）；未获取：标注。
                      Text(
                        unlockedAt != null
                            ? formatBeijing(unlockedAt)
                            : '未获取',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unlockedAt != null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.secondary,
                          fontWeight: unlockedAt != null
                              ? null
                              : FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
