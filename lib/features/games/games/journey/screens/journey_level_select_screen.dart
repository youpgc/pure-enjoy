import 'package:flutter/material.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../widgets/journey_load_error.dart';
import 'journey_battle_screen.dart';

/// S3 关卡选择页（八十一难，主线西行专用）。
///
/// 无尽妖潮/每日游历已拆分为 hub 独立入口（游历地图选择见
/// JourneyDailyScreen），本页只展示主线西行列表：按区域折叠面板
/// （自绘 header：主题色条+区域名+「已清 X/Y 难」+展开箭头；初始展开
/// 当前进行中关卡所在区域并滚动定位）。主线解锁口径：关卡号 ≤ 最远
/// 关卡+1（顺序推进制），已通关可重复挑战；挑战进入对局。
class JourneyLevelSelectScreen extends StatefulWidget {
  const JourneyLevelSelectScreen({super.key});

  @override
  State<JourneyLevelSelectScreen> createState() =>
      _JourneyLevelSelectScreenState();
}

class _JourneyLevelSelectScreenState extends State<JourneyLevelSelectScreen> {
  JourneyConfigSnapshot? _config;
  JourneyProgressModel _progress = const JourneyProgressModel();

  /// 挑战页入栈中：连点只打开一个对局。
  bool _navigating = false;

  /// 已展开的区域编码集合（折叠面板状态）。
  final Set<String> _expanded = <String>{};

  /// 区域 header 定位键（Scrollable.ensureVisible 滚动到当前关区域）。
  final Map<String, GlobalKey> _regionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 加载失败标记：异常时由错误态接管，避免永久停在 loading。
  bool _loadFailed = false;

  Future<void> _load() async {
    try {
      final progress = JourneyProgressService.instance;
      await Future.wait<void>(<Future<void>>[
        JourneyConfigService.instance.ensure(JourneyConfigScope.levelSelect),
        progress.ensureLoaded(),
      ]);
      if (!mounted) return;
      setState(() {
        _config = JourneyConfigService.instance.cached;
        _progress = progress.state;
        _loadFailed = false;
      });
      _prepareExpansion();
    } catch (e, st) {
      reportJourneyLoadError(e, st);
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _retry() {
    setState(() => _loadFailed = false);
    _load();
  }

  /// 初始展开：当前进行中关卡（最远+1）所在区域，其余折叠；
  /// 全通关（最远≥最大关号）展开最后一个区域；postFrame 滚动定位。
  void _prepareExpansion() {
    final config = _config;
    if (config == null || config.regions.isEmpty) return;
    final levels = config.levels.toList()
      ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
    final farthest = _progress.farthestLevelNo;
    final upcoming = levels.where((l) => l.levelNo > farthest).toList();
    // 进行中=首个未通关难；全部清完=最后一难（前期 20 难封顶口径）
    final target = upcoming.isNotEmpty
        ? upcoming.first
        : (levels.isNotEmpty ? levels.last : null);
    var code = target?.regionCode ?? '';
    if (!config.regions.any((r) => r.code == code)) {
      code = config.regions.last.code;
    }
    _expanded
      ..clear()
      ..add(code);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _regionKeys[code]?.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return JourneyPageScaffold(
        title: '八十一难',
        body: JourneyLoadError(onRetry: _retry),
      );
    }
    final config = _config;
    if (config == null) {
      return const JourneyPageScaffold(
        title: '八十一难',
        body: Center(
          child: JourneyLoading(label: '西行中…'),
        ),
      );
    }
    return JourneyPageScaffold(
      title: '西行启程',
      body: _mainList(config),
    );
  }

  // ---- 主线：区域折叠面板 ----

  Widget _mainList(JourneyConfigSnapshot config) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: config.regions.length,
      itemBuilder: (ctx, i) {
        final region = config.regions[i];
        final levels = config.levelsOfRegion(region.code);
        final expanded = _expanded.contains(region.code);
        final cleared = levels
            .where((l) => l.levelNo <= _progress.farthestLevelNo)
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _regionHeader(region, levels.length, cleared, expanded),
            if (expanded) ...levels.map(_buildLevelCard),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  /// 区域折叠 header：主题色条 + 区域名 + 「已清 X/Y 难」+ 展开箭头。
  Widget _regionHeader(
    JourneyRegionModel region,
    int total,
    int cleared,
    bool expanded,
  ) {
    final key = _regionKeys.putIfAbsent(region.code, GlobalKey.new);
    final color = _regionColor(region);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
          onTap: () => setState(() {
            expanded ? _expanded.remove(region.code) : _expanded.add(region.code);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: JourneyTheme.panel,
              borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
              border: Border.all(
                color: expanded ? color : JourneyTheme.panelStroke,
                width: 1.2,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(region.name, style: JourneyTheme.title),
                const SizedBox(width: 8),
                Text('已清 $cleared/$total 难', style: JourneyTheme.faint),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    color: JourneyTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _regionColor(JourneyRegionModel region) {
    final hex = region.themeColor.replaceAll('#', '');
    if (hex.length != 7) return JourneyTheme.gold;
    return Color(int.parse('FF$hex', radix: 16));
  }

  Widget _buildLevelCard(JourneyLevelModel level) {
    final farthest = _progress.farthestLevelNo;
    final cleared = level.levelNo <= farthest;
    final unlocked = level.levelNo <= farthest + 1;
    final kindLabel = switch (level.kind) {
      'story' => '叙事',
      'boss' => '妖王${level.bossFights > 1 ? ' ×${level.bossFights}' : ''}',
      'trial' => '试炼',
      'node' => '节点',
      _ => '战斗',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: JourneyCard(
        locked: !unlocked,
        onTap: unlocked ? () => _challenge(level) : null,
        child: Row(
          children: <Widget>[
            // 关号徽标
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cleared
                    ? JourneyTheme.gold.withValues(alpha: 0.18)
                    : JourneyTheme.panelRaised,
                shape: BoxShape.circle,
                border: Border.all(
                  color: cleared ? JourneyTheme.gold : JourneyTheme.panelStroke,
                ),
              ),
              child: cleared
                  ? const Icon(Icons.check,
                      color: JourneyTheme.gold, size: 20)
                  : Text(
                      '${level.levelNo}',
                      style: JourneyTheme.title.copyWith(
                        color: unlocked
                            ? JourneyTheme.textPrimary
                            : JourneyTheme.textFaint,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 关卡统一映射展示：第 N 难 · 关卡名称
                  Text('第 ${level.levelNo} 难 · ${level.title}',
                      style: JourneyTheme.title),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? '第 ${level.levelNo} 难 · $kindLabel'
                        : '通关前置难关后解锁',
                    style: unlocked ? JourneyTheme.caption : JourneyTheme.faint,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 挑战按钮留出与卡片内容、卡片边缘的间距
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: unlocked
                  ? JourneyButton(
                      text: cleared ? '重挑战' : '挑战',
                      secondary: cleared,
                      onTap: () => _challenge(level),
                    )
                  : null,
            ),
            if (!unlocked)
              const Icon(Icons.lock, color: JourneyTheme.locked, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _challenge(JourneyLevelModel level) async {
    if (_navigating || !mounted) return;
    _navigating = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JourneyBattleScreen(level: level),
        ),
      );
    } finally {
      _navigating = false;
    }
  }
}
