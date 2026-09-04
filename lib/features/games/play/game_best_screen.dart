import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../models/match3_mode.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';

/// 最佳记录页（从原成绩看板拆分）：展示各模式最佳成绩（消消乐）
/// 或各维度最佳成绩（2048 / 羊了个羊）。
class GameBestScreen extends StatefulWidget {
  final GameModel game;

  const GameBestScreen({super.key, required this.game});

  @override
  State<GameBestScreen> createState() => _GameBestScreenState();
}

/// 某个模式的最佳成绩聚合
class _ModeBest {
  final Match3Mode mode;
  int bestScore = 0;
  int clears = 0;
  _ModeBest(this.mode);
}

class _GameBestScreenState extends State<GameBestScreen> {
  List<GameBestScore> _best = <GameBestScore>[];
  List<_ModeBest> _modeBest = <_ModeBest>[];
  bool _loading = true;

  late final bool _isModeGame = widget.game.code == 'match3';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_isModeGame) {
      final levels = GameService.instance.cachedConfig.levelsOf(widget.game.id);
      final levelMode = <String, Match3Mode>{};
      for (final lv in levels) {
        levelMode[lv.id] = parseMatch3Mode(lv.config, lv.levelNo);
      }
      final entries =
          await GameScoreService.instance.fetchScoresWithValues(widget.game.id);
      final acc = <Match3Mode, _ModeBest>{};
      for (final e in entries) {
        final mode = e.score.levelId != null ? levelMode[e.score.levelId] : null;
        if (mode == null) continue;
        final mb = acc.putIfAbsent(mode, () => _ModeBest(mode));
        final score = e.values['score']?.toInt() ?? 0;
        if (score > mb.bestScore) mb.bestScore = score;
        if (e.score.isCleared) mb.clears++;
      }
      if (mounted) {
        setState(() => _modeBest = acc.values.toList()
          ..sort((a, b) => a.mode.index.compareTo(b.mode.index)));
      }
    } else {
      final best = await GameScoreService.instance
          .fetchBestScores(gameId: widget.game.id, force: true);
      if (mounted) {
        setState(() => _best = best
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtBest(GameBestScore b) {
    if (b.isDuration) {
      final sec = (b.bestValue / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    return '${b.bestValue.toInt()}${b.unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 最佳记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(_isModeGame ? '各模式最佳成绩' : '最佳成绩',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildBestSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBestSection() {
    if (_isModeGame) {
      if (_modeBest.isEmpty) {
        return const Text('暂无成绩', style: TextStyle(color: AppTheme.neutral500));
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: _modeBest
                .map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Icon(m.mode.icon, color: m.mode.color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(m.mode.label,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Text('最高 ${m.bestScore}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              )),
                          const SizedBox(width: 12),
                          Text('通关 ${m.clears} 次',
                              style: const TextStyle(
                                fontSize: 12, color: AppTheme.neutral600)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );
    }
    if (_best.isEmpty) {
      return const Text('暂无成绩', style: TextStyle(color: AppTheme.neutral500));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _best
              .map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(b.dimensionName,
                            style: const TextStyle(color: AppTheme.neutral600)),
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
    );
  }
}
