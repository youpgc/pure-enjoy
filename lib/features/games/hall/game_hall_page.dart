import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import './game_total_dashboard.dart';
import '../game_home_screen.dart';
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
  GameConfigSnapshot? _config;
  List<GameBestScore> _best = <GameBestScore>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await GameService.instance.loadCachedConfig();
    if (mounted) setState(() => _config = cached);
    final config = await GameService.instance.fetchConfig();
    final best = await GameScoreService.instance.fetchBestScores();
    if (mounted) {
      setState(() {
        _config = config;
        _best = best;
        _loading = false;
      });
    }
  }

  GameBestScore? _primaryBest(String gameId) {
    for (final b in _best) {
      if (b.gameId == gameId && b.isPrimary) return b;
    }
    return null;
  }

  String _fmtBest(GameBestScore b) {
    if (b.isDuration) {
      final sec = (b.bestValue / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    return '${b.bestValue.toInt()}${b.unit ?? ''}';
  }

  /// 点击游戏入口：统一进入该游戏的「主界面」([GameHomeScreen])。
  /// 主界面内再决定「开始游戏 / 选关 / 查看说明 / 查看记录」，
  /// 选关逻辑已抽到 [GameLevelPicker]，按 [GameModel.levelSelectMode] 决定锁状态。
  Future<void> _openGame(GameModel game) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameHomeScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = _config?.games ?? <GameModel>[];

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
      body: _loading && games.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: games.isEmpty
                  ? const Center(child: Text('暂无可用游戏'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: games.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (ctx, i) {
                        final game = games[i];
                        final best = _primaryBest(game.id);
                        return InkWell(
                          onTap: () => _openGame(game),
                          borderRadius: BorderRadius.circular(16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SvgPicture.asset(gameCoverAsset(game.icon),
                                      width: 48, height: 48),
                                  const SizedBox(height: 12),
                                  Text(game.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  if (best != null)
                                    Column(
                                      children: <Widget>[
                                        Text(best.dimensionName,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.neutral600)),
                                        Text(_fmtBest(best),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.success,
                                            )),
                                      ],
                                    )
                                  else
                                    const Text('暂无成绩',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.neutral500)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
