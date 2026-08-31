import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../models/game_score_model.dart';
import '../services/game_score_service.dart';

/// 单游戏成绩看板（游戏页右上角入口）。
///
/// 展示该游戏各维度最佳成绩 + 最近游玩记录。
class GameSingleDashboard extends StatefulWidget {
  /// 游戏
  final GameModel game;

  const GameSingleDashboard({super.key, required this.game});

  @override
  State<GameSingleDashboard> createState() => _GameSingleDashboardState();
}

class _GameSingleDashboardState extends State<GameSingleDashboard> {
  List<GameBestScore> _best = <GameBestScore>[];
  List<GameScoreModel> _history = <GameScoreModel>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final best = await GameScoreService.instance
        .fetchBestScores(gameId: widget.game.id, force: true);
    final history =
        await GameScoreService.instance.fetchScoreHistory(widget.game.id);
    if (mounted) {
      setState(() {
        _best = best..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _history = history;
        _loading = false;
      });
    }
  }

  String _fmtBest(GameBestScore b) {
    if (b.isDuration) {
      final sec = (b.bestValue / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    return '${b.bestValue.toInt()}${b.unit ?? ''}';
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    // Supabase 返回 UTC（isUtc=true），须转本地时区再格式化，否则差 8 小时
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 成绩看板')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text('最佳成绩', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_best.isEmpty)
                  const Text('暂无成绩', style: TextStyle(color: AppTheme.neutral500))
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: _best
                            .map((b) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(b.dimensionName,
                                          style: const TextStyle(
                                              color: AppTheme.neutral600)),
                                      Text(_fmtBest(b),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.success,
                                          )),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('最近记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Text('暂无记录', style: TextStyle(color: AppTheme.neutral500))
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final h = _history[i];
                        final sec = ((h.durationMs ?? 0) / 1000).floor();
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            h.isCleared ? Icons.check_circle : Icons.cancel,
                            color: h.isCleared
                                ? AppTheme.success
                                : AppTheme.neutral500,
                            size: 18,
                          ),
                          title: Text(_fmtDate(h.playedAt)),
                          subtitle: Text(
                            '用时 ${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}',
                          ),
                          trailing: h.isCleared
                              ? const Text('通关', style: TextStyle(color: AppTheme.success))
                              : const Text('未通关'),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
