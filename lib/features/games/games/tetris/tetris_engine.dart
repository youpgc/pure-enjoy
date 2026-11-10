part of 'tetris_game.dart';

// 引擎核心（part of _TetrisGameState）：形状/SRS 踢墙/7-bag/重力/锁定/消行/计分。
// 纯逻辑与渲染分离——本文件不触碰 Widget，供 tetris_board/input 两个 part 消费。
// ignore_for_file: invalid_use_of_protected_member
// （part+extension 内调宿主 setState 属 analyzer 已知误报，g2048 同款处理）

/// 七种方块（索引即棋盘存色 id）。
enum Tetromino { I, J, L, O, S, T, Z }

/// 方块实例：类型 + 旋转态（0=spawn/1=R/2=180/3=L）+ 左上角棋盘坐标 +
/// 特殊标记（三期 T3-02：bomb/weight 由 config `special_chance` 概率注入）。
class Piece {
  Tetromino type;
  int rot;
  int x;
  int y;
  TetrisSpecial special;
  Piece(this.type, this.rot, this.x, this.y, {this.special = TetrisSpecial.none});
}

/// 特殊方块类型（三期 T3-02）。
enum TetrisSpecial { none, bomb, weight }

/// 发牌队列条目：方块类型 + 注入的特殊标记（Next 预览同步显示）。
class QueuedPiece {
  final Tetromino type;
  final TetrisSpecial special;
  const QueuedPiece(this.type, {this.special = TetrisSpecial.none});
}

/// 棋盘尺寸（Guideline 标准 10×20）。
const int kTetrisRows = 20;
const int kTetrisCols = 10;

/// 每种方块的基础矩阵（spawn 态）。I 用 4×4、O 用 2×2、其余 3×3，
/// 矩阵逐次顺时针旋转生成 4 个旋转态的占用格（SRS 标准行为）。
const Map<Tetromino, List<List<int>>> _kBaseMatrix = <Tetromino, List<List<int>>>{
  Tetromino.I: [
    <int>[0, 0, 0, 0],
    <int>[1, 1, 1, 1],
    <int>[0, 0, 0, 0],
    <int>[0, 0, 0, 0],
  ],
  Tetromino.J: [
    <int>[1, 0, 0],
    <int>[1, 1, 1],
    <int>[0, 0, 0],
  ],
  Tetromino.L: [
    <int>[0, 0, 1],
    <int>[1, 1, 1],
    <int>[0, 0, 0],
  ],
  Tetromino.O: [
    <int>[1, 1],
    <int>[1, 1],
  ],
  Tetromino.S: [
    <int>[0, 1, 1],
    <int>[1, 1, 0],
    <int>[0, 0, 0],
  ],
  Tetromino.T: [
    <int>[0, 1, 0],
    <int>[1, 1, 1],
    <int>[0, 0, 0],
  ],
  Tetromino.Z: [
    <int>[1, 1, 0],
    <int>[0, 1, 1],
    <int>[0, 0, 0],
  ],
};

/// 预计算占用格：[type][rot] → 相对锚点(左上)的偏移列表。
final Map<Tetromino, List<List<Point<int>>>> _kCells = <Tetromino,
    List<List<Point<int>>>>{
  for (final t in Tetromino.values)
    t: List<List<Point<int>>>.generate(4, (rot) {
      var m = _kBaseMatrix[t]!;
      for (var i = 0; i < rot; i++) {
        m = _rotateCW(m);
      }
      final cells = <Point<int>>[];
      for (var r = 0; r < m.length; r++) {
        for (var c = 0; c < m[r].length; c++) {
          if (m[r][c] == 1) cells.add(Point<int>(c, r));
        }
      }
      return cells;
    }),
};

List<List<int>> _rotateCW(List<List<int>> m) {
  final n = m.length;
  return List<List<int>>.generate(
      n, (r) => List<int>.generate(n, (c) => m[n - 1 - c][r]));
}

