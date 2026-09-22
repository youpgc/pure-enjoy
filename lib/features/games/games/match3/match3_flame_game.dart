library match3_flame_game;

import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game_play_helpers.dart';
import '../../services/game_reward_picker.dart';
import '../../shared/game_audio.dart';
import 'candy_component.dart';
import 'match3_effects.dart';
import 'match3_objective.dart';
import 'match3_overlays.dart';
import 'match3_runs.dart';
import 'match3_swipe.dart';

// 【文件拆分 2026-09-22】单文件超 500 行红线，按 part + extension 分片（逻辑零变更）：
// match3_props_engine.dart（六道具引擎侧）、match3_flame_resolve.dart（连锁消除与结算）。
part 'match3_props_engine.dart';
part 'match3_flame_resolve.dart';

/// 消消乐（Flame 引擎 · 成熟手感版）
///
/// - 自绘卡通糖块（6 种形状+颜色），条纹/彩爆/包装特殊糖。
/// - 4 连→条纹糖（清整行/列）；5 连→彩爆（清同色）；L/T→包装糖（清 3×3）。
/// - **6 种关卡目标**由 [Match3Objective] 驱动（计分/消除/收集/破冰/限时/Boss），
///   引擎只负责盘面与消除，目标判定与进度全部交给状态机。
/// - 连击倍率；消除/下落/交换全动画 + 音效。
/// - 双交互：点选两格交换 + 按住某格朝相邻格滑动交换（按**起始格**判定）。
/// - 特效层 [Match3Effects]：碎片迸发、条纹光束、冲击波、连击飘字。
class Match3FlameGame extends FlameGame
    with TapCallbacks, MultiTouchDragDetector, Match3SwipeMixin {
  final void Function(GamePlayOutcome) onFinished;

  /// 关卡目标状态机（模式、进度、达成判定、HUD 数据）
  final Match3Objective objective;

  /// HUD 变更信号：每次分数/步数/目标进度变化自增，Flutter 层据此重建信息条
  final ValueNotifier<int> hudTick;

  final int rows;
  final int cols;

  List<List<Candy?>> grid = <List<Candy?>>[];
  int score = 0;
  int movesLeft = 0;
  int combo = 1;

  /// 本局最高连击（达到过的最大连锁波数，结算 max_combo 维度）
  int maxCombo = 0;

  /// 本局单次操作最高分（一次交换的整段连锁累计，结算 max_single 维度）
  int maxSingle = 0;

  /// 本局累计消除方块数（含连锁与道具引爆，结算 cleared_blocks 维度，
  /// 供「糖块富豪」累计型成就计数 GameCumulativeService）
  int _clearedBlocks = 0;

  /// 当前交换动作的累计得分（连锁结束即计入 maxSingle）
  int _moveScore = 0;

  final DateTime _startTime = DateTime.now();
  bool _over = false;
  bool _busy = false;
  bool _loaded = false;

  /// 残局处理器（宿主页注入，道具商城扩展预留，2026-09-09）：
  /// 死局（无可消交换）时调用，返回 true 表示已处理（如用洗牌券洗牌），
  /// false 则判负结算。未注入（null）时直接判负——当前默认行为。
  Future<bool> Function()? stalemateHandler;

  /// 局部破坏（锤子）待命中：宿主道具按钮确认后置 true，
  /// 玩家下一次点击盘面格执行 [smashAt]（道具商城扩展预留）。
  bool smashArmed = false;

  /// 强制交换待命中：第一次点击选中糖（hintT 高亮标记），第二次点击
  /// 相邻糖执行 [forceSwap]（无视三连规则；道具商城扩展）。
  bool forceSwapArmed = false;
  int? _fsR;
  int? _fsC;

  /// 魔法棒待命中：下一次点击盘面格执行 [magicAt]（道具商城扩展）。
  bool magicArmed = false;

  /// 两段式道具（hammer/force_swap/magic_wand）**执行成功**回调：
  /// 宿主在此真正扣减库存（确认弹窗仅做可用性预检，延迟到执行成功才扣，
  /// 杜绝「确认后未执行券已扣」的闭环漏洞）。参数为道具 item_type。
  void Function(String itemType)? onPropExecuted;

  /// 道具 armed 状态变化通知（宿主刷新按钮选中高亮；armed 被盘面
  /// 操作消费或取消时触发）。
  VoidCallback? onPropStateChanged;

  /// 取消全部待命态（宿主道具按钮再次点击取消；不退券——尚未消耗）。
  void cancelPropArming() {
    smashArmed = false;
    forceSwapArmed = false;
    magicArmed = false;
    if (_fsR != null) {
      grid[_fsR!][_fsC!]?.hintT = 0;
      _fsR = _fsC = null;
    }
  }

  int? _selectedR;
  int? _selectedC;

  final Match3Effects effects = Match3Effects();

  late double _cell;
  /// 网格相对画布左上角的偏移（画布非正方形时居中网格，背景填满留白）
  late double _offsetX;
  late double _offsetY;
  final Random _rng = Random();

  /// 方块类型数（难度配置项）：config['types']，钳制 3..6；决定单局渲染几种糖果
  final int typeCount;

  late final List<Color> _palette = <Color>[
    const Color(0xFFEF5350),
    const Color(0xFF42A5F5),
    const Color(0xFF66BB6A),
    const Color(0xFFFFEE58),
    const Color(0xFFAB47BC),
    const Color(0xFFFFA726),
  ];

  static const Duration _anim = Duration(milliseconds: 220);

  /// 消除（弹出+淡出）动画时长（秒），与 [_anim] 对齐，确保方块淡出后再移除。
  static const double _dieDur = 0.38;

  /// 棋盘左右留白（逻辑像素），让糖块不贴边、视觉更透气（2~4px）。
  static const double _padX = 3.0;

  Match3FlameGame({
    required this.onFinished,
    required this.objective,
    required this.hudTick,
    this.rows = 8,
    this.cols = 8,
    this.typeCount = 6,
  });

  // ---------- 滑动手势（Match3SwipeMixin 接线）----------

  @override
  (int, int)? cellAt(double x, double y) {
    final c = ((x - _offsetX) / _cell).floor();
    final r = ((y - _offsetY) / _cell).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return (r, c);
  }

  @override
  bool get canInteract => _loaded && !_busy && !_over;

  /// 滑动即交换：目标格越界则忽略，并清掉点选态避免与点选标记冲突。
  @override
  void onSwipe(int r, int c, int dr, int dc) {
    // 任一道具待命中：滑动手势不触发交换也不缓冲，留给点击执行道具目标
    if (smashArmed || forceSwapArmed || magicArmed) return;
    // 输入缓冲（2026-09-14 审查修复）：动画/锁定期开始的滑动不再整条丢弃，
    // 记录待执行，_busy 解除瞬间在 update() 里补执行（主流三消标准做法）。
    // 后到的滑动覆盖先前的缓冲（最新意图优先）。
    if (!canInteract) {
      _pendingSwipe = (r, c, dr, dc);
      return;
    }
    final tr = r + dr;
    final tc = c + dc;
    if (tr < 0 || tr >= rows || tc < 0 || tc >= cols) return;
    _selectedR = null;
    _selectedC = null;
    _trySwap(r, c, tr, tc);
  }

  /// 待执行滑动缓冲（起始行, 起始列, 行增量, 列增量）；null = 无
  (int, int, int, int)? _pendingSwipe;

  /// 每帧检查：锁定期结束后补执行缓冲的滑动。
  /// 执行前复验目标格仍有效（动画期间盘面可能已变化）。
  void _flushPendingSwipe() {
    final pending = _pendingSwipe;
    if (pending == null || !canInteract) return;
    _pendingSwipe = null;
    final (r, c, dr, dc) = pending;
    final tr = r + dr;
    final tc = c + dc;
    if (tr < 0 || tr >= rows || tc < 0 || tc >= cols) return;
    if (grid[r][c] == null || grid[tr][tc] == null) return;
    _selectedR = null;
    _selectedC = null;
    _trySwap(r, c, tr, tc);
  }

  Offset _cellCenter(int r, int c) => Offset(
        _offsetX + c * _cell + _cell / 2,
        _offsetY + r * _cell + _cell / 2,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 预加载动物头像 SVG（异步；未就绪帧先画纯色兜底圆，Flame 每帧重绘自动补）
    unawaited(precacheCandyPictures());
    // 横向留出 _padX 左右边距；网格在剩余空间内居中，纵向居中。
    _recomputeLayout();
    _newBoard();
    objective.initBoard(_rng);
    movesLeft = objective.steps;
    _syncHud();
    _loaded = true;
  }

  /// 上次 HUD 时钟显示秒（秒级节流：mm:ss 展示只在整秒变化时重建）
  int _lastClockSecond = -1;

  /// 把引擎侧的分数/步数同步进目标状态机，并通知 Flutter 层刷新 HUD。
  ///
  /// 通知统一调度：Flame 首帧 update 发生在 GameWidget build 期间，同步
  /// notifyListeners 会触发「setState during build」断言（2026-09-07）——
  /// 处于 build 阶段时推迟到帧末，其余直接通知。
  void _syncHud() {
    objective.score = score;
    objective.movesLeft = movesLeft;
    notifyHud();
  }

  void notifyHud() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // build 阶段：推迟到帧末再通知
      SchedulerBinding.instance.addPostFrameCallback((_) => hudTick.value++);
    } else {
      hudTick.value++;
    }
  }

  /// 加时卡：限时模式追加秒数（由游戏外壳在消耗 add_time 道具后调用）。
  void addTime(double seconds) {
    if (_over || !objective.isTimed) return;
    objective.secondsLeft += seconds;
    _syncHud();
  }

  /// 画布尺寸变化（首屏布局完成 / 旋转 / 安全区变化 / 父容器尺寸修正）时
  /// 同步网格布局。若不跟随，cellAt 仍用旧 size 算出的 _cell/_offset，导致
  /// 点触与滑动命中的格子相对实际盘面发生偏移（「滑动选不中正确方块」）。
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _recomputeLayout();
  }

  void _recomputeLayout() {
    if (size.x <= 0 || size.y <= 0) return;
    _cell = ((size.x - 2 * _padX) / cols).clamp(0, size.y / rows);
    _offsetX = _padX + (size.x - 2 * _padX - cols * _cell) / 2;
    _offsetY = (size.y - rows * _cell) / 2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF26263A),
    );
    if (!_loaded) return; // 盘面/目标层尚未就绪
    Match3Overlays.drawGrid(canvas, _offsetX, _offsetY, _cell, rows, cols);
    // 果冻底层（在糖果下方）
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (objective.jelly[r][c] > 0) {
          Match3Overlays.drawJelly(
              canvas, _offsetX + c * _cell, _offsetY + r * _cell, _cell);
        }
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cand = grid[r][c];
        if (cand != null) drawCandy(canvas, cand, _cell, _palette[cand.type]);
      }
    }
    // 特殊糖描边环（2026-09-10 定版方案 A「霓虹描边环」：贴图标圆形底板外缘，
    // 画在糖果上方——格底层方案会被放大后占满整格的图标完全遮挡）
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cand = grid[r][c];
        if (cand == null || cand.special.isEmpty) continue;
        final alpha =
            cand.dying ? cand.dyingAlpha.clamp(0.0, 1.0) : 1.0;
        Match3Overlays.drawSpecialRing(
          canvas,
          _offsetX + c * _cell,
          _offsetY + r * _cell,
          _cell,
          cand.special,
          alpha,
        );
      }
    }
    // 冰封盖层（在糖果上方）
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final lv = objective.ice[r][c];
        if (lv > 0) {
          Match3Overlays.drawIce(
              canvas, _offsetX + c * _cell, _offsetY + r * _cell, _cell, lv);
        }
      }
    }
    if (_selectedR != null && _selectedC != null) {
      Match3Overlays.drawSelection(
          canvas, _offsetX, _offsetY, _cell, _selectedR!, _selectedC!);
    }
    // 特效层置顶：碎片/光束/冲击波/飘字画在所有糖块之上
    effects.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    effects.update(dt);
    // 锁定期结束后补执行缓冲的滑动（输入缓冲，见 onSwipe 注释）
    _flushPendingSwipe();
    // 限时模式：倒计时推进，归零即结算
    if (objective.isTimed && _loaded && !_over) {
      objective.secondsLeft -= dt;
      if (objective.secondsLeft <= 0) {
        objective.secondsLeft = 0;
        _finishByObjective();
      } else {
        // mm:ss 展示秒级粒度：仅整秒变化时通知（避免每帧 60 次无效重建）
        final sec = objective.secondsLeft.ceil();
        if (sec != _lastClockSecond) {
          _lastClockSecond = sec;
          notifyHud();
        }
      }
    }
    // 降低缓动速率（14→8），下落/交换更舒缓、过渡更自然，不再「生硬」。
    final k = min(1.0, dt * 8);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cand = grid[r][c];
        if (cand == null) continue;
        final tx = _offsetX + cand.col * _cell;
        final ty = _offsetY + cand.row * _cell;
        cand.px += (tx - cand.px) * k;
        cand.py += (ty - cand.py) * k;
        if (cand.hintT > 0) cand.hintT = max(0.0, cand.hintT - dt);
        if (cand.dying) {
          // 弹出曲线：先轻微放大(1→1.25)再缩小归零，配合透明度淡出，手感更柔和。
          cand.dyingT += dt;
          final p = (cand.dyingT / _dieDur).clamp(0.0, 1.0);
          cand.scale = p < 0.3
              ? 1.0 + (p / 0.3) * 0.25
              : 1.25 * (1 - (p - 0.3) / 0.7);
          cand.dyingAlpha = 1.0 - p;
        } else {
          cand.scale += (1.0 - cand.scale) * k;
        }
      }
    }
  }

  // ---------- 棋盘生成 ----------

  /// 生成初始棋盘（盘面运算下沉至 match3_runs.newBoard）
  void _newBoard() {
    // 开局生成后校验残局：newBoard 只保证无初始连线、不保证有解，
    // 死局开局直接判负全然是 RNG 惩罚，故重生成直至有解（上限 50 次，
    // 6 色 56 格下首次即有解的概率极高，循环仅为理论兜底）
    for (var attempt = 0; attempt < 50; attempt++) {
      grid = newBoard(
        rows: rows,
        cols: cols,
        nextType: () => _rng.nextInt(typeCount.clamp(3, _palette.length)),
        offsetX: _offsetX,
        offsetY: _offsetY,
        cell: _cell,
        make: (t, r, c, x, y) => Candy(t, r, c, x, y),
      );
      if (hasAnyMove(grid, rows, cols)) return;
    }
  }

  // ---------- 交换 ----------

  @override
  void onTapUp(TapUpEvent event) {
    // 滑动尾部在部分机型会补发 tap，防误触窗口内直接忽略
    if (recentSwipe) return;
    if (!_loaded || _busy || _over) return;
    final c = ((event.canvasPosition.x - _offsetX) / _cell).floor();
    final r = ((event.canvasPosition.y - _offsetY) / _cell).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;

    // 道具待命中：本次点击执行对应道具目标（道具商城扩展）
    if (smashArmed) {
      if (grid[r][c] == null) return; // 空格无效，保持待命重选
      smashArmed = false;
      smashAt(r, c);
      onPropExecuted?.call('hammer');
      onPropStateChanged?.call();
      return;
    }
    if (forceSwapArmed) {
      _handleForceSwapTap(r, c);
      return;
    }
    if (magicArmed) {
      if (magicAt(r, c)) {
        magicArmed = false;
        onPropExecuted?.call('magic_wand');
        onPropStateChanged?.call();
      }
      return;
    }

    if (_selectedR == null) {
      _selectedR = r;
      _selectedC = c;
      return;
    }
    final sr = _selectedR!;
    final sc = _selectedC!;
    _selectedR = null;
    _selectedC = null;
    if (sr == r && sc == c) return;
    final adjacent = (sr - r).abs() + (sc - c).abs() == 1;
    if (!adjacent) return;
    _trySwap(sr, sc, r, c);
  }

  void _trySwap(int r1, int c1, int r2, int c2) {
    final a = grid[r1][c1];
    final b = grid[r2][c2];
    if (a == null || b == null) return;
    grid[r1][c1] = b;
    grid[r2][c2] = a;
    a.row = r2;
    a.col = c2;
    b.row = r1;
    b.col = c1;
    _busy = true;
    GameAudio.instance.select();
    GameAudio.instance.haptic(GameHaptic.light);

    Future.delayed(_anim, () {
      if (!isMounted) return;
      if (findRuns(grid, rows, cols).isEmpty) {
        grid[r1][c1] = a;
        grid[r2][c2] = b;
        a.row = r1;
        a.col = c1;
        b.row = r2;
        b.col = c2;
        GameAudio.instance.tap();
        Future.delayed(_anim, () {
          if (isMounted) _busy = false;
        });
      } else {
        // 全模式统计已用步数（结算 moves 维度）；限步模式同步递减剩余，
        // 限时/不限步（steps<=0）不递减
        objective.movesUsed++;
        if (!objective.isTimed && objective.steps > 0) movesLeft--;
        _syncHud();
        combo = 1;
        _moveScore = 0;
        _resolveCascade(r1, c1, r2, c2);
      }
    });
  }

}
