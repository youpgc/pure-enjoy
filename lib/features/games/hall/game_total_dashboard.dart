import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../services/game_score_service.dart';

/// 全部游戏最佳成绩看板（游戏栏右上角入口）。
class GameTotalDashboard extends StatefulWidget {
  const GameTotalDashboard({super.key});

  @override
  State<GameTotalDashboard> createState() => _GameTotalDashboardState();
}

class _GameTotalDashboardState extends State<GameTotalDashboard> {
  List<GameBestScore> _best = <GameBestScore>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await GameScoreService.instance.loadCachedBestScores();
    if (mounted) setState(() => _best = cached);
    final list = await GameScoreService.instance.fetchBestScores(force: true);
    if (mounted) setState(() => _best = list..sort((a, b) => a.gameCode.compareTo(b.gameCode)));
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(GameBestScore b) {
    if (b.isDuration) {
      final sec = (b.bestValue / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    return '${b.bestValue.toInt()}${b.unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    // 按游戏分组
    final byGame = <String, List<GameBestScore>>{};
    for (final b in _best) {
      byGame.putIfAbsent(b.gameId, () => <GameBestScore>[]).add(b);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('全部最佳成绩')),
      body: _loading && _best.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : byGame.isEmpty
              ? const Center(child: Text('暂无成绩记录'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: byGame.length,
                  itemBuilder: (ctx, i) {
                    final entry = byGame.entries.elementAt(i);
                    final rows = entry.value
                      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.value.first.gameName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...rows.map((b) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(b.dimensionName,
                                          style: const TextStyle(
                                              color: AppTheme.neutral600)),
                                      Text(_fmt(b),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.success,
                                          )),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
