import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import './game_total_dashboard.dart';
import '../game_play_helpers.dart';
import '../game_play_screen.dart';
import '../models/game_level_model.dart';
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

  /// 点击游戏入口：允许选关且启用关卡 > 1 时弹选关界面，否则直接进入首关。
  void _openGame(GameModel game) {
    final levels = _config?.levelsOf(game.id) ?? <GameLevelModel>[];
    if (game.levelSelectable && levels.length > 1) {
      _showLevelSelect(game, levels);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GamePlayScreen(game: game)),
    );
  }

  /// 选关底部弹窗（仅展示启用关卡）。
  void _showLevelSelect(GameModel game, List<GameLevelModel> levels) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '选择关卡 · ${game.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...levels.map(
            (lv) => ListTile(
              title: Text(lv.name),
              subtitle: lv.countForDailyClear
                  ? const Text('通关计入每日首通奖励')
                  : const Text('不计入每日首通奖励'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GamePlayScreen(game: game, level: lv),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
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
                                  Icon(gameIcon(game.icon),
                                      size: 48, color: AppTheme.primaryOrange),
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
