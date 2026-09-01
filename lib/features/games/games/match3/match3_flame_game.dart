import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import 'candy_component.dart';
import 'match3_objective.dart';
import 'match3_overlays.dart';

/// 消消乐一次连线（用于生成特殊糖与消除判定）
class _Run {
  final String orient;
  final List<(int, int)> cells;
  _Run(this.orient, this.cells);
}

/// 消消乐（Flame 引擎 · 成熟手感版）
///
/// - 自绘卡通糖块（6 种形状+颜色），条纹/彩爆/包装特殊糖。
/// - 4 连→条纹糖（清整行/列）；5 连→彩爆（清同色）；L/T→包装糖（清 3×3）。
/// - **6 种关卡目标**由 [Match3Objective] 驱动（计分/消除/收集/破冰/限时/Boss），
///   引擎只负责盘面与消除，目标判定与进度全部交给状态机。
/// - 连击倍率；消除/下落/交换全动画 + 音效。
class Match3FlameGame extends FlameGame with TapCallbacks {
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 横向留出 _padX 左右边距；网格在剩余空间内居中，纵向居中。
    _cell = ((size.x - 2 * _padX) / cols).clamp(0, size.y / rows);
    _offsetX = _padX + (size.x - 2 * _padX - cols * _cell) / 2;
    _offsetY = (size.y - rows * _cell) / 2;
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF26263A),
    );
    if (!_loaded) return; // 盘面/目标层尚未就绪
    // 白色圆角格底：糖块画在白底上，与深色底板形成强对比，
    // 边缘清晰不发虚（缓解「看久了眼睛不舒服」）
    final cellPaint = Paint()..color = const Color(0xFFFFFFFF);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              _offsetX + c * _cell + _cell * 0.03,
              _offsetY + r * _cell + _cell * 0.03,
              _cell * 0.94,
              _cell * 0.94,
            ),
            Radius.circular(_cell * 0.18),
          ),
          cellPaint,
        );
      }
    }
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
      canvas.drawRect(
        Rect.fromLTWH(_offsetX + _selectedC! * _cell,
            _offsetY + _selectedR! * _cell, _cell, _cell),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _cell * 0.06,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
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

  void _newBoard() {
    grid = List.generate(rows, (_) => List<Candy?>.filled(cols, null));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        int t;
        do {
          t = _rng.nextInt(_palette.length);
        } while ((c >= 2 &&
                grid[r][c - 1]?.type == t &&
                grid[r][c - 2]?.type == t) ||
            (r >= 2 &&
                grid[r - 1][c]?.type == t &&
                grid[r - 2][c]?.type == t));
        grid[r][c] = Candy(
            t, r, c, _offsetX + c * _cell, _offsetY + r * _cell);
      }
    }
  }

  // ---------- 连线检测 ----------

  List<_Run> _findRuns() {
    final runs = <_Run>[];
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        final t = grid[r][c]?.type;
        if (t == null) {
          c++;
          continue;
        }
        var end = c;
        while (end + 1 < cols && grid[r][end + 1]?.type == t) {
          end++;
        }
        final len = end - c + 1;
        if (len >= 3) {
          final cells = <(int, int)>[];
          for (var k = c; k <= end; k++) {
            cells.add((r, k));
          }
          runs.add(_Run('h', cells));
        }
        c = end + 1;
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        final t = grid[r][c]?.type;
        if (t == null) {
          r++;
          continue;
        }
        var end = r;
        while (end + 1 < rows && grid[end + 1][c]?.type == t) {
          end++;
        }
        final len = end - r + 1;
        if (len >= 3) {
          final cells = <(int, int)>[];
          for (var k = r; k <= end; k++) {
            cells.add((k, c));
          }
          runs.add(_Run('v', cells));
        }
        r = end + 1;
      }
    }
    return runs;
  }

  // ---------- 交换 ----------

  @override
  void onTapUp(TapUpEvent event) {
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
      if (_findRuns().isEmpty) {
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
    final runs = _findRuns();
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

    for (final cell in toClear) {
      final cand = grid[cell.$1][cell.$2];
      if (cand != null) cand.dying = true;
    }
    for (final e in created.entries) {
      final cand = grid[e.key.$1][e.key.$2];
      if (cand != null) cand.special = e.value;
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
      for (final ac in _effectCells(cand, cell.$1, cell.$2)) {
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

  List<(int, int)> _effectCells(Candy cand, int r, int c) {
    switch (cand.special) {
      case 'row':
        return [for (var cc = 0; cc < cols; cc++) (r, cc)];
      case 'col':
        return [for (var rr = 0; rr < rows; rr++) (rr, c)];
      case 'wrap':
        final list = <(int, int)>[];
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            final rr = r + dr;
            final cc = c + dc;
            if (rr >= 0 && rr < rows && cc >= 0 && cc < cols) {
              list.add((rr, cc));
            }
          }
        }
        return list;
      case 'bomb':
        final list = <(int, int)>[];
        for (var rr = 0; rr < rows; rr++) {
          for (var cc = 0; cc < cols; cc++) {
            final o = grid[rr][cc];
            if (o != null && o.type == cand.type) list.add((rr, cc));
          }
        }
        return list;
      default:
        return [];
    }
  }

  void _removeCleared(Set<(int, int)> toClear) {
    for (final cell in toClear) {
      grid[cell.$1][cell.$2] = null;
    }
  }

  void _applyGravity() {
    for (var c = 0; c < cols; c++) {
      final remain = <Candy>[];
      for (var r = 0; r < rows; r++) {
        final cand = grid[r][c];
        if (cand != null) {
          remain.add(cand);
          grid[r][c] = null;
        }
      }
      var idx = rows - 1;
      for (var k = remain.length - 1; k >= 0; k--) {
        final cand = remain[k];
        cand.row = idx;
        grid[idx][c] = cand;
        idx--;
      }
      var spawnY = -1;
      for (var r = idx; r >= 0; r--) {
        final cand = Candy(
          _rng.nextInt(_palette.length),
          r,
          c,
          _offsetX + c * _cell,
          _offsetY + spawnY * _cell,
        );
        spawnY--;
        grid[r][c] = cand;
      }
    }
  }

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
    onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{'score': score, 'duration_ms': elapsed},
      durationMs: elapsed,
    ));
  }
}