/// SRS 踢墙表（已折算为棋盘坐标系：y 向下为正）。
/// key = '$from$to'（旋转方向只有 ±1 与对转不存在，覆盖全部 8 个相邻态）。
const Map<String, List<Point<int>>> _kKickTable = <String, List<Point<int>>>{
  '01': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(-1, -1), Point<int>(0, 2), Point<int>(-1, 2)],
  '10': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(1, 1), Point<int>(0, -2), Point<int>(1, -2)],
  '12': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(1, 1), Point<int>(0, -2), Point<int>(1, -2)],
  '21': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(-1, -1), Point<int>(0, 2), Point<int>(-1, 2)],
  '23': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(1, -1), Point<int>(0, 2), Point<int>(1, 2)],
  '32': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(-1, 1), Point<int>(0, -2), Point<int>(-1, -2)],
  '30': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(-1, 1), Point<int>(0, -2), Point<int>(-1, -2)],
  '03': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(1, -1), Point<int>(0, 2), Point<int>(1, 2)],
  // I 独立踢墙表
  '01I': [Point<int>(0, 0), Point<int>(-2, 0), Point<int>(1, 0), Point<int>(-2, 1), Point<int>(1, -2)],
  '10I': [Point<int>(0, 0), Point<int>(2, 0), Point<int>(-1, 0), Point<int>(2, -1), Point<int>(-1, 2)],
  '12I': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(2, 0), Point<int>(-1, -2), Point<int>(2, 1)],
  '21I': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(-2, 0), Point<int>(1, 2), Point<int>(-2, -1)],
  '23I': [Point<int>(0, 0), Point<int>(2, 0), Point<int>(-1, 0), Point<int>(2, -1), Point<int>(-1, 2)],
  '32I': [Point<int>(0, 0), Point<int>(-2, 0), Point<int>(1, 0), Point<int>(-2, 1), Point<int>(1, -2)],
  '30I': [Point<int>(0, 0), Point<int>(1, 0), Point<int>(-2, 0), Point<int>(1, 2), Point<int>(-2, -1)],
  '03I': [Point<int>(0, 0), Point<int>(-1, 0), Point<int>(2, 0), Point<int>(-1, -2), Point<int>(2, 1)],
};

/// 七种方块的经典配色（I 青 / O 黄 / T 紫 / S 绿 / Z 红 / J 蓝 / L 橙）。
const List<Color> kTetrominoColors = <Color>[
  Color(0xFF00BCD4),
  Color(0xFF3B6FD4),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF22C55E),
  Color(0xFFA855F7),
  Color(0xFFEF4444),
];

// ───────────────────────── 引擎状态与流程 ─────────────────────────

extension _TetrisEngineOps on _TetrisGameState {
  /// 从 7-bag 取下一块（袋空重洗），并按 `special_chance` 掷骰特殊标记
  /// （三期 T3-02：bomb/weight 各半概率二选一）。
  QueuedPiece _nextFromBag() {
    if (_bag.isEmpty) {
      _bag
        ..clear()
        ..addAll(Tetromino.values)
        ..shuffle(_rng);
    }
    final type = _bag.removeLast();
    var special = TetrisSpecial.none;
    if (_specialChance > 0 && _rng.nextDouble() < _specialChance) {
      special = _rng.nextBool() ? TetrisSpecial.bomb : TetrisSpecial.weight;
    }
    return QueuedPiece(type, special: special);
  }

  /// 生成新块：spawn 位被占 = Block Out（顶死）。
  void _spawnPiece() {
    final qp = _queue.removeAt(0);
    while (_queue.length <= _nextPreview) {
      _queue.add(_nextFromBag());
    }
    final type = qp.type;
    final cells = _kCells[type]![0];
    final minX = cells.map((p) => p.x).reduce(min);
    final maxX = cells.map((p) => p.x).reduce(max);
    _current = Piece(type, 0, (kTetrisCols - (maxX - minX + 1)) ~/ 2 - minX, 0,
        special: qp.special);
    _lastAction = _TetrisAction.spawn;
    if (_collides(_current!, 0, 0)) {
      // 顶死：先尝试上移一格（spawn 行被占时仍可救一块）
      _current!.y--;
      if (_collides(_current!, 0, 0)) {
        _current = null;
        _onBlockOut();
        return;
      }
    }
    _cancelLockTimer();
    _lockResets = 0;
    if (mounted) setState(() {});
  }

