import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import 'candy_component.dart';
import 'match3_effects.dart';
import 'match3_objective.dart';
import 'match3_overlays.dart';
import 'match3_runs.dart';
import 'match3_swipe.dart';

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
    with TapCallbacks, PanDetector, Match3SwipeMixin {
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

  /// 局部破坏（锤子）待命中：宿主道具按钮确认消耗后置 true，
  /// 玩家下一次点击盘面格执行 [smashAt]（道具商城扩展预留）。
  bool smashArmed = false;

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
    // 局部破坏（锤子）待命中：滑动手势不触发交换，留给点击执行破坏
    if (smashArmed) return;
    final tr = r + dr;
    final tc = c + dc;
    if (tr < 0 || tr >= rows || tc < 0 || tc >= cols) return;
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

    // 局部破坏（锤子）待命中：本次点击即执行破坏（道具商城扩展预留）
    if (smashArmed) {
      smashArmed = false;
      smashAt(r, c);
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

  // ---------- 连锁消除 ----------

  void _resolveCascade(int sr1, int sc1, int sr2, int sc2, [int depth = 0]) {
    if (depth > 200) {
      _busy = false;
      return;
    }
    final runs = findRuns(grid, rows, cols);
    if (runs.isEmpty) {
      // 本步连锁结束：单次操作得分计入最高纪录
      if (_moveScore > maxSingle) maxSingle = _moveScore;
      _moveScore = 0;
      _syncHud();
      // 目标达成即刻通关；资源（步数/时间）耗尽则按目标判定成败；
      // 残局判定：盘面无任何可消交换 → 交残局处理器（洗牌道具等，未注入
      // 则判负，用户 2026-09-09 拍板 B 方案）
      if (objective.achieved || objective.exhausted) {
        _finishByObjective();
      } else if (!hasAnyMove(grid, rows, cols)) {
        final handler = stalemateHandler;
        if (handler == null) {
          _finishByObjective(failReason: '无可消组合，对局结束');
        } else {
          // 释放操作锁：洗牌路径 doShuffle 需要可执行；处理器弹窗为模态，
          // 期间玩家触不到盘面，拒绝处理后立即判负
          _busy = false;
          handler().then((handled) {
            if (!handled && isMounted && !_over) {
              _finishByObjective(failReason: '无可消组合，对局结束');
            }
          });
        }
      } else {
        _busy = false;
      }
      return;
    }

    final toClear = <(int, int)>{};
    final created = <(int, int), String>{};
    final swapped = {(sr1, sc1), (sr2, sc2)};

    for (final run in runs) {
      String? sp;
      if (run.cells.length >= 5) {
        sp = 'bomb';
      } else if (run.cells.length == 4) {
        sp = run.orient == 'h' ? 'row' : 'col';
      }
      for (final cell in run.cells) {
        toClear.add(cell);
      }
      if (sp != null) {
        final spot = run.cells.firstWhere(
          (cell) => swapped.contains(cell),
          orElse: () => run.cells[run.cells.length ~/ 2],
        );
        // 目标位已是特殊糖（道具方块）：优先消耗旧道具（留在 toClear 触发
        // 引爆），不覆盖生成新道具——防止旧道具免爆换皮（2026-09-07）
        final existing = grid[spot.$1][spot.$2];
        if (existing == null || existing.special.isEmpty) {
          created[spot] = sp;
        }
      }
    }

    // L/T 交叉 → 包装糖
    final hCells = <(int, int)>{};
    final vCells = <(int, int)>{};
    for (final run in runs) {
      for (final cell in run.cells) {
        if (run.orient == 'h') {
          hCells.add(cell);
        } else {
          vCells.add(cell);
        }
      }
    }
    for (final cell in hCells) {
      if (!vCells.contains(cell)) continue;
      // 目标位已是特殊糖：不覆盖生成，按普通消除引爆旧道具
      final existing = grid[cell.$1][cell.$2];
      if (existing == null || existing.special.isEmpty) {
        created[cell] = 'wrap';
      }
    }

    for (final cell in created.keys) {
      toClear.remove(cell);
    }
    _applySpecials(toClear, created);

    score += toClear.length * 10 * combo;
    _moveScore += toClear.length * 10 * combo;
    if (combo > maxCombo) maxCombo = combo;

    // 目标进度累计（果冻清除 / 冰块削层 / 收集计数 / Boss 掉血）
    final clearedCells = <ClearedCell>[];
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      clearedCells.add(ClearedCell(
        cell.$1,
        cell.$2,
        cand.type,
        special: cand.special.isNotEmpty,
      ));
    }
    objective.onCleared(clearedCells);
    _syncHud();

    GameAudio.instance.match();
    GameAudio.instance.haptic(GameHaptic.medium);

    // 消除特效：碎片迸发（特殊糖加倍）+ 特殊糖生成冲击波 + 连击飘字
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      cand.dying = true;
      final special = cand.special.isNotEmpty;
      final center = _cellCenter(cell.$1, cell.$2);
      effects.burst(
        center: center,
        color: _palette[cand.type],
        cell: _cell,
        power: special ? 1.8 : 1.0,
      );
      if (!special) continue;
      effects.shock(
          center: center, radius: _cell * 1.6, color: _palette[cand.type]);
      // 条纹糖：沿整行/整列射出光带
      final horiz = cand.special == 'row';
      if (horiz || cand.special == 'col') {
        effects.beam(
          horizontal: horiz,
          centerAlong: (horiz ? size.x : size.y) / 2,
          centerCross: horiz ? center.dy : center.dx,
          length: horiz ? size.x : size.y,
          thickness: _cell * 0.5,
          color: _palette[cand.type],
        );
      }
    }
    for (final e in created.entries) {
      final cand = grid[e.key.$1][e.key.$2];
      if (cand != null) cand.special = e.value;
      effects.shock(
        center: _cellCenter(e.key.$1, e.key.$2),
        radius: _cell * 1.2,
        color: Colors.white,
      );
    }
    if (combo >= 2) {
      effects.float(
        center: Offset(size.x / 2, _offsetY + rows * _cell * 0.42),
        text: '连击 ×$combo',
        color: const Color(0xFFFFB300),
        fontSize: _cell * 0.7,
      );
    }

    combo++;
    Future.delayed(_anim, () {
      if (!isMounted) return;
      _removeCleared(toClear);
      _applyGravity();
      Future.delayed(_anim, () => _resolveCascade(sr1, sc1, sr2, sc2, depth + 1));
    });
  }

  void _applySpecials(
    Set<(int, int)> toClear,
    Map<(int, int), String> created,
  ) {
    final queue = <(int, int)>[];
    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand != null && cand.special.isNotEmpty) queue.add(cell);
    }
    final handled = <(int, int)>{};
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      if (handled.contains(cell)) continue;
      handled.add(cell);
      final cand = grid[cell.$1][cell.$2];
      if (cand == null) continue;
      for (final ac in effectCells(cand, cell.$1, cell.$2, grid, rows, cols)) {
        if (created.containsKey(ac)) continue;
        if (toClear.add(ac)) {
          final o = grid[ac.$1][ac.$2];
          if (o != null && o.special.isNotEmpty && !handled.contains(ac)) {
            queue.add(ac);
          }
        }
      }
    }
  }

  void _removeCleared(Set<(int, int)> toClear) => removeCleared(grid, toClear);

  /// 重力下落 + 顶部补充（盘面运算下沉至 match3_runs.applyGravity）
  void _applyGravity() => applyGravity(
        grid: grid,
        rows: rows,
        cols: cols,
        offsetX: _offsetX,
        offsetY: _offsetY,
        cell: _cell,
        spawn: (r, c, x, y) =>
            Candy(_rng.nextInt(typeCount.clamp(3, _palette.length)), r, c, x, y),
      );

  // ---------- 道具能力（道具商城扩展预留，2026-09-09；入口开关见宿主页） ----------

  /// 洗牌：特殊糖原位保留，普通糖随机重排直至「无现成三连且有解」。
  ///
  /// 成功后糖果经 px/py 缓动自动滑到新格（无需额外动画）；失败（200 次
  /// 重排仍无解，极小概率）返回 false，盘面保持原状，由调用方回退处理。
  bool doShuffle() {
    if (_over || _busy) return false;
    if (!shuffleGrid(grid, rows, cols, _rng)) return false;
    _busy = true;
    GameAudio.instance.select();
    _syncHud();
    Future.delayed(_anim, () {
      if (isMounted) _busy = false;
    });
    return true;
  }

  /// 局部破坏（锤子）：直接清除指定格（特殊糖按效果引爆），目标进度/
  /// 得分/特效与普通消除同口径，随后下落补位并连锁检测。不计步数。
  void smashAt(int r, int c) {
    if (_over || _busy) return;
    final cand = grid[r][c];
    if (cand == null) return;
    _busy = true;
    final toClear = <(int, int)>{(r, c)};
    _applySpecials(toClear, const {});
    score += toClear.length * 10;
    final clearedCells = <ClearedCell>[];
    for (final cell in toClear) {
      final o = grid[cell.$1][cell.$2];
      if (o == null) continue;
      clearedCells.add(ClearedCell(
        cell.$1,
        cell.$2,
        o.type,
        special: o.special.isNotEmpty,
      ));
    }
    objective.onCleared(clearedCells);
    _syncHud();
    GameAudio.instance.match();
    GameAudio.instance.haptic(GameHaptic.medium);
    for (final cell in toClear) {
      final o = grid[cell.$1][cell.$2];
      if (o == null) continue;
      o.dying = true;
      effects.burst(
        center: _cellCenter(cell.$1, cell.$2),
        color: _palette[o.type],
        cell: _cell,
        power: o.special.isNotEmpty ? 1.8 : 1.0,
      );
    }
    combo = 1;
    Future.delayed(_anim, () {
      if (!isMounted) return;
      _removeCleared(toClear);
      _applyGravity();
      // (-1,-1,-1,-1)：swapped 空集——连锁特殊糖生成位置取 run 中位
      Future.delayed(_anim, () => _resolveCascade(-1, -1, -1, -1));
    });
  }

  /// 提示：随机高亮一组可消交换的两颗糖（各 2.5 秒脉动描边）。
  /// 无可消交换（死局）时飘字提示，不产生高亮。
  void highlightHint() {
    if (_over || _busy) return;
    final moves = findAllMoves(grid, rows, cols);
    if (moves.isEmpty) {
      effects.float(
        center: Offset(size.x / 2, _offsetY + rows * _cell * 0.42),
        text: '无可消组合',
        color: Colors.white,
        fontSize: _cell * 0.6,
      );
      return;
    }
    final (r1, c1, r2, c2) = moves[_rng.nextInt(moves.length)];
    grid[r1][c1]?.hintT = 2.5;
    grid[r2][c2]?.hintT = 2.5;
  }

  /// 按当前模式的目标判定通关/失败并结算。
  ///
  /// [failReason] 非残局外的自定义失败原因（当前仅残局判负传入），
  /// 透传至结算弹窗展示（null 时弹窗显示默认失败文案）。
  void _finishByObjective({String? failReason}) {
    if (_over) return;
    _over = true;
    _syncHud();
    final cleared = objective.achieved;
    if (cleared) {
      GameAudio.instance.win();
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    // 已用步数：全模式由引擎累计（限时此前恒 0 的根因修复）
    final usedMoves = objective.movesUsed;
    // 限时等路径可能跳过连锁收尾分支：结算前补记单次最高分
    if (_moveScore > maxSingle) maxSingle = _moveScore;
    _moveScore = 0;
    onFinished(GamePlayOutcome(
      cleared: cleared,
      reason: failReason,
      values: <String, num>{
        'score': score,
        'duration_ms': elapsed,
        'moves': usedMoves,
        'max_combo': maxCombo,
        'max_single': maxSingle,
      },
      durationMs: elapsed,
    ));
  }
}
