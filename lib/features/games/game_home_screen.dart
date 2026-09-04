import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'game_guide.dart';
import 'game_level_picker.dart';
import 'game_play_helpers.dart';
import 'game_play_screen.dart';
import 'game_item_shop_screen.dart';
import 'services/game_item_service.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'models/game_mode_model.dart';
import 'models/match3_mode.dart';
import 'play/game_single_dashboard.dart';
import 'services/game_score_service.dart';
import 'services/game_service.dart';

/// 游戏主界面（大厅点击游戏入口后的落地页）。
///
/// 三游戏统一入口层级（不再按 game.code 分叉）：
/// - 模式网格（玩法模式为主）：展示该游戏在 `game_modes` 表里的所有「有关卡」模式，
///   点模式 → 选关弹窗（按 mode_id 过滤）或直接开合成关（无尽模式）。
/// - 无后台模式时回落旧逻辑：「选择关卡」/「开始游戏」。
/// 模式清单完全来自后台配置，App 端不再硬编码任何模式。
class GameHomeScreen extends StatefulWidget {
  final GameModel game;

  const GameHomeScreen({super.key, required this.game});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  List<GameLevelModel> _levels = <GameLevelModel>[];
  List<GameModeModel> _modes = <GameModeModel>[];
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
        _modes = config.modesOf(widget.game.id);
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

  void _startGame() {
    final lv = _startLevel;
    if (lv == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GamePlayScreen(game: widget.game, level: lv)),
    );
  }

  /// 全关卡选关（无模式时使用）。
  void _openPicker() {
    GameLevelPicker.show(
      context: context,
      game: widget.game,
      levels: _levels,
      clearedIds: _clearedIds,
    );
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
                          SvgPicture.asset(gameCoverAsset(game.icon),
                              width: 44, height: 44),
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

                  const SizedBox(height: 16),

                  // 模式网格（三游戏统一：模式为主，点模式→选关/合成关）
                  // 无尽模式无后台关卡，按 isEndless 特判保留可达，不被「有关卡」过滤剔除。
                  if (_modes.isNotEmpty)
                    _modeGridGeneric(_modes
                        .where((m) =>
                            m.isEndless ||
                            _levels.any((l) => l.modeId == m.id))
                        .toList()),

                  const SizedBox(height: 16),

                  // 入口（无后台模式时回落旧逻辑）
                  if (_modes.isEmpty)
                    if (game.levelSelectable && _levels.length > 1)
                      _EntryTile(
                        icon: Icons.grid_view_rounded,
                        label: '选择关卡',
                        desc: '挑选要挑战的关卡',
                        primary: true,
                        enabled: startable,
                        onTap: () => _openPicker(),
                      )
                    else
                      _EntryTile(
                        icon: Icons.play_arrow_rounded,
                        label: '开始游戏',
                        desc: startable ? '从当前可挑战关卡开始' : '暂无可玩关卡',
                        primary: true,
                        enabled: startable,
                        onTap: _startGame,
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

  /// 统一模式网格（三游戏一致）：模式为主，点模式→选关/合成关。
  Widget _modeGridGeneric(List<GameModeModel> modes) {
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
          itemCount: modes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (_, idx) {
            final mode = modes[idx];
            final cleared = _modeClearedById(mode);
            final total = _levelsOfModeId(mode.id).length;
            final color = modeColorOf(mode.playKind);
            final subtitle = mode.isEndless
                ? '无尽 · 随时挑战'
                : '已通关 $cleared/$total';
            return InkWell(
              onTap: () => _onModeTap(mode),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SvgPicture.asset(modeIconAsset(mode.icon),
                            width: 22, height: 22),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(mode.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.neutral500)),
                          ],
                        ),
                      ),
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

  int _modeClearedById(GameModeModel mode) {
    final ids = _levels.where((l) => l.modeId == mode.id).map((l) => l.id).toSet();
    return _clearedIds.where(ids.contains).length;
  }

  List<GameLevelModel> _levelsOfModeId(String modeId) {
    return _levels.where((l) => l.modeId == modeId).toList()
      ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
  }

  /// 模式点击分流：
  /// - 无尽模式（endless）：无具体关，直接开合成无尽局；
  /// - 其它：打开选关弹窗（按 mode_id 过滤该模式关卡）。
  void _onModeTap(GameModeModel mode) {
    if (mode.isEndless) {
      final lv = GameLevelModel.endless2048(
        gameId: widget.game.id,
        modeId: mode.id,
        size: 4,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(game: widget.game, level: lv),
        ),
      );
      return;
    }
    _openPickerForMode(mode);
  }

  void _openPickerForMode(GameModeModel mode) {
    GameLevelPicker.show(
      context: context,
      game: widget.game,
      levels: _levels,
      clearedIds: _clearedIds,
      mode: mode,
    );
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
