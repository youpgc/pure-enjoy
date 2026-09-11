import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../shared/duration_format.dart';
import '../shared/game_local_loading.dart';
import '../models/game_model.dart';
import '../models/game_score_model.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';

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
    // 统一北京时间展示（2026-09-11）：此前 toLocal() 依赖设备时区，
    // 非北京时区的设备（模拟器/出国真机）会偏差；改为固定 UTC+8，
    // 与 achievement_service.formatBeijing 同口径。格式 YYYY-MM-DD HH:mm:ss。
    final utc = dt.isUtc ? dt : dt.toUtc();
    final bj = utc.add(const Duration(hours: 8));
    return '${bj.year}-${bj.month.toString().padLeft(2, '0')}-${bj.day.toString().padLeft(2, '0')} '
        '${bj.hour.toString().padLeft(2, '0')}:${bj.minute.toString().padLeft(2, '0')}:${bj.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 游戏记录')),
      body: RefreshIndicator(
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

  /// 记录归属描述（从配置缓存反查）。
  ///
  /// 关卡名种子格式自带「游戏·模式」前缀（如「2048·经典模式 L001」），自含
  /// 归因信息——有关卡名时**直接返回（剥游戏名前缀）**，不再重复拼模式段；
  /// 无关卡名（无尽合成关 / 被删配置 / 默认流程）时降级：合成关显示「无尽模式」，
  /// 其余回退模式名，全无则空串（不占位）。
  String _scopeLabel(GameScoreModel h) {
    final config = GameService.instance.cachedConfig;
    String? modeName;
    if (h.modeId != null && h.modeId!.isNotEmpty) {
      for (final m in config.modesOf(widget.game.id)) {
        if (m.id == h.modeId) {
          modeName = m.name;
          break;
        }
      }
    }
    if (h.levelId != null && h.levelId!.isNotEmpty) {
      if (h.levelId!.startsWith('endless_2048')) {
        return '无尽模式';
      }
      for (final l in config.levelsOf(widget.game.id)) {
        if (l.id == h.levelId && l.name.isNotEmpty) {
          return _stripGamePrefix(l.name);
        }
      }
    }
    return modeName ?? '';
  }

  /// 剥掉关卡名开头的「游戏名·」前缀（种子格式「2048·经典模式 L001」→
  /// 「经典模式 L001」）；非该前缀开头（自定义关卡名 / 旧数据）原样返回。
  String _stripGamePrefix(String name) {
    final prefix = '${widget.game.name}·';
    return name.startsWith(prefix) ? name.substring(prefix.length) : name;
  }

  /// 无尽模式 id 集合（该游戏的 endless 模式）
  Set<String> get _endlessModeIds {
    final ids = <String>{};
    for (final m in GameService.instance.cachedConfig.modesOf(widget.game.id)) {
      if (m.isEndless) ids.add(m.id);
    }
    return ids;
  }

  /// 一条记录是否属于无尽会话（levelId=null 且 modeId 为无尽模式）
  bool _isEndlessRecord(GameScoreModel h) =>
      _endlessModeIds.contains(h.modeId) &&
      (h.levelId == null || h.levelId!.isEmpty);

  /// 聚合后的展示项：无尽会话（相邻间隔 ≤30 分钟的连续无尽记录）合并为
  /// 一项——总局数 + 累积分数（2026-09-07 拍板）；其余记录逐条展示。
  List<GameScoreModel> get _displayItems {
    final items = <GameScoreModel>[];
    var i = 0;
    while (i < _history.length) {
      final h = _history[i];
      if (!_isEndlessRecord(h)) {
        items.add(h);
        i++;
        continue;
      }
      // 收集连续的无尽会话记录（列表按 played_at 倒序；相邻间隔 ≤30 分钟视为同会话）
      final session = <GameScoreModel>[h];
      var j = i + 1;
      while (j < _history.length &&
          _isEndlessRecord(_history[j]) &&
          h.playedAt != null &&
          _history[j].playedAt != null &&
          h.playedAt!.difference(_history[j].playedAt!).inMinutes <= 30) {
        session.add(_history[j]);
        j++;
      }
      if (session.length == 1) {
        items.add(h);
      } else {
        num total = 0;
        for (final r in session) {
          total += r.score ?? 0;
        }
        // 会话聚合项：score=累积、durationMs=会话总时长（末条 played - 首条开始）
        final last = session.first;
        final first = session.last;
        final totalDur = (first.playedAt != null && last.playedAt != null)
            ? last.playedAt!
                .difference(
                    first.playedAt!.subtract(Duration(milliseconds: first.durationMs ?? 0)))
                .inMilliseconds
            : last.durationMs ?? 0;
        items.add(GameScoreModel(
          id: last.id,
          userId: last.userId,
          gameId: last.gameId,
          modeId: last.modeId,
          score: total,
          status: 'cleared',
          durationMs: totalDur,
          playedAt: last.playedAt,
        ));
        // 会话局数挂在静态 map 供 itemBuilder 读取
        _sessionRounds[last.id] = session.length;
      }
      i = j;
    }
    return items;
  }

  final Map<String, int> _sessionRounds = <String, int>{};

  Widget _buildHistorySection() {
    // 列表区局部 loading（规范：禁止整页 loading）
    if (_loading) {
      return const GameLocalLoading(label: '记录加载中…');
    }
    if (_history.isEmpty) {
      return const Text('暂无记录', style: TextStyle(color: AppTheme.neutral500));
    }
    final items = _displayItems;
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          if (i >= items.length) {
            // 分页 footer：仅在加载下一页时转圈；空闲时显示静态提示
            //（此前无条件渲染 spinner，只要还有下一页就一直转，2026-09-11 用户反馈）
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '上拉加载更多',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.neutral500),
                      ),
              ),
            );
          }
          final h = items[i];
          // 进阶时间单位（2026-09-11）：秒→分秒→时分秒，双端同口径
          final clock = formatDurationSmart(h.durationMs ?? 0);
          final scope = _scopeLabel(h);
          final isSession = _sessionRounds.containsKey(h.id);
          final subtitle = isSession
              ? '无尽模式 · ${_sessionRounds[h.id]} 局 · 累计 ${h.score?.toInt() ?? 0} 分 · 用时 $clock'
              : (scope.isEmpty
                  ? '用时 $clock'
                  : '$scope · 用时 $clock');
          return ListTile(
            dense: true,
            leading: Icon(
              (isSession || h.isCleared)
                  ? Icons.check_circle
                  : Icons.cancel,
              color: (isSession || h.isCleared)
                  ? AppTheme.success
                  : AppTheme.neutral500,
              size: 18,
            ),
            title: Text(_fmtDate(h.playedAt)),
            subtitle: Text(subtitle),
            trailing: // 对局结果统一状态语义（通关绿/放弃灰/失败红）：
                // 无尽会话聚合项（旧模型多局合并）也属正常结束 → 显示「通关」，
                // 会话归属信息已在副标题（无尽模式 · N 局 · 累计 X 分）
                (isSession || h.isCleared)
                    ? const Text('通关', style: TextStyle(color: AppTheme.success))
                    // 未通关区分语义：放弃=灰 / 挑战失败=红（2026-09-10）
                    : (h.status == 'aborted'
                        ? const Text('放弃',
                            style: TextStyle(color: AppTheme.neutral500))
                        : const Text('挑战失败',
                            style: TextStyle(color: AppTheme.error))),
          );
        },
      ),
    );
  }
}
