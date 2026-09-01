import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../models/game_score_model.dart';
import '../models/match3_mode.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';

/// 单游戏成绩看板（游戏页右上角入口）。
///
/// - 有模式配置的游戏（如消消乐）：优先展示**各模式最佳成绩**，而非单一最佳；
/// - 其余游戏：展示各维度最佳成绩；
/// - 游戏记录列表采用**分页滚动加载**（每页 20 条，滑到底自动续拉）。
class GameSingleDashboard extends StatefulWidget {
  /// 游戏
  final GameModel game;

  const GameSingleDashboard({super.key, required this.game});

  @override
  State<GameSingleDashboard> createState() => _GameSingleDashboardState();
}

/// 某个模式的最佳成绩聚合
class _ModeBest {
  final Match3Mode mode;
  int bestScore = 0;
  int clears = 0;
  _ModeBest(this.mode);
}

class _GameSingleDashboardState extends State<GameSingleDashboard> {
  List<GameBestScore> _best = <GameBestScore>[];
  List<_ModeBest> _modeBest = <_ModeBest>[];
  List<GameScoreModel> _history = <GameScoreModel>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  /// 是否「有模式配置」的游戏（消消乐）
  late final bool _isModeGame = widget.game.code == 'match3';
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240 &&
        _hasMore &&
        !_loadingMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_isModeGame) {
      await _loadModeBest();
    } else {
      final best = await GameScoreService.instance
          .fetchBestScores(gameId: widget.game.id, force: true);
      if (mounted) {
        setState(() => _best = best
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
      }
    }
    await _loadHistoryPage(reset: true);
    if (mounted) setState(() => _loading = false);
  }

  /// 聚合各模式最佳成绩：从缓存关卡配置得到「关卡→模式」映射，
  /// 再汇总该模式全部成绩的最高分与通关次数。
  Future<void> _loadModeBest() async {
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
  }

  Future<void> _loadHistoryPage({bool reset = false}) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final offset = reset ? 0 : _history.length;
    final page = await GameScoreService.instance.fetchScoreHistory(
      widget.game.id,
      limit: _pageSize,
      offset: offset,
    );
    if (mounted) {
      setState(() {
        if (reset) {
          _history = page;
        } else {
          _history = <GameScoreModel>[..._history, ...page];
        }
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
    } else {
      _loadingMore = false;
    }
  }

  Future<void> _loadMore() => _loadHistoryPage();

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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // 最佳成绩：有模式游戏展示「各模式最佳」，否则展示「各维度最佳」
                Text(_isModeGame ? '各模式最佳成绩' : '最佳成绩',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildBestSection(),
                const SizedBox(height: 20),
                const Text('游戏记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildHistorySection(),
              ],
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

  Widget _buildHistorySection() {
    if (_history.isEmpty) {
      return const Text('暂无记录', style: TextStyle(color: AppTheme.neutral500));
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _history.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (i >= _history.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final h = _history[i];
          final sec = ((h.durationMs ?? 0) / 1000).floor();
          return ListTile(
            dense: true,
            leading: Icon(
              h.isCleared ? Icons.check_circle : Icons.cancel,
              color: h.isCleared ? AppTheme.success : AppTheme.neutral500,
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
    );
  }
}
