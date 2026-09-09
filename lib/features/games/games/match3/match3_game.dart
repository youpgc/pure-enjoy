import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import '../../game_play_helpers.dart';
import '../../game_item_shop_screen.dart';
import '../../models/game_level_model.dart';
import '../../models/game_model.dart';
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

  /// 所属游戏（道具商城跳转、道具目录 game_code 来源）
  final GameModel game;

  /// 关卡（读取 config 的 mode/steps/goal 等决定模式与目标；为 null 用默认）
  final GameLevelModel? level;

  /// 请求重开本局（由外层承载页重建游戏实例）
  final VoidCallback? onRestart;

  const Match3Game({
    super.key,
    required this.onFinished,
    required this.game,
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

  /// 通用道具状态（洗牌/破坏/提示），**数据驱动**：
  /// game_items.enabled 控制是否存在（后台可测），level.config.propUnlock
  /// 控制关卡通关数解锁（{item_type: 解锁关号}，未配置 = 允许）。
  GameItemModel? _shuffleItem;
  int _shuffleFree = 0;
  int _shuffleOwned = 0;
  GameItemModel? _hammerItem;
  int _hammerFree = 0;
  int _hammerOwned = 0;
  GameItemModel? _hintItem;
  int _hintFree = 0;
  int _hintOwned = 0;

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
    // 道具商城（数据驱动）：死局处理器常驻注入；道具目录由
    // game_items.enabled 控制是否生效（后台可测），propUnlock 控制关卡解锁
    _game.stalemateHandler = _handleStalemate;
    _loadMatchProps();
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

  // ---------- 道具商城（洗牌/破坏/提示，数据驱动） ----------

  /// 加载通用道具目录与库存。
  ///
  /// 渲染条件（三者同时满足）：
  /// ① game_items.enabled=true（后台数据开关，测试/开放入口）；
  /// ② level.config.propUnlock 解锁（{item_type: 解锁关号}，level_no 达标；
  ///    未配置该键 = 允许，配置粒度见参考文档 §19）；
  /// ③ 模式适配（hint/shuffle/hammer 为通用道具 mode=''，全模式可用）。
  Future<void> _loadMatchProps() async {
    try {
      final items = await GameItemService.instance
          .fetchItems(gameCode: widget.game.code);
      final inv = await GameItemService.instance.fetchInventory();
      final levelNo = widget.level?.levelNo ?? 0;
      final unlock =
          (widget.level?.config ?? const <String, dynamic>{})['propUnlock'];
      bool allowed(String itemType) {
        if (unlock is Map) {
          final v = unlock[itemType];
          if (v is num) return levelNo >= v.toInt();
        }
        return true; // 未配置 = 允许
      }

      if (!mounted) return;
      setState(() {
        for (final it in items) {
          if (!allowed(it.itemType)) continue;
          final owned = inv[it.id] ?? 0;
          final free = it.freePerGame;
          final budget = (it.perGameLimit - free).clamp(0, it.perGameLimit);
          final o = owned < budget ? owned : budget;
          switch (it.itemType) {
            case 'shuffle':
              _shuffleItem = it;
              _shuffleFree = free;
              _shuffleOwned = o;
            case 'hammer':
              _hammerItem = it;
              _hammerFree = free;
              _hammerOwned = o;
            case 'hint':
              _hintItem = it;
              _hintFree = free;
              _hintOwned = o;
          }
        }
      });
    } catch (e) {
      // 载入失败不影响对局
    }
  }

  /// 死局处理器（引擎 stalemateHandler 回调）：
  ///
  /// 有洗牌券 → 弹「使用洗牌 / 去商城 / 放弃对局」；无券 → 弹「去商城
  /// 购买 / 放弃对局」。选择商城则跳转购买，**返回后对局状态保持**
  /// （引擎位于下层路由未被销毁），刷新库存后重新进入询问——购买不自动
  /// 使用，需再次确认消耗（用户拍板的独立消耗流程）。返回 true = 已处理
  /// （对局继续），false = 判负结算。
  Future<bool> _handleStalemate() async {
    while (true) {
      final available =
          _shuffleItem != null && (_shuffleFree + _shuffleOwned) > 0;
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('无可消组合'),
            content: Text(available
                ? '盘面已无可消交换。使用洗牌卡重排盘面（特殊糖保留原位），或前往道具商城补货。'
                : '盘面已无可消交换，且没有洗牌卡。可前往道具商城购买，或放弃本局。'),
            actions: <Widget>[
              if (available)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'use'),
                  child: Text(_shuffleFree > 0
                      ? '使用洗牌（免费剩 $_shuffleFree 次）'
                      : '使用洗牌（库存剩 $_shuffleOwned 张）'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'shop'),
                child: const Text('道具商城'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'quit'),
                child: const Text('放弃对局'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'use') {
        // 独立确认消耗流程：弹窗确认后才扣券执行
        final confirm = await _confirmConsumeShuffle();
        if (confirm != true) continue; // 取消消耗 → 回到询问
        final ok = await _consumeShuffleAndApply();
        if (ok) return true;
        // 洗牌执行失败（200 次重排仍无解，概率极低）：券已消耗无法回退，
        // 判负闭环，避免「返回 true 但盘面仍死局」的卡死场景
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('洗牌失败，本局结束')),
          );
        }
        return false;
      }
      if (choice == 'shop') {
        // 跳转商城购买：push 保留下层路由，Flame 引擎与对局状态原样保留；
        // 返回后刷新库存，回到询问（购买后需单独确认消耗，不自动使用）
        if (!mounted) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameItemShopScreen(game: widget.game),
          ),
        );
        await _loadMatchProps();
        continue;
      }
      return false; // 放弃对局 / 未登录等异常
    }
  }

  /// 消耗前确认（独立消耗流程，购买后同样必须经过此步）。
  Future<bool> _confirmConsumeShuffle() async {
    final useFree = _shuffleFree > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使用洗牌卡？'),
        content: Text(
          useFree
              ? '确定要使用 1 次免费洗牌（剩余 $_shuffleFree 次）吗？重排后不保证立即出现消除机会以外的额外收益。'
              : '确定要消耗 1 张洗牌卡（库存剩余 $_shuffleOwned 张）吗？',
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
    return confirm == true;
  }

  /// 消耗洗牌并执行：先免费用完再消耗库存；执行成功才计数生效。
  Future<bool> _consumeShuffleAndApply() async {
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
    final applied = _game.doShuffle();
    if (applied) _syncPropsAfterUse();
    return applied;
  }

  /// 确认使用局部破坏（锤子）：确认即消耗，进入待命中（按钮选中高亮）——
  /// 下一次点击盘面格执行破坏；再次点击道具按钮可取消待命（券不退）。
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
              ? '确定要使用 1 次免费破坏（剩余 $_hammerFree 次）吗？确认后点击盘面任意一颗糖直接消除（特殊糖按效果引爆）。'
              : '确定要消耗 1 张破坏锤（库存剩余 $_hammerOwned 张）吗？确认后点击盘面任意一颗糖直接消除（特殊糖按效果引爆）。',
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
    _syncPropsAfterUse();
  }

  /// 确认使用提示卡：确认即消耗，高亮一组可消交换位置。
  Future<void> _confirmHint() async {
    if (_hintItem == null) return;
    if (_hintFree <= 0 && _hintOwned <= 0) return;
    final useFree = _hintFree > 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('使用提示卡？'),
        content: Text(
          useFree
              ? '确定要使用 1 次免费提示（剩余 $_hintFree 次）吗？将高亮一组可消交换的糖果。'
              : '确定要消耗 1 张提示卡（库存剩余 $_hintOwned 张）吗？将高亮一组可消交换的糖果。',
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
    if (_hintFree > 0) {
      if (mounted) setState(() => _hintFree -= 1);
    } else {
      final ok = await GameItemService.instance.consumeItem(_hintItem!.id);
      if (!ok) {
        if (mounted) setState(() => _hintOwned = 0);
        return;
      }
      if (mounted) setState(() => _hintOwned -= 1);
    }
    _game.highlightHint();
    _syncPropsAfterUse();
  }

  /// 道具消耗/购买后的库存同步（引擎状态在 smasher 等路径外不受影响）。
  void _syncPropsAfterUse() {
    if (mounted) setState(() {});
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
            GameAction(
              icon: Icons.refresh,
              label: '重新开始',
              primary: true,
              onPressed: widget.onRestart == null ? null : _confirmRestart,
            ),
          ],
          // 道具栏：独立一行，渲染于主控制栏（重新开始）上方；
          // 渲染与否由 game_items.enabled + level.config.propUnlock 数据驱动
          propActions: <GameAction>[
            if (_hintItem != null)
              GameAction(
                // 道具图标口子：icon 字段暂用内置 Material icon，
                // 统一设计图标文件后按 games.icon 机制接入文件资产
                icon: Icons.lightbulb_outline,
                label: '提示',
                badge: '${_hintFree + _hintOwned}',
                extraTag: _hintFree > 0 ? '免$_hintFree' : null,
                onPressed: (_hintFree + _hintOwned) > 0 ? _confirmHint : null,
              ),
            if (_hammerItem != null)
              GameAction(
                icon: Icons.construction_outlined,
                label: _game.smashArmed ? '点击目标' : '破坏',
                badge: '${_hammerFree + _hammerOwned}',
                extraTag: _hammerFree > 0 ? '免$_hammerFree' : null,
                selected: _game.smashArmed,
                onPressed: (_hammerFree + _hammerOwned) > 0
                    ? () {
                        // 待命中再次点击 = 取消（券不退，库存已扣）
                        if (_game.smashArmed) {
                          _game.smashArmed = false;
                          _syncPropsAfterUse();
                          return;
                        }
                        _confirmHammer();
                      }
                    : null,
              ),
            if (_shuffleItem != null)
              GameAction(
                icon: Icons.shuffle_outlined,
                label: '洗牌',
                badge: '${_shuffleFree + _shuffleOwned}',
                extraTag: _shuffleFree > 0 ? '免$_shuffleFree' : null,
                onPressed: (_shuffleFree + _shuffleOwned) > 0
                    ? () async {
                        // 即时入口也走独立确认消耗流程（与死局路径一致）
                        if (await _confirmConsumeShuffle()) {
                          final ok = await _consumeShuffleAndApply();
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('洗牌失败，请重试')),
                            );
                          }
                        }
                      }
                    : null,
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
