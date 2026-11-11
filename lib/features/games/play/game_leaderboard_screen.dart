import 'package:flutter/material.dart' hide ErrorWidget;

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'package:pure_enjoy/core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import '../../../services/error_reporter.dart';
import '../../../services/supabase_service.dart';
import '../models/game_dimension_model.dart';
import '../models/game_mode_model.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../shared/game_local_loading.dart';

/// 游戏排行榜页。
///
/// 数据源 `get_game_leaderboard` RPC（security definer 跨玩家聚合）：
/// - 总榜 / 周榜（北京自然周，周一 0 点重置）双榜切换；
/// - 模式筛选（全部模式 / 单模式，含自由模式）；
/// - 排行维度 = 该游戏主维度（is_primary：西行=farthest_level、g2048/match3/tetris=score、sheep=level，后台配置驱动）；
/// - 仅展示 昵称/头像/最佳值/游玩次数/最近游玩，不含其他敏感字段；
/// - 底部常驻「我的排名」（不在榜内显示未上榜）。
class GameLeaderboardScreen extends StatefulWidget {
  final GameModel game;

  const GameLeaderboardScreen({super.key, required this.game});

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

/// 榜单行（RPC 返回行解析）
class _LeaderboardRow {
  final int rank;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final num bestValue;
  final int playCount;
  final DateTime? lastPlayedAt;
  final bool isMe;

