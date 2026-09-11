import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../game_play_helpers.dart';
import '../models/game_dimension_model.dart';
import '../models/game_level_model.dart';
import '../models/game_mode_model.dart';
import '../models/game_model.dart';
import '../models/game_score_model.dart';
import '../models/match3_mode.dart';
import '../services/game_score_service.dart';
import '../services/game_service.dart';
import '../shared/duration_format.dart';
import '../shared/game_local_loading.dart';

/// 最佳记录页（从原成绩看板拆分）：三游戏统一「各模式最佳成绩」。
///
/// 2026-09-10 修复：原实现 2048/羊了个羊走 `get_game_best_scores` RPC
/// 游戏级聚合（无模式划分，只出一条记录）；消消乐用 `parseMatch3Mode`
/// 从关卡 config 猜模式（config 无 mode 键时回落 level_no 百位=0 → 全算计分），
/// 导致模式展示缺失。现统一为 `fetchScoresWithValues` 本地聚合 +
/// `level.modeId → game_modes` 分组（score.modeId 兜底，覆盖 2048 无尽合成局）。
class GameBestScreen extends StatefulWidget {
  final GameModel game;

  const GameBestScreen({super.key, required this.game});

  @override
  State<GameBestScreen> createState() => _GameBestScreenState();
}

/// 某个模式的最佳成绩聚合（模式 → 主维度最佳值 + 通关次数）
class _ModeBest {
  /// 模式 id（game_modes.id）
  final String modeId;

  /// 展示名（消消乐用 Match3Mode 定版名，其余用 game_modes.name）
  final String label;

  /// 模式主色（消消乐用 Match3Mode 配色，其余按 playKind 取统一网格色）
  final Color color;

  /// 模式图标 SVG 资源名（game_modes.icon，空则用内置 [fallbackIcon]）
  final String iconAsset;

  /// 内置兜底图标（消消乐定版 Material 图标 / 其余网格兜底）
  final IconData fallbackIcon;

  /// 主维度最佳取值
  num bestValue = 0;

  /// 是否有主维度取值（缺失展示 '—'）
  bool hasValue = false;

  /// 通关次数
  int clears = 0;

  _ModeBest({
    required this.modeId,
    required this.label,
    required this.color,
    required this.iconAsset,
    required this.fallbackIcon,
  });
}

class _GameBestScreenState extends State<GameBestScreen> {
  /// 按模式聚合的最佳成绩（键顺序 = 模式 sort_order）
  List<_ModeBest> _modeBest = <_ModeBest>[];
  bool _loading = true;

  /// 消消乐：用 Match3Mode 定版名/配色/图标渲染
  late final bool _isModeGame = widget.game.code == 'match3';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = GameService.instance.cachedConfig;

    // 模式索引：id → 模式（按 sort_order 升序，输出顺序与之对齐）
    final modes = snapshot.modesOf(widget.game.id);
    final modeById = <String, GameModeModel>{
      for (final m in modes) m.id: m,
    };
    // 关卡索引：id → 关卡（成绩 → 关卡 → 模式 的解析链）
    final levelById = <String, GameLevelModel>{
      for (final lv in snapshot.levelsOf(widget.game.id)) lv.id: lv,
    };
    // 主维度（最佳成绩取值维度）：优先 isPrimary，缺失回落第一个维度；
    // 维度未配置时置 null（后台漏配维度防崩，仅展示通关次数）
    final dims = snapshot.dimensionsOf(widget.game.id);
    final GameDimensionModel? primary = dims.isEmpty
        ? null
        : dims.firstWhere(
            (d) => d.isPrimary,
            orElse: () => dims.first,
          );

    final entries =
        await GameScoreService.instance.fetchScoresWithValues(widget.game.id);

    final acc = <String, _ModeBest>{};
    for (final e in entries) {
      // 模式解析：level.modeId 优先（关卡级真相源），score.modeId 兜底
      // （2048 无尽合成局 level_id 为 null，主记录仍带模式 id）
      final lv = e.score.levelId != null ? levelById[e.score.levelId] : null;
      String? modeId;
      if (lv != null && lv.modeId.isNotEmpty) modeId = lv.modeId;
      modeId ??= e.score.modeId;
      final mode = modeId != null ? modeById[modeId] : null;
      if (mode == null) continue;

      final mb = acc.putIfAbsent(
        mode.id,
        () => _isModeGame
            ? _match3ModeBest(mode)
            : _ModeBest(
                modeId: mode.id,
                label: mode.name,
                color: modeColorOf(mode.playKind),
                iconAsset: mode.icon,
                fallbackIcon: Icons.grid_view_rounded,
              ),
      );
      if (primary != null) {
        final v = e.valueOf(primary.code);
        if (v != null) {
          if (!mb.hasValue) {
            mb.bestValue = v;
            mb.hasValue = true;
          } else if (primary.isLowerBetter ? v < mb.bestValue : v > mb.bestValue) {
            mb.bestValue = v;
          }
        }
      }
      if (e.score.isCleared) mb.clears++;
    }

    if (mounted) {
      setState(() => _modeBest = acc.values.toList()
        ..sort((a, b) {
          final ia = modes.indexWhere((m) => m.id == a.modeId);
          final ib = modes.indexWhere((m) => m.id == b.modeId);
          return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
        }));
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 消消乐模式聚合行：play_kind → Match3Mode 定版元数据（含早期 DB 占位码兜底）
  _ModeBest _match3ModeBest(GameModeModel mode) {
    final m = match3ModeFromAnyCode(mode.playKind) ??
        match3ModeFromAnyCode(mode.code) ??
        Match3Mode.score;
    return _ModeBest(
      modeId: mode.id,
      label: m.label,
      color: m.color,
      iconAsset: mode.icon,
      fallbackIcon: m.icon,
    );
  }

  /// 主维度取值格式化：时长进阶单位，其余「值+单位」
  String _fmtBest(_ModeBest m, GameDimensionModel primary) {
    if (!m.hasValue) return '—';
    if (primary.isDuration) {
      return formatDurationSmart(m.bestValue);
    }
    return '${m.bestValue.toInt()}${primary.unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game.name} · 最佳记录')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text('各模式最佳成绩',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 数据区局部 loading（规范：禁止整页 loading）
            if (_loading)
              const GameLocalLoading(label: '成绩加载中…')
            else
              _buildBestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSection() {
    if (_modeBest.isEmpty) {
      return const Text('暂无成绩', style: TextStyle(color: AppTheme.neutral500));
    }
    final snapshot = GameService.instance.cachedConfig;
    final dims = snapshot.dimensionsOf(widget.game.id);
    final GameDimensionModel? primary = dims.isEmpty
        ? null
        : dims.firstWhere(
            (d) => d.isPrimary,
            orElse: () => dims.first,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _modeBest
              .map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: <Widget>[
                        _buildModeIcon(m),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (primary != null)
                          Text(
                            '${primary.isLowerBetter ? '最快' : '最高'} ${_fmtBest(m, primary)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                            ),
                          ),
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

  /// 模式图标：SVG 资源优先（与主界面/选关一致），缺失回落内置图标
  Widget _buildModeIcon(_ModeBest m) {
    if (m.iconAsset.isNotEmpty) {
      return SvgPicture.asset(modeIconAsset(m.iconAsset),
          width: 20, height: 20,
          errorBuilder: (_, __, ___) =>
              Icon(m.fallbackIcon, color: m.color, size: 20));
    }
    return Icon(m.fallbackIcon, color: m.color, size: 20);
  }
}
