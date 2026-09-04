import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../models/game_model.dart';
import '../models/game_score_model.dart';
import '../services/game_score_service.dart';

/// 游戏记录页（从原成绩看板拆分）：对局历史列表，滚动到底自动加载下一页。
class GameHistoryScreen extends StatefulWidget {
  final GameModel game;

  const GameHistoryScreen({super.key, required this.game});

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  List<GameScoreModel> _history = <GameScoreModel>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
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

  Future<void> _loadMore() => _loadHistoryPage();

  Future<void> _load() async {
    setState(() => _loading = true);
    await _loadHistoryPage(reset: true);
    if (mounted) setState(() => _loading = false);
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

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';
    // Supabase 返回 UTC（isUtc=true），须转本地时区再格式化，否则差 8 小时
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 游戏记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _buildHistorySection(),
                ],
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