  const _LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.bestValue,
    required this.playCount,
    required this.isMe,
    this.avatarUrl,
    this.lastPlayedAt,
  });

  factory _LeaderboardRow.fromJson(Map<String, dynamic> j) {
    return _LeaderboardRow(
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      userId: j['user_id']?.toString() ?? '',
      nickname: (j['nickname']?.toString().isNotEmpty ?? false)
          ? j['nickname'].toString()
          : '玩家',
      avatarUrl: j['avatar_url']?.toString(),
      bestValue: (j['best_value'] as num?) ?? 0,
      playCount: (j['play_count'] as num?)?.toInt() ?? 0,
      lastPlayedAt: j['last_played_at'] != null
          ? DateTime.tryParse(j['last_played_at'].toString())
          : null,
      isMe: j['is_me'] == true,
    );
  }
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  /// 榜单周期：'all'=总榜 / 'week'=周榜
  String _scope = 'all';

  /// 模式筛选：null=全部模式
  String? _modeId;

  /// 排行维度码（后台主维度配置驱动：西行=farthest_level、sheep=level、g2048/match3/tetris=score）
  String? _dimension;
  String? _dimensionName;

  bool _loading = true;
  String? _error;
  List<_LeaderboardRow> _rows = const <_LeaderboardRow>[];

  /// 可选模式清单（配置快照驱动，含自由模式）
  List<GameModeModel> _modes = const <GameModeModel>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// 维度与模式清单来自配置快照（TTL 缓存，秒开），随后拉榜单。
  Future<void> _init() async {
    try {
      final config = await GameService.instance.fetchConfig();
      if (!mounted) return;
      // 计分维度：优先主维度 is_primary（后台权威标记，取证：每游戏恰一个；
      // sheep=level，g2048/match3/tetris=score），无主维度时回落 score/level
      final dims = config
          .dimensionsOf(widget.game.id)
          .where((d) => d.enabled)
          .toList(growable: false);
      GameDimensionModel? dim;
      // 排行维度 = 该游戏的「主维度」(is_primary，任意 code 均可；
      // 如西行=farthest_level、g2048/match3/tetris=score、sheep=level)。
      // 旧式 score/level 码仅在无主维度时兜底，保持向后兼容。
      for (final d in dims) {
        if (d.isPrimary) {
          dim = d;
          break;
        }
      }
      if (dim == null) {
        for (final d in dims) {
          if (d.code == 'score' || d.code == 'level') {
            dim = d;
            break;
          }
        }
      }
      setState(() {
        _dimension = dim?.code;
        _dimensionName = dim?.name;
        _modes = config.modesOf(widget.game.id);
      });
    } catch (e, st) {
      // 配置异常不阻塞榜单：维度缺省按 score 兜底，由 RPC 空集承接
      ErrorReporter.report(e, st, module: 'games', level: 'warning');
      if (mounted) {
        setState(() {
          _dimension ??= 'score';
        });
      }
    }
    await _load();
  }

  Future<void> _load() async {
    final dim = _dimension;
    if (dim == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiClient.rpc(
        'get_game_leaderboard',
        params: <String, dynamic>{
          'p_game_id': widget.game.id,
          'p_dimension': dim,
          'p_scope': _scope,
          'p_mode_id': _modeId,
          'p_limit': 50,
        },
        note: 'games:leaderboard',
      );
      if (!result.isSuccess) {
        throw Exception(result.errorMessage);
      }
      final rows = ((result.data as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_LeaderboardRow.fromJson)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, module: 'games', level: 'warning');
      if (mounted) {
        setState(() {
          _error = '榜单加载失败，请重试';
          _loading = false;
        });
      }
    }
  }

  void _switchScope(String scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    _load();
  }

  void _switchMode(String? modeId) {
    if (_modeId == modeId) return;
    setState(() => _modeId = modeId);
    _load();
  }

  _LeaderboardRow? get _myRow {
    for (final r in _rows) {
      if (r.isMe) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dimLabel = _dimensionName ?? '成绩';
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 排行榜')),
      body: Column(
        children: <Widget>[
          // 总榜 / 周榜切换 + 维度说明
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                          value: 'all', label: Text('总榜')),
                      ButtonSegment<String>(
                          value: 'week', label: Text('周榜')),
                    ],
                    selected: <String>{_scope},
                    onSelectionChanged: (s) => _switchScope(s.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(width: 12),
                Text('按$dimLabel',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.neutral500)),
              ],
            ),
          ),
          // 模式筛选（全部 + 各模式，横向滚动）
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: <Widget>[
                _modeChip(null, '全部模式'),
                for (final m in _modes) _modeChip(m.id, m.name),
              ],
            ),
          ),
          const Divider(height: 1),
          // 榜单主体（局部加载/错误/空态，禁整页 loading）
          Expanded(
            child: _loading
                ? const GameLocalLoading(label: '榜单加载中…')
                : _error != null
                    ? ErrorWidget(
                        message: _error!,
                        actionText: '重试',
                        onRetry: _load,
                      )
                    : _rows.isEmpty
                        ? const EmptyWidget(
                            icon: Icons.emoji_events_outlined,
                            message: '暂无上榜记录，快来抢占第一',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.only(top: 4, bottom: 12),
                              itemCount: _rows.length,
                              itemBuilder: (_, i) => _rowTile(_rows[i]),
                            ),
                          ),
          ),
          // 我的排名（常驻底部）
          _myRankBar(),
        ],
      ),
    );
  }

  Widget _modeChip(String? modeId, String label) {
    final selected = _modeId == modeId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _switchMode(modeId),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _rowTile(_LeaderboardRow r) {
    final medal = r.rank <= 3
        ? const <int, Color>{1: Color(0xFFFFB300), 2: Color(0xFF9E9E9E), 3: Color(0xFFBF6B3A)}[r.rank]
        : null;
    return ListTile(
      leading: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
          ? CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(r.avatarUrl!),
              onBackgroundImageError: (_, __) {},
            )
          : CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.neutral200,
              child: Text(
                  r.nickname.isNotEmpty ? r.nickname.substring(0, 1) : '玩',
                  style: const TextStyle(fontSize: 14)),
            ),
      title: Text(
        r.isMe ? '${r.nickname}（我）' : r.nickname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: r.isMe ? FontWeight.bold : FontWeight.w500,
          color: r.isMe ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        '游玩 ${r.playCount} 局'
        '${r.lastPlayedAt != null ? ' · ${_fmtTime(r.lastPlayedAt!)}' : ''}',
        style: const TextStyle(fontSize: 11, color: AppTheme.neutral500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_fmtValue(r.bestValue),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(
            width: 40,
            child: Text(
              '#${r.rank}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: medal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myRankBar() {
    final loggedIn = AuthService.instance.currentUserId != null;
    final me = _myRow;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.neutral300)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.person_pin_rounded,
              size: 20, color: AppTheme.neutral500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !loggedIn
                  ? '登录后参与排名'
                  : me != null
                      ? '我的排名：第 ${me.rank} 名 · ${_fmtValue(me.bestValue)}'
                      : '本期暂未上榜，玩一局上榜',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtValue(num v) {
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(1);
  }

  String _fmtTime(DateTime t) {
    final b = t.toUtc().add(const Duration(hours: 8));
    return '${b.month.toString().padLeft(2, '0')}-'
        '${b.day.toString().padLeft(2, '0')} '
        '${b.hour.toString().padLeft(2, '0')}:'
        '${b.minute.toString().padLeft(2, '0')}';
  }
}
