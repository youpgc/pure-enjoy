import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/game_achievement_model.dart';
import '../services/achievement_service.dart';
import '../shared/achievement_icon.dart';
import '../shared/game_local_loading.dart';

/// 我的成就页
///
/// 展示当前用户已获得的成就（按类目合并为最高级别），网格呈现
/// 「图标 + 主名 + 档位徽标」紧凑结构（名称拆分见 [_splitAchievementName]）；
/// 点击某项弹窗展示大图标、名称、达成条件与获取时间（北京时区）。
/// 同类全部档位（含未获取）可通过底部左右按钮切换浏览，未获取档位置灰展示。
class AchievementListScreen extends StatefulWidget {
  /// {@macro achievement_list_screen}
  const AchievementListScreen({super.key});

  @override
  State<AchievementListScreen> createState() => _AchievementListScreenState();
}

/// 成就名称拆分（纯展示口径，不改数据）。
///
/// 名称约定以 `·` 分隔、末段为档位值：`糖块富豪·8000`、`消消乐·混合模式·钻石段位`。
/// 卡片空间有限，展示「主名 + 档位徽标」两行结构，避免整名换行/截断：
/// - 末段 → 档位徽标（关键数值/段位，用户最关心的达成信息）；
/// - 首段为游戏名且段数 ≥3 时去掉游戏前缀（消消乐·混合模式·钻石段位 → 混合模式）；
/// - 无 `·` 的名称（火眼金睛）整名作主名、无徽标。
/// 后台若配置了不合约定的名称，仅退化为整名展示，不影响数据与判定。
({String base, String? tier}) _splitAchievementName(String name) {
  final segments = name.split('·');
  if (segments.length < 2) return (base: name, tier: null);
  var base = segments.sublist(0, segments.length - 1).join('·');
  const gamePrefixes = <String>{'消消乐', '羊了个羊', '2048'};
  if (segments.length >= 3 && gamePrefixes.contains(segments.first)) {
    base = segments.sublist(1, segments.length - 1).join('·');
  }
  return (base: base, tier: segments.last);
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
                  // mainAxisExtent 固定行高：内容高度可预期
                  // （图标 48 + 主名 1 行 + 档位徽标），不随屏宽反推，
                  // 杜绝真机小屏出现 RenderFlex 溢出（旧版 aspect 0.82 + 2 行
                  // 名称在 360dp 宽度即已溢出，正是真机样式错乱的根因）。
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 124,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final group = _items[i];
                    final view = group.highest; // 网格仅展示最高等级
                    final parts = _splitAchievementName(view.achievement.name);
                    final cs = Theme.of(context).colorScheme;
                    return Card(
                      child: InkWell(
                        onTap: () => _showDetail(group),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              AchievementIcon(view.achievement.icon, size: 48),
                              const SizedBox(height: 8),
                              // 主名单行省略：档位信息由徽标承载，不靠换行硬撑
                              Text(
                                parts.base,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (parts.tier != null) ...<Widget>[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  // 超长档位值缩字号展示而非截断
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      parts.tier!,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: cs.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
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
/// 纵向布局、档位切换条移至底部：内容区占满弹窗宽度——旧版左右箭头挤占
/// 两侧导致名称/描述可用宽度仅 ~136dp，是真机上名称与语义换行难看的根因。
/// 名称按 [_splitAchievementName] 拆为「主名 + 档位徽标」，折行只发生在
/// 结构边界；达成条件（DB description）自然换行、不再截断。
/// 整卡 maxHeight 75% + 可滚动，小屏真机内容超高一律滚动兜底。
/// 浏览该类目全部档位（含未获取，配置快照补全）：已获取展示图标 + 名称 +
/// 达成条件 + 获取时间；未获取档位图标置灰、标注「未获取」。
/// v2 结算只解锁最高档（每类目常仅 1 条已获取记录），切换必须基于
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
    final cs = theme.colorScheme;
    final tiers = _tiers;
    final achievement = tiers[_index];
    final unlockedAt = _unlockedAt[achievement.id];
    final showArrows = tiers.length > 1;
    final canPrev = _index > 0;
    final canNext = _index < tiers.length - 1;
    final parts = _splitAchievementName(achievement.name);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        // 小屏真机兜底：内容超高时整卡滚动，杜绝 RenderFlex 溢出
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 未获取档位图标置灰。
              Opacity(
                opacity: unlockedAt != null ? 1 : 0.35,
                child: AchievementIcon(achievement.icon, size: 96),
              ),
              const SizedBox(height: 16),
              // 主名 + 档位：**上下两行、水平居中**（2026-09-15 按需求调整）。
              // 此前用 Wrap 同行排布，「连锁大师」与「5连锁」挤在一行；
              // 档位本质是名称的语义后缀（·5连锁 / ·王者段位），单独成行更易读。
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    parts.base,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (parts.tier != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        parts.tier!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 达成条件（DB description，与真实判定口径一致），自然换行不截断
              if (achievement.description != null &&
                  achievement.description!.isNotEmpty)
                Text(
                  achievement.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              // 已获取：获取时间（仅时间，不带前缀）；未获取：标注。
              Text(
                unlockedAt != null ? formatBeijing(unlockedAt) : '未获取',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: unlockedAt != null
                      ? cs.onSurfaceVariant
                      : cs.secondary,
                  fontWeight: unlockedAt != null ? null : FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (showArrows) ...<Widget>[
                const SizedBox(height: 20),
                // 档位切换条移至底部：内容区不再被左右箭头挤占
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _arrow(canPrev, Icons.chevron_left, () => _step(-1)),
                    Text(
                      '${_index + 1}/${tiers.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    _arrow(canNext, Icons.chevron_right, () => _step(1)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
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