  /// 格占用检测：越界或已有块。
  bool _cellBlocked(int row, int col) {
    if (col < 0 || col >= kTetrisCols || row >= kTetrisRows) return true;
    if (row < 0) return false; // 顶上方缓冲区视作空
    return _board[row][col] != null;
  }

  /// 格碰撞检测；[rot] 缺省用当前朝向，旋转预检必须传目标朝向——
  /// 用旧朝向测通过、应用新朝向后会压进已占格（穿模/锁定覆盖他人）。
  bool _collides(Piece p, int dx, int dy, {int? rot}) {
    for (final c in _kCells[p.type]![rot ?? p.rot]) {
      if (_cellBlocked(p.y + c.y + dy, p.x + c.x + dx)) return true;
    }
    return false;
  }

  /// 当前块是否已触底（无法再下移）。
  bool get _isResting {
    final p = _current;
    return p == null || _collides(p, 0, 1);
  }

  /// 横移一格（按钮/手势）；成功返回 true。
  bool _moveHorizontal(int dx) {
    final p = _current;
    if (p == null || _finished || _isPaused || _collides(p, dx, 0)) {
      return false;
    }
    p.x += dx;
    _lastAction = _TetrisAction.move;
    _afterSuccessfulShift();
    GameAudio.instance.move();
    if (mounted) setState(() {});
    return true;
  }

  /// SRS 旋转（O 恒成功但不计入 T-Spin 末态）。
  bool _rotatePiece(int dir) {
    final p = _current;
    if (p == null || _finished || _isPaused) return false;
    if (p.type == Tetromino.O) {
      GameAudio.instance.rotate();
      return true;
    }
    // 重块（三期 T3-02）：不可旋转
    if (p.special == TetrisSpecial.weight) return false;
    final to = (p.rot + dir + 4) % 4;
    final key = '${p.rot}$to${p.type == Tetromino.I ? 'I' : ''}';
    final kicks = _kKickTable[key] ??
        _kKickTable['${p.rot}$to'] ??
        const <Point<int>>[];
    for (var i = 0; i < kicks.length; i++) {
      final k = kicks[i];
      // 按旋转后的目标朝向检测（rot: to），旧朝向会误判通过
      if (!_collides(p, k.x, k.y, rot: to)) {
        p.rot = to;
        p.x += k.x;
        p.y += k.y;
        _lastAction = _TetrisAction.rotate;
        _lastKickIndex = i;
        _afterSuccessfulShift();
        GameAudio.instance.rotate();
        if (mounted) setState(() {});
        return true;
      }
    }
    return false;
  }

  /// 移动/旋转成功后的 lock delay 处理：
  /// 已触底时刷新 500ms 计时（上限 [_kMaxLockResets] 次防无限拖延）；
  /// 若重新悬空则取消计时。
  void _afterSuccessfulShift() {
    if (_isResting) {
      if (_lockTimer != null &&
          _lockResets < _TetrisGameState._kMaxLockResets) {
        _lockResets++;
        _restartLockTimer();
      } else if (_lockTimer == null) {
        _startLockTimer();
      }
    } else {
      _cancelLockTimer();
    }
  }

  /// 重力 tick：能下移则下移；触底则启动 lock delay。
  /// 重块特殊：每 tick 额外再下移 1 格（等效 ×2 速，与宿主 0.4 间隔系数
  /// 叠加≈快速下沉）。
  void _gravityTick() {
    if (_finished || _isPaused || _current == null) return;
    if (!_isResting) {
      _current!.y++;
      if (_current!.special == TetrisSpecial.weight &&
          !_isResting &&
          !_finished) {
        _current!.y++; // 重块二次下坠
      }
      _cancelLockTimer();
      if (mounted) setState(() {});
      return;
    }
    if (_lockTimer == null) _startLockTimer();
  }

