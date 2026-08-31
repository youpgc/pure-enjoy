import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'game_guide.dart';
import 'game_level_picker.dart';
import 'game_play_helpers.dart';
import 'game_play_screen.dart';
import 'game_item_shop_screen.dart';
import 'services/game_item_service.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'models/match3_mode.dart';
import 'play/game_single_dashboard.dart';
import 'services/game_score_service.dart';
import 'services/game_service.dart';

/// 游戏主界面（大厅点击游戏入口后的落地页）。
///
/// 入口层级（避免「模式+开始游戏+选关」堆叠混乱）：
/// - 消消乐（match3）：以「6 模式网格」为**选择模式**入口，点模式**直接进入**该模式
///   首个未通关关卡（全通关回第一关），不再弹窗；底部「选择关卡」用于挑具体关卡。
/// - 有选关能力的其它游戏（[GameModel.levelSelectable] 且 >1 关）：以「选择关卡」
///   代替「开始游戏」，避免重复入口。
/// - 单关卡游戏：保留「开始游戏」直接开局。
class GameHomeScreen extends StatefulWidget {
  final GameModel game;

  const GameHomeScreen({super.key, required this.game});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  List<GameLevelModel> _levels = <GameLevelModel>[];
  Set<String> _clearedIds = const <String>{};
  bool _hasShop = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await GameService.instance.loadCachedConfig();
    if (mounted) {
      setState(() {
        _levels = cached?.levelsOf(widget.game.id) ?? <GameLevelModel>[];
      });
    }
    final config = await GameService.instance.fetchConfig();
    final cleared = await GameScoreService.instance.fetchClearedLevelIds(widget.game.id);
    final items = await GameItemService.instance.fetchItems(gameCode: widget.game.code);
    if (mounted) {
      setState(() {
        _levels = config.levelsOf(widget.game.id);
        _clearedIds = cleared;
        _hasShop = items.isNotEmpty;
        _loading = false;
      });
    }
  }

  /// 开始游戏的目标关卡：gated 取第一个未通关（frontier），全通关取末关；
  /// free / 单关取首关；无配置返回 null。
  GameLevelModel? get _startLevel {
    if (_levels.isEmpty) return null;
    if (widget.game.levelSelectMode != 'gated') return _levels.first;
    for (final lv in _levels) {
      if (!_clearedIds.contains(lv.id)) return lv;
    }
    return _levels.last;
  }

  bool get _canSelectLevel =>
      widget.game.levelSelectable && _levels.length > 1;

  void _startGame() {
    final lv = _startLevel;
    if (lv == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GamePlayScreen(game: widget.game, level: lv)),
    );
  }

  void _openPicker({Match3Mode? initialMode}) {
    GameLevelPicker.show(
      context: context,
      game: widget.game,
      levels: _levels,
      clearedIds: _clearedIds,
      initialMode: initialMode,
    );
  }

  /// 直接进入某模式首个未通关关卡（frontier）；全通关回第一关。
  /// 该模式后台未配关卡时，合成一局「体验关」直接开玩（id 为空、不计首通、
  /// 不计入通关进度），保证点任意模式都有响应，不再静默无反应。
  void _startMode(Match3Mode mode) {
    final list = _levelsOfMode(mode);
    final GameLevelModel lv;
    if (list.isEmpty) {
      lv = GameLevelModel(
        id: '',
        gameId: widget.game.id,
        levelNo: mode.index * 10 + 1,
        name: '${mode.label} · 体验关',
        config: <String, dynamic>{'mode': mode.code},
        countForDailyClear: false,
      );
    } else {
      var maxCleared = -1;
      for (var i = 0; i < list.length; i++) {
        if (_clearedIds.contains(list[i].id)) maxCleared = i;
      }
      lv = list[maxCleared + 1 < list.length ? maxCleared + 1 : 0];
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GamePlayScreen(game: widget.game, level: lv)),
    );
  }

  /// 某模式下的关卡（按 level_no 升序）
  List<GameLevelModel> _levelsOfMode(Match3Mode mode) {
    final list = _levels
        .where((l) => parseMatch3Mode(l.config, l.levelNo) == mode)
        .toList()
      ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
    return list;
  }

  void _showGuide() {
    final guide = gameGuideOf(widget.game);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: <Widget>[
            Text(guide.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (guide.intro != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(guide.intro!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 16),
            ...guide.sections.map((s) => _GuideSectionView(section: s)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameSingleDashboard(game: widget.game)),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameItemShopScreen(game: widget.game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isMatch3 = game.code == 'match3';
    final startable = _startLevel != null;

    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: _loading && _levels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  // 头部：图标 + 名称 + 简介
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: <Widget>[
                          Icon(gameIcon(game.icon),
                              size: 44, color: AppTheme.primaryOrange),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(game.name,
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold)),
                                if (game.description != null) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(game.description!,
                                      style: const TextStyle(
                                          fontSize: 13, color: AppTheme.neutral600)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 消消乐：6 模式网格（模式为主）
                  if (game.code == 'match3') _modeGrid(),

                  const SizedBox(height: 16),

                  // 入口：有选关/模式能力的游戏，优先「选择关卡」；消消乐以模式网格为起点，隐藏「开始游戏」
                  if (!isMatch3 && !_canSelectLevel)
                    _EntryTile(
                      icon: Icons.play_arrow_rounded,
                      label: '开始游戏',
                      desc: startable ? '从当前可挑战关卡开始' : '暂无可玩关卡',
                      primary: true,
                      enabled: startable,
                      onTap: _startGame,
                    ),
                  if (_canSelectLevel)
                    _EntryTile(
                      icon: Icons.list_alt_rounded,
                      label: '选择关卡',
                      desc:
                          isMatch3 ? '按模式与关序挑选具体关卡' : '按关序挑选关卡',
                      primary: !isMatch3,
                      onTap: () => _openPicker(),
                    ),
                  _EntryTile(
                    icon: Icons.menu_book_rounded,
                    label: '查看说明',
                    desc: '玩法与过关技巧',
                    onTap: _showGuide,
                  ),
                  _EntryTile(
                    icon: Icons.bar_chart_rounded,
                    label: '查看游戏记录',
                    desc: '我的成绩与最佳记录',
                    onTap: _openRecords,
                  ),
                  if (_hasShop)
                    _EntryTile(
                      icon: Icons.wallet_giftcard_rounded,
                      label: '道具商城',
                      desc: '积分兑换游戏道具卡',
                      onTap: _openShop,
                    ),
                ],
              ),
            ),
    );
  }

  /// 消消乐模式网格：6 张卡，点选深链到该模式选关
  Widget _modeGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 4, bottom: 8),
          child: Text('玩法模式',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: Match3Mode.values.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (_, idx) {
            final mode = Match3Mode.values[idx];
            final cleared = _modeCleared(mode);
            return InkWell(
              onTap: () => _startMode(mode),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(mode.icon, color: mode.color, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(mode.label,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          mode.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.neutral600),
                        ),
                      ),
                      Text('已通关 $cleared/5',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.neutral500)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  int _modeCleared(Match3Mode mode) {
    final ids = _levels
        .where((l) => parseMatch3Mode(l.config, l.levelNo) == mode)
        .map((l) => l.id)
        .toSet();
    return _clearedIds.where(ids.contains).length;
  }
}

/// 说明弹窗里的一段
class _GuideSectionView extends StatelessWidget {
  final GameGuideSection section;
  const _GuideSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (section.icon != null) ...<Widget>[
                Icon(section.icon, size: 18, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
              ],
              Text(section.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(section.body, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/// 主界面入口行
class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback? onTap;
  final bool primary;
  final bool enabled;

  const _EntryTile({
    required this.icon,
    required this.label,
    required this.desc,
    this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary
                          ? AppTheme.primaryOrange.withAlpha(26)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        color: primary ? AppTheme.primaryOrange : null, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(label,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.neutral600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.neutral500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
