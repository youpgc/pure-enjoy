import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

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
    // 个性化配置接入（2026-10-10）：圆角跟随 UI 风格 token（简约扁平 8 /
    // 锐利极简 4 / 胶囊现代 18…），投影与边框跟随全局「开启阴影/显示边框」
    // 开关，暗色模式下渐变整体压暗。
    // 胶囊 50% 适配仅作用于大厅卡（2026-10-10 用户拍板：全局 token 已撤销）：
    // 胶囊现代风格下，88px 高的全宽卡端头圆角 = 44（短边一半，长卡变胶囊）
    final uiStyle = AppTheme.uiStyleOf(context);
    final tokenRadius = UiStyleToken.of(uiStyle).cardRadius;
    final isPill = uiStyle == UiStyle.pillModern;
    final radius = BorderRadius.circular(isPill ? 44.0 : tokenRadius);
    final elevation = AppTheme.cardElevation(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? _colors
            .map((c) => Color.lerp(c, const Color(0xFF10131F), 0.35)!)
            .toList()
        : _colors;
    final hpad = isPill ? 14.0 : 14.0 + (tokenRadius - 8).clamp(0.0, 12.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          // 固定高度 88（2026-10-10 调整）：避免「外层渐变容器 + 内层背景
          // 图层」两层高度不一致；装饰/遮罩 Positioned.fill 独占全卡
          height: 88,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            border: Border.fromBorderSide(
                AppTheme.cardBorderSide(context, colors.first)),
            boxShadow: elevation > 0
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppTheme.cardShadowColor(colors.first),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: <Widget>[
                // 氛围装饰层：散布元素整体倾斜 + 降透明度（俏皮、退后做底），
                // 资产缺失时 errorBuilder 渲染空，渐变兜底
                Positioned.fill(
                  child: Transform.rotate(
                    angle: -0.06,
                    child: Opacity(
                      opacity: 0.55,
                      child: SvgPicture.asset(
                        'assets/games/backgrounds/${game.code}.svg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                // 暗角遮罩：左侧深、右侧浅，保证文字对比度
                Positioned.fill(
                  child: DecoratedBox(
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
                ),
                // 前景（2026-10-10 二稿）：左侧图标+名称；右侧「奖杯墙」——
                // 大号立体奖杯（有成绩金色/无成绩置灰）+ 最佳成绩小字；
                // 描述行与播放按钮移除（整卡可点）。
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hpad),
                  child: SizedBox.expand(
                    child: Row(
                    children: <Widget>[
                      // 游戏图标（白底圆角卡，突出主体；胶囊下 50% 变圆）
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          // 联动风格圆角：胶囊风格下 64 正方图标卡变圆
                          borderRadius: BorderRadius.circular(
                              UiStyleToken.of(AppTheme.uiStyleOf(context))
                                          .cardRadius >=
                                      999
                                  ? 999
                                  : 16),
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
                      const SizedBox(width: 14),
                      // 名称（垂直居中，描述行移除）
                      Expanded(
                        child: Text(
                          game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                      // 最佳成绩（文字在奖杯左侧）+ 大号奖杯；无成绩不展示
                      if (best != null) ...<Widget>[
                        const SizedBox(width: 10),
                        Text(
                          '最佳 ${fmtBest ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD54F),
                            shadows: <Shadow>[
                              Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          'assets/games/backgrounds/trophy_gold.svg',
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.emoji_events,
                              size: 44,
                              color: Color(0xFFFFD54F)),
                        ),
                      ],
                    ],
                  ),
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
