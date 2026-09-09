import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../models/match3_mode.dart';
import '../../models/game_item_model.dart';
import '../../services/game_item_service.dart';
import '../../services/game_service.dart';
import '../../shared/game_shell.dart';
import 'match3_flame_game.dart';
import 'goal_banner.dart';
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
  /// 道具商城扩展总开关（2026-09-09 预留，暂不开放）：
  /// 开启后死局时优先询问使用洗牌券、控制栏追加「提示/破坏/洗牌」三道具。
  /// 引擎能力（doShuffle/smashAt/highlightHint/stalemateHandler）已全部就绪，
  /// 开放仅需：置 true + 后台 game_items 配置 shuffle/hammer 道具行。
  static const bool kPropShopEnabled = false;

  late final ValueNotifier<int> _hudTick;
  late final Match3Objective _objective;
  late final Match3FlameGame _game;
  late final Match3Mode _mode;

  /// 限时模式加时卡道具状态（免费额度 + 购买库存）
  GameItemModel? _addTimeItem;
  int _addTimeFree = 0;
  int _addTimeOwned = 0;

  /// 洗牌 / 局部破坏道具状态（道具商城扩展预留，开关关闭时不加载）
  GameItemModel? _shuffleItem;
  int _shuffleFree = 0;
  int _shuffleOwned = 0;
  GameItemModel? _hammerItem;
  int _hammerFree = 0;
  int _hammerOwned = 0;

  @override
  void initState() {
    super.initState();
    final cfg = widget.level?.config ?? const <String, dynamic>{};
    final levelNo = widget.level?.levelNo ?? 0;
    final rows = (cfg['rows'] as num?)?.toInt() ?? 8;
    final cols = (cfg['cols'] as num?)?.toInt() ?? 8;
    // 优先按关卡 mode_id → game_modes.play_kind 解析引擎行为（v2 唯一真相源）；
    // play_kind 缺失时回落 config 语义键 / level_no 百位兜底。
    String? playKind;
    final lvl = widget.level;
    if (lvl != null && lvl.modeId.isNotEmpty) {
      final mode = GameService.instance.cachedConfig.modes
          .where((m) => m.id == lvl.modeId)
          .firstOrNull;
      playKind = mode?.playKind;
    }
    _mode = resolveMatch3Mode(
      config: cfg,
      levelNo: levelNo,
      playKind: playKind,
    );
    _objective = Match3Objective.fromConfig(
      cfg,
      levelNo,
      rows: rows,
      cols: cols,
      mode: _mode,
    );
    _hudTick = ValueNotifier<int>(0);
    _game = Match3FlameGame(
      onFinished: widget.onFinished,
      objective: _objective,
      hudTick: _hudTick,
      rows: rows,
      cols: cols,
      // 方块类型数：难度配置项（config['types']，3..6），决定单局渲染几种糖果
      typeCount: (cfg['types'] is num ? (cfg['types'] as num).toInt() : 6),
    );
    if (_mode == Match3Mode.timed) _loadAddTime();
    // 道具商城扩展预留：死局处理器注入 + 洗牌/破坏道具加载（开关关闭时不生效）
    if (kPropShopEnabled) {
      _game.stalemateHandler = _handleStalemate;
      _loadSmashProps();
    }
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

  /// 重新开始前二次确认，避免误触丢失当前进度（与 g2048「新游戏」同口径）。
  Future<void> _confirmRestart() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃当前对局？'),
        content: const Text('点击「重新开始」将放弃当前进度（步数与得分不保留），确定要重新开始吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃并重新开始'),
          ),
        ],
      ),
    );
    if (sure == true) widget.onRestart?.call();
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

  // ---------- 道具商城扩展预留（kPropShopEnabled 暂为 false，未开放） ----------

  /// 加载洗牌/局部破坏道具（免费额度 + 购买库存），模式同加时卡。
  Future<void> _loadSmashProps() async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: 'match3');
      final inv = await GameItemService.instance.fetchInventory();
      void load(String itemType, void Function(GameItemModel?, int, int) set) {
        final item =
            items.where((it) => it.itemType == itemType).firstOrNull;
        if (item == null) return;
        final owned = inv[item.id] ?? 0;
        final free = item.freePerGame;
        final limit = item.perGameLimit;
        final budget = (limit - free).clamp(0, limit);
        set(item, free, owned < budget ? owned : budget);
      }

      if (!mounted) return;
      setState(() {
        load('shuffle', (it, f, o) {
          _shuffleItem = it;
          _shuffleFree = f;
          _shuffleOwned = o;
        });
        load('hammer', (it, f, o) {
          _hammerItem = it;
          _hammerFree = f;
          _hammerOwned = o;
        });
      });
    } catch (e) {
      // 载入失败不影响对局
    }
  }

  /// 死局处理器（引擎 stalemateHandler 回调）：优先询问使用洗牌券，
  /// 用券洗牌成功返回 true（对局继续）；无券/取消/洗牌失败返回 false
  /// （引擎判负结算）。
  Future<bool> _handleStalemate() async {
    final available = _shuffleItem != null && (_shuffleFree + _shuffleOwned) > 0;
    if (!available) return false;
    final useFree = _shuffleFree > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('无可消组合'),
        content: Text(
          useFree
              ? '盘面已无可消交换。使用 1 次免费洗牌（剩余 $_shuffleFree 次）重排盘面吗？'
              : '盘面已无可消交换。使用 1 张洗牌券（库存剩余 $_shuffleOwned 张）重排盘面吗？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('放弃对局'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('使用洗牌'),
          ),
        ],
      ),
    );
    if (confirm != true) return false;
    return _useShuffle();
  }

  /// 使用洗牌：先免费用完再消耗库存，成功后引擎重排盘面（缓存对局继续）。
  Future<bool> _useShuffle() async {
    if (_shuffleItem == null) return false;
    if (_shuffleFree > 0) {
      if (mounted) setState(() => _shuffleFree -= 1);
    } else {
      final ok = await GameItemService.instance.consumeItem(_shuffleItem!.id);
      if (!ok) {
        if (mounted) setState(() => _shuffleOwned = 0);
        return false;
      }
      if (mounted) setState(() => _shuffleOwned -= 1);
    }
    return _game.doShuffle();
  }

  /// 确认使用局部破坏（锤子）：确认即消耗，进入待命中——下一次点击盘面
  /// 格执行破坏（引擎 smashArmed）。
  Future<void> _confirmHammer() async {
    if (_hammerItem == null) return;
    if (_hammerFree <= 0 && _hammerOwned <= 0) return;
    final useFree = _hammerFree > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使用破坏锤？'),
        content: Text(
          useFree
              ? '确定要使用「破坏锤」吗？将消耗 1 次免费次数（剩余 $_hammerFree 次），点击后任意点击盘面一颗糖直接消除。'
              : '确定要使用「破坏锤」吗？将消耗 1 张道具卡（库存剩余 $_hammerOwned 张），点击后任意点击盘面一颗糖直接消除。',
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
    if (confirm != true) return;
    if (_hammerFree > 0) {
      if (mounted) setState(() => _hammerFree -= 1);
    } else {
      final ok = await GameItemService.instance.consumeItem(_hammerItem!.id);
      if (!ok) {
        if (mounted) setState(() => _hammerOwned = 0);
        return;
      }
      if (mounted) setState(() => _hammerOwned -= 1);
    }
    _game.smashArmed = true;
  }

  @override
  void dispose() {
    _hudTick.dispose();
    super.dispose();
  }

  /// 顶部横幅：Boss 血条 / 收集与破冰的「目标达成条件」chips
  Widget? _buildBanner() {
    if (_mode == Match3Mode.collect || _mode == Match3Mode.obstacle) {
      return Match3GoalBanner(objective: _objective);
    }
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
        // 目标糖果不再放 HUD 状态栏：收集/破冰的「目标达成条件」统一在
        // 游戏容器内上方 banner 展示（图标×N、居中、实时减少，2026-09-07 拍板）
        return GameShell(
          statusItems: stats
              .map(
                (s) => GameStatusItem(
                  label: s.label,
                  value: s.value,
                  valueColor: s.alert ? AppTheme.error : null,
                ),
              )
              .toList(),
          
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
            // 道具商城扩展预留三道具（kPropShopEnabled 暂 false 不渲染）
            if (kPropShopEnabled) ...<GameAction>[
              GameAction(
                icon: Icons.lightbulb_outline,
                label: '提示',
                onPressed: _game.highlightHint,
              ),
              GameAction(
                icon: Icons.construction_outlined,
                label: '破坏',
                badge: '${_hammerFree + _hammerOwned}',
                extraTag: _hammerFree > 0 ? '免$_hammerFree' : null,
                onPressed: (_hammerFree + _hammerOwned) > 0
                    ? () {
                        _confirmHammer();
                      }
                    : null,
              ),
              GameAction(
                icon: Icons.shuffle_outlined,
                label: '洗牌',
                badge: '${_shuffleFree + _shuffleOwned}',
                extraTag: _shuffleFree > 0 ? '免$_shuffleFree' : null,
                onPressed: (_shuffleFree + _shuffleOwned) > 0
                    ? () async {
                        await _useShuffle();
                      }
                    : null,
              ),
            ],
            GameAction(
              icon: Icons.refresh,
              label: '重新开始',
              primary: true,
              onPressed: widget.onRestart == null ? null : _confirmRestart,
            ),
          ],
          content: LayoutBuilder(
            builder: (ctx, constraints) {
              // 画布铺满内容区，正方形网格在内部居中，深色底板自然填满上下留白。
              // 目标达成条件横幅（收集/破冰）置于同一 ClipRRect 深色圆角容器内
              // 顶端——与棋盘一体，消除两个模块间的白色裁剪裸露（2026-09-07）。
              final banner = _buildBanner();
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: <Widget>[
                      if (banner != null) banner,
                      Expanded(child: GameWidget(game: _game)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