  /// 硬降：直达 ghost 位并立即锁定（+2 分/格）。
  void _hardDrop() {
    final p = _current;
    if (p == null || _finished || _isPaused) return;
    final gy = _ghostY();
    final dist = gy - p.y;
    if (dist > 0) {
      p.y = gy;
      _score += 2 * dist;
      _lastAction = _TetrisAction.drop;
    }
    GameAudio.instance.haptic(GameHaptic.light);
    _cancelLockTimer();
    _lockPiece();
  }

  /// 软降一步（按钮/按住手势）：能下移则 +1 分；触底则交给 lock delay。
  void _softDropStep() {
    final p = _current;
    if (p == null || _finished || _isPaused) return;
    if (!_isResting) {
      p.y++;
      _score += 1;
      _cancelLockTimer();
      if (mounted) setState(() {});
    } else if (_lockTimer == null) {
      _startLockTimer();
    }
  }

  /// ghost 落点行。
  int _ghostY() {
    final p = _current!;
    var y = p.y;
    while (!_collidesAt(p, p.x, y + 1)) {
      y++;
    }
    return y;
  }

  bool _collidesAt(Piece p, int px, int py) {
    for (final c in _kCells[p.type]![p.rot]) {
      if (_cellBlocked(py + c.y, px + c.x)) return true;
    }
    return false;
  }

  /// Hold：落地前每块仅一次；有暂存则交换，无暂存则取队列头。
  void _holdPiece() {
    final p = _current;
    if (p == null || _finished || !_holdEnabled || _holdUsed || _isPaused) {
      return;
    }
    _cancelLockTimer();
    _lockResets = 0;
    final held = _held;
    final heldSpecial = _heldSpecial;
    _held = p.type;
    _heldSpecial = p.special;
    if (held == null) {
      _spawnPiece();
    } else {
      _current = Piece(held, 0,
          (kTetrisCols - _pieceWidth(held)) ~/ 2, 0,
          special: heldSpecial);
      _lastAction = _TetrisAction.spawn;
      if (_collides(_current!, 0, 0)) {
        _current!.y--;
        if (_collides(_current!, 0, 0)) {
          _current = null;
          _onBlockOut();
          return;
        }
      }
    }
    _holdUsed = true;
    GameAudio.instance.select();
    if (mounted) setState(() {});
  }

  int _pieceWidth(Tetromino t) {
    final cells = _kCells[t]![0];
    final xs = cells.map((c) => c.x).toList();
    return xs.reduce(max) - xs.reduce(min) + 1;
  }

  // ───────────────────────── 锁定 / 消行 / 计分 ─────────────────────────

  /// T-Spin 判定：T 块 + 末动为旋转 + 四角 ≥3 占。
  /// 前两角（指向侧）均占或第 5 号踢位触发 → full，否则 mini。
  _TetrisSpin? _detectTSpin(Piece p) {
    if (p.type != Tetromino.T || _lastAction != _TetrisAction.rotate) {
      return null;
    }
    const corners = <Point<int>>[
      Point<int>(0, 0),
      Point<int>(2, 0),
      Point<int>(0, 2),
      Point<int>(2, 2),
    ];
    const frontByRot = <List<Point<int>>>[
      [Point<int>(0, 0), Point<int>(2, 0)], // 0 指上
      [Point<int>(2, 0), Point<int>(2, 2)], // R 指右
      [Point<int>(0, 2), Point<int>(2, 2)], // 2 指下
      [Point<int>(0, 0), Point<int>(0, 2)], // L 指左
    ];
    var occupied = 0;
    for (final c in corners) {
      if (_cellBlocked(p.y + c.y, p.x + c.x)) occupied++;
    }
    if (occupied < 3) return null;
    final front = frontByRot[p.rot];
    final frontBoth = _cellBlocked(p.y + front[0].y, p.x + front[0].x) &&
        _cellBlocked(p.y + front[1].y, p.x + front[1].x);
    final isFull = frontBoth || _lastKickIndex == 4;
    return isFull ? _TetrisSpin.full : _TetrisSpin.mini;
  }

}

enum _TetrisAction { spawn, move, rotate, drop }

/// T-Spin 类型。
enum _TetrisSpin { full, mini }

/// 消行大字特效条目。
class _TetrisFx {
  final String text;
  final DateTime at;
  const _TetrisFx(this.text, this.at);
}
