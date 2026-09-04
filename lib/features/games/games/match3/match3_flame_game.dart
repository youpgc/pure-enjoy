import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

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

  final DateTime _startTime = DateTime.now();
  bool _over = false;
  bool _busy = false;
  bool _loaded = false;

  int? _selectedR;
  int? _selectedC;

  final Match3Effects effects = Match3Effects();

  late double _cell;
  /// 网格相对画布左上角的偏移（画布非正方形时居中网格，背景填满留白）
  late double _offsetX;
  late double _offsetY;
  final Random _rng = Random();

  final List<Color> _palette = <Color>[
    const Color(0xFFEF5350),
    const Color(0xFF42A5F5),
    const Color(0xFF66BB6A),
    const Color(0xFFFFEE58),
    const Color(0xFFAB47BC),
    const Color(0xFFFFA726),
  ];

  static const Duration _anim = Duration(milliseconds: 220);

  /// 消除（弹出+淡出）动画时长（秒），与 [_anim] 对齐，确保方块淡出后再移除。
  static const double _dieDur = 0.22;

  /// 棋盘左右留白（逻辑像素），让糖块不贴边、视觉更透气（2~4px）。
  static const double _padX = 3.0;

  Match3FlameGame({
    required this.onFinished,
    required this.objective,
    required this.hudTick,
    this.rows = 8,
    this.cols = 8,
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

  /// 把引擎侧的分数/步数同步进目标状态机，并通知 Flutter 层刷新 HUD
  void _syncHud() {
    objective.score = score;
    objective.movesLeft = movesLeft;
    hudTick.value++;
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
        hudTick.value++;
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
    grid = newBoard(
      rows: rows,
      cols: cols,
      nextType: () => _rng.nextInt(_palette.length),
      offsetX: _offsetX,
      offsetY: _offsetY,
      cell: _cell,
      make: (t, r, c, x, y) => Candy(t, r, c, x, y),
    );
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
        // 限时模式不限步数，仅倒计时约束
        if (!objective.isTimed) movesLeft--;
        _syncHud();
        combo = 1;
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
      _syncHud();
      // 目标达成即刻通关；资源（步数/时间）耗尽则按目标判定成败
      if (objective.achieved || objective.exhausted) {
        _finishByObjective();
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
        created[spot] = sp;
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
      if (vCells.contains(cell)) created[cell] = 'wrap';
    }

    for (final cell in created.keys) {
      toClear.remove(cell);
    }
    _applySpecials(toClear, created);

    score += toClear.length * 10 * combo;

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
            Candy(_rng.nextInt(_palette.length), r, c, x, y),
      );

  /// 按当前模式的目标判定通关/失败并结算
  void _finishByObjective() {
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
    // 已用步数 = 配置总步数 - 剩余步数（钳制到 [0, steps]，失败临界 movesLeft 可能为 0/负）
    final usedMoves = (objective.steps - objective.movesLeft).clamp(0, objective.steps);
    onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{
        'score': score,
        'duration_ms': elapsed,
        'moves': usedMoves,
      },
      durationMs: elapsed,
    ));
  }
}
