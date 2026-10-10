import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import './game_total_dashboard.dart';
import '../game_home_screen.dart';
import '../shared/duration_format.dart';
import '../shared/game_local_loading.dart';
import '../game_play_helpers.dart';
import '../models/game_model.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';

/// 游戏大厅：展示全部启用游戏入口，右上角可查看全部游戏最佳成绩看板。
class GameHallPage extends StatefulWidget {
  const GameHallPage({super.key});

  @override
  State<GameHallPage> createState() => _GameHallPageState();
}

class _GameHallPageState extends State<GameHallPage> {
  /// 大厅展示的游戏（已按 test_only + 资源匹配过滤）
  List<GameModel> _games = <GameModel>[];
  List<GameBestScore> _best = <GameBestScore>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 测试游戏过滤（2026-09-10）：test_only=true 且本包**没有**匹配到该游戏
  /// 的图标资源 → 隐藏（生产包）；资源能匹配 = 测试/开发包 → 展示。
  Future<List<GameModel>> _filterVisibleGames(List<GameModel> all) async {
    final out = <GameModel>[];
    for (final g in all) {
      if (!g.testOnly || await hasBundledGameAsset(g.icon)) out.add(g);
    }
    return out;
  }

  /// SWR 加载（2026-09-07）：缓存命中立即展示（不等网络），随后静默请求
  /// 更新缓存与展示；[refresh]（下拉刷新）时配置强拉并让 Future 供指示器等待。
  ///
  /// 静默失败保留已展示的旧数据（空快照不覆盖非空缓存）。
  Future<void> _load({bool refresh = false}) async {
    // 1) 缓存先行：仅当页面尚无数据（未命中）时读持久缓存，命中即渲染
    if (_games.isEmpty && _best.isEmpty) {
      final cachedConfig = await GameService.instance.loadCachedConfig();
      final cachedBest = await GameScoreService.instance.loadCachedBestScores();
      if (cachedConfig != null || cachedBest.isNotEmpty) {
        final games = cachedConfig != null
            ? await _filterVisibleGames(cachedConfig.games)
            : <GameModel>[];
        if (mounted) {
          setState(() {
            if (cachedConfig != null) _games = games;
            if (cachedBest.isNotEmpty) _best = cachedBest;
            _loading = false;
          });
        }
      }
    }

    // 2) 静默请求 / 下拉强拉：成功后更新缓存（service 内部已回写）与展示
    final config = await GameService.instance.fetchConfig(force: refresh);
    final best = await GameScoreService.instance.fetchBestScores();
    final games = await _filterVisibleGames(config.games);
    if (!mounted) return;
    // 静默失败（空快照）不覆盖已展示的非空缓存，避免刷新把页面打空
    setState(() {
      if (games.isNotEmpty || _games.isEmpty) _games = games;
      if (best.isNotEmpty || _best.isEmpty) _best = best;
      _loading = false;
    });
  }

  GameBestScore? _primaryBest(String gameId) {
    for (final b in _best) {
      if (b.gameId == gameId && b.isPrimary) return b;
    }
    return null;
  }

  String _fmtBest(GameBestScore b) {
    if (b.isDuration) {
      // 进阶时间单位（2026-09-11）：秒→分秒→时分秒→天，双端同口径
      return formatDurationSmart(b.bestValue);
    }
    return '${b.bestValue.toInt()}${b.unit ?? ''}';
  }

  /// 点击游戏入口：统一进入该游戏的「主界面」([GameHomeScreen])。
  /// 主界面内再决定「开始游戏 / 选关 / 查看说明 / 查看记录」，
  /// 选关逻辑已抽到 [GameLevelPicker]，按 [GameModel.levelSelectMode] 决定锁状态。
  /// 返回后刷新（对局可能产生新成绩 → 最佳记录需更新）。
  Future<void> _openGame(GameModel game) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameHomeScreen(game: game)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;

    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: '全部最佳成绩',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GameTotalDashboard(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: games.isEmpty
                  ? (_loading
                      // 局部 loading（规范：禁止整页 loading）
                      ? const GameLocalLoading(label: '游戏加载中…')
                      : const Center(child: Text('暂无可用游戏')))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: games.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final game = games[i];
                        final best = _primaryBest(game.id);
                        return _GameBannerCard(
                          game: game,
                          best: best,
                          fmtBest: best == null ? null : _fmtBest(best),
                          onTap: () => _openGame(game),
                        );
                      },
                    ),
            ),
    );
  }
}

/// 游戏入口横幅卡（2026-10-10 大厅改版：一行一游戏、氛围化设计）。
/// 结构：游戏专属渐变底 + 氛围装饰 SVG（透明底散布元素，缺失时纯渐变兜底）
/// + 暗角遮罩保文字可读 + 前景（大图标 / 名称与简介 / 最佳成绩胶囊 / 开玩钮）。
class _GameBannerCard extends StatelessWidget {
  final GameModel game;
  final GameBestScore? best;
  final String? fmtBest;
  final VoidCallback onTap;

  const _GameBannerCard({
    required this.game,
    required this.best,
    required this.fmtBest,
    required this.onTap,
  });

  /// 游戏专属氛围渐变（未知游戏回落通用蓝紫）
  static const Map<String, List<Color>> _gradients = <String, List<Color>>{
    'match3': <Color>[Color(0xFFEC407A), Color(0xFF6A1B9A)],
    'sheep': <Color>[Color(0xFF26A69A), Color(0xFF004D40)],
    'g2048': <Color>[Color(0xFFFF7043), Color(0xFF8D2A0C)],
    'tetris': <Color>[Color(0xFF3F51B5), Color(0xFF101331)],
  };

  List<Color> get _colors =>
      _gradients[game.code] ?? const <Color>[Color(0xFF5C6BC0), Color(0xFF283593)];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _colors,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _colors.last.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // 氛围装饰层：散布元素（资产缺失时 errorBuilder 渲染空，渐变兜底）
                SvgPicture.asset(
                  'assets/games/backgrounds/${game.code}.svg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                // 暗角遮罩：左侧深、右侧浅，保证文字对比度
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.34),
                        Colors.black.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
                // 前景
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: <Widget>[
                      // 游戏图标（白底圆角卡，突出主体）
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(7),
                        child: SvgPicture.asset(
                          gameCoverAsset(game.icon),
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.sports_esports, size: 40),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 名称 + 简介 + 成绩
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              game.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: <Shadow>[
                                  Shadow(
                                      color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              best == null
                                  ? '尚未挑战 · 点击开玩'
                                  : '${best!.dimensionName} · ${fmtBest ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // 最佳成绩胶囊
                            if (best != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(Icons.emoji_events,
                                        size: 13, color: Color(0xFFFFD54F)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '最佳 ${fmtBest ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFFD54F),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 开玩钮
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 30, color: Color(0xFFF2571B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
