import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../models/match3_mode.dart';
import '../../models/game_item_model.dart';
import '../../services/game_item_service.dart';
import '../../shared/game_shell.dart';
import 'match3_flame_game.dart';
import 'match3_objective.dart';

/// 消消乐 Flutter 承载组件。
///
/// 布局遵循「按钮与视图分离」：信息条在**上方独立容器**、盘面独占中间容器、
/// 控制按钮统一在**底部控制栏**，任何控件都不再叠加覆盖在盘面之上。
/// 关卡目标由 [Match3Objective] 按 6 种模式驱动。
class Match3Game extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 关卡（读取 config 的 mode/steps/goal 等决定模式与目标；为 null 用默认）
  final GameLevelModel? level;

  /// 请求重开本局（由外层承载页重建游戏实例）
  final VoidCallback? onRestart;

  const Match3Game({
    super.key,
    required this.onFinished,
    this.level,
    this.onRestart,
  });

  @override
  State<Match3Game> createState() => _Match3GameState();
}

class _Match3GameState extends State<Match3Game> {
  late final ValueNotifier<int> _hudTick;
  late final Match3Objective _objective;
  late final Match3FlameGame _game;
  late final Match3Mode _mode;

  /// 限时模式加时卡道具状态（免费额度 + 购买库存）
  GameItemModel? _addTimeItem;
  int _addTimeFree = 0;
  int _addTimeOwned = 0;

  @override
  void initState() {
    super.initState();
    final cfg = widget.level?.config ?? const <String, dynamic>{};
    final levelNo = widget.level?.levelNo ?? 0;
    final rows = (cfg['rows'] as num?)?.toInt() ?? 8;
    final cols = (cfg['cols'] as num?)?.toInt() ?? 8;
    _mode = parseMatch3Mode(cfg, levelNo);
    _objective = Match3Objective.fromConfig(
      cfg,
      levelNo,
      rows: rows,
      cols: cols,
    );
    _hudTick = ValueNotifier<int>(0);
    _game = Match3FlameGame(
      onFinished: widget.onFinished,
      objective: _objective,
      hudTick: _hudTick,
      rows: rows,
      cols: cols,
    );
    if (_mode == Match3Mode.timed) _loadAddTime();
  }

  /// 限时模式开局：载入 add_time 道具，先免费用 free_per_game 次，再消耗购买库存。
  Future<void> _loadAddTime() async {
    try {
      final items = await GameItemService.instance
          .fetchItems(gameCode: 'match3', mode: 'timed');
      final item =
          items.where((it) => it.itemType == 'add_time').firstOrNull;
      if (item == null) return;
      final inv = await GameItemService.instance.fetchInventory();
      final owned = inv[item.id] ?? 0;
      final free = item.freePerGame;
      final limit = item.perGameLimit;
      final purchasedBudget = (limit - free).clamp(0, limit);
      if (mounted) {
        setState(() {
          _addTimeItem = item;
          _addTimeFree = free;
          _addTimeOwned = owned < purchasedBudget ? owned : purchasedBudget;
        });
      }
    } catch (e) {
      // 载入失败不影响对局
    }
  }

  /// 使用加时卡前弹窗确认（免费次数或购买库存均先确认，避免误触消耗）。
  Future<void> _confirmAddTime() async {
    if (_addTimeItem == null) return;
    if (_addTimeFree <= 0 && _addTimeOwned <= 0) return;
    final useFree = _addTimeFree > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使用加时卡？'),
        content: Text(
          useFree
              ? '确定要使用「加时卡」吗？将消耗 1 次免费次数（剩余 $_addTimeFree 次），使用后本局 +15 秒，不可撤销。'
              : '确定要使用「加时卡」吗？将消耗 1 张道具卡（库存剩余 $_addTimeOwned 张），使用后本局 +15 秒，不可撤销。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定使用'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _useAddTime();
    }
  }

  /// 使用加时卡：先免费用完再消耗库存，成功后本局加时 15 秒。
  Future<void> _useAddTime() async {
    if (_addTimeItem == null) return;
    if (_addTimeFree <= 0 && _addTimeOwned <= 0) return;
    if (_addTimeFree > 0) {
      _addTimeFree -= 1;
    } else {
      final ok = await GameItemService.instance.consumeItem(_addTimeItem!.id);
      if (!ok) {
        if (mounted) setState(() => _addTimeOwned = 0);
        return;
      }
      _addTimeOwned -= 1;
    }
    _game.addTime(15);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hudTick.dispose();
    super.dispose();
  }

  /// Boss 模式的血条 / 其他模式的目标进度条
  Widget? _buildBanner() {
    if (_mode != Match3Mode.boss) return null;
    final ratio = _objective.bossHp <= 0
        ? 0.0
        : (_objective.bossLeft / _objective.bossHp).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Icon(_mode.icon, size: 20, color: _mode.color),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: AppTheme.neutral300,
                // 血量条按国内涨红跌绿之外的通用语义：血量用红色
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.error),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${_objective.bossLeft}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _hudTick,
      builder: (_, __, ___) {
        final stats = _objective.stats();
        return GameShell(
          statusItems: stats
              .map((s) => GameStatusItem(
                    label: s.label,
                    value: s.value,
                    valueColor: s.alert ? AppTheme.error : null,
                  ))
              .toList(),
          banner: _buildBanner(),
          hint: _objective.hint,
          actions: <GameAction>[
            if (_mode == Match3Mode.timed && _addTimeItem != null)
              GameAction(
                icon: Icons.timer_outlined,
                label: '加时卡',
                badge: '${_addTimeFree + _addTimeOwned}',
                extraTag: _addTimeFree > 0 ? '免$_addTimeFree' : null,
                onPressed: (_addTimeFree + _addTimeOwned) > 0
                    ? () {
                        _confirmAddTime();
                      }
                    : null,
              ),
            GameAction(
              icon: Icons.refresh,
              label: '重新开始',
              primary: true,
              onPressed: widget.onRestart,
            ),
          ],
          content: LayoutBuilder(
            builder: (ctx, constraints) {
              // 画布铺满内容区，正方形网格在内部居中，深色底板自然填满上下留白
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GameWidget(game: _game),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
