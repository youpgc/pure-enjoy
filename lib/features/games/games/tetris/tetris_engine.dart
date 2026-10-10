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

  bool _collides(Piece p, int dx, int dy) {
    for (final c in _kCells[p.type]![p.rot]) {
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
    if (p == null || _finished || _collides(p, dx, 0)) return false;
    p.x += dx;
    _lastAction = _TetrisAction.move;
    _afterSuccessfulShift();
    if (mounted) setState(() {});
    return true;
  }

  /// SRS 旋转（O 恒成功但不计入 T-Spin 末态）。
  bool _rotatePiece(int dir) {
    final p = _current;
    if (p == null || _finished) return false;
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
      if (!_collides(p, k.x, k.y)) {
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
    if (_finished || _current == null) return;
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
    if (p == null || _finished) return;
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
    if (p == null || _finished) return;
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
    if (p == null || _finished || !_holdEnabled || _holdUsed) return;
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

  /// 锁定当前块：写盘 → T-Spin 判定 → 满行检测。
  /// 有消行时先播放闪烁动画（_flashRows 白色高亮 4 相位 ~360ms，2026-10-10
  /// 用户反馈「瞬间消失太生硬」），动画结束在 [_finishLineClear] 真正删行计分；
  /// 无消行走原路径直接结算。
  void _lockPiece() {
    final p = _current;
    if (p == null || _finished) return;
    final spin = _detectTSpin(p);
    for (final c in _kCells[p.type]![p.rot]) {
      final r = p.y + c.y;
      final col = p.x + c.x;
      if (r >= 0 && r < kTetrisRows && col >= 0 && col < kTetrisCols) {
        _board[r][col] = p.type.index;
      }
    }
    _boardRev++;
    _current = null;
    _piecesPlaced++;
    _cancelLockTimer();
    _lockResets = 0;

    // 炸弹块引爆（三期 T3-02）：清除以锁定中心格为准的 3×3 邻域，
    // 固定 30×等级引爆分；引爆清格不算消行、不计 Boss 伤害（防刷），
    // 但可能连带拼出满行走下方正常消行流程（计分/计伤/B2B 断链照旧）。
    if (p.special == TetrisSpecial.bomb) {
      final cr = p.y + 1;
      final cc = p.x + 1;
      for (var r = cr - 1; r <= cr + 1; r++) {
        for (var c = cc - 1; c <= cc + 1; c++) {
          if (r >= 0 && r < kTetrisRows && c >= 0 && c < kTetrisCols) {
            _board[r][c] = null;
          }
        }
      }
      _score += 30 * _scoreLevel;
      _boardRev++;
      _pushFx('BOOM!');
      GameAudio.instance.haptic(GameHaptic.heavy);
    }

    // 满行检测
    final full = <int>[
      for (var r = 0; r < kTetrisRows; r++)
        if (_board[r].every((c) => c != null)) r,
    ];
    if (full.isNotEmpty) {
      // 消行动画：保留被消行原样，白色高亮一亮一暗闪 4 相位
      _flashRows = full;
      _flashPhase = 0;
      _boardRev++;
      GameAudio.instance.lineClear(full.length);
      GameAudio.instance
          .haptic(full.length >= 4 ? GameHaptic.heavy : GameHaptic.medium);
      if (mounted) setState(() {});
      _flashTimer?.cancel();
      _flashTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
        _flashPhase++;
        if (_flashPhase >= 4) {
          t.cancel();
          _finishLineClear(spin);
          return;
        }
        _boardRev++;
        if (mounted) setState(() {});
      });
      return;
    }

    // 无消行：空锁定也要给 combo 断链语义（_applyClearScore(0)）
    _applyClearScore(0, spin);

    // 挑战模式块数耗尽：spawn 前结算
    if (_piecesLimit != null && _piecesPlaced >= _piecesLimit!) {
      _finish(_score >= _scoreTarget);
      return;
    }
    if (_checkWin()) return;
    _holdUsed = false;
    _spawnPiece();
  }

  /// 消行计分：基础表 × T-Spin/B2B × Combo × PC × Frenzy（blitz）。
  void _applyClearScore(int lines, _TetrisSpin? spin) {
    final lvl = _scoreLevel;
    var base = 0;
    if (spin == _TetrisSpin.full) {
      base = const <int>[400, 800, 1200, 1600][lines.clamp(0, 3)];
    } else if (spin == _TetrisSpin.mini) {
      base = const <int>[100, 200][lines.clamp(0, 1)];
    } else if (lines > 0) {
      base = const <int>[0, 100, 300, 500, 800][lines.clamp(0, 4)];
      if (lines == 4) _tetrisCount++;
    }
    if (spin != null) _tspinCount++;

    // B2B：本次为 Tetris 或任意 T-Spin 消行 → 维持/开启链；普通消行断链
    final isB2BMove = lines > 0 && (lines == 4 || spin != null);
    var b2bApplied = false;
    if (lines > 0) {
      if (isB2BMove) {
        if (_b2bActive) {
          b2bApplied = true;
          _b2bChain++;
          _maxB2b = max(_maxB2b, _b2bChain);
        } else {
          _b2bChain = 1;
        }
        _b2bActive = true;
      } else {
        _b2bChain = 0;
        _b2bActive = false;
      }
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
    } else {
      // 空锁定（如 T-Spin 0 行不消行）不推进也不打断 combo 语义：打断 combo
      _combo = 0;
    }

    var gain = 0;
    if (lines > 0 || spin != null) {
      gain = (base * lvl * (b2bApplied ? 1.5 : 1)).round();
      if (_combo >= 1) gain += 50 * _combo * lvl;
    }

    // Perfect Clear：消行后盘面全空
    if (lines > 0 && _board.every((row) => row.every((c) => c == null))) {
      gain += 3500 * lvl;
      _perfectClears++;
      _pushFx('PERFECT CLEAR!');
    }

    if (_frenzyEnabled && lines > 0) {
      // Frenzy 断连规则：倒计时最后 10s 倍率强制归 1（终局不加成）
      final mult = (_timeLimit != null && _remainingSeconds() <= 10)
          ? 1.0
          : 1 + 0.5 * min(_combo, 6);
      gain = (gain * mult).round();
    }

    _score += gain;
    if (lines > 0) {
      _linesTotal += lines;
      // 通关大字反馈（爽感反馈验收项）
      if (lines == 4) {
        _pushFx('TETRIS!');
      } else if (spin == _TetrisSpin.full) {
        _pushFx(lines > 0 ? 'T-SPIN $lines 行' : 'T-SPIN');
      } else if (spin == _TetrisSpin.mini) {
        _pushFx('T-SPIN MINI');
      } else if (_combo >= 2) {
        _pushFx('COMBO ×$_combo');
      }
      if (isB2BMove && b2bApplied) _pushFx('B2B');
      // 速度等级（仅 marathon 局内加速）：每 levelUpLines 行间隔 ×speedFactor
      _applyFallSpeed();
      // 消行音效/触觉已在闪烁动画开始时播放（_lockPiece），此处不重复
    }

    // 计分等级随消行增长（全模式）
    final newLevel = 1 + _linesTotal ~/ 10;
    if (newLevel > _scoreLevel) {
      _scoreLevel = newLevel;
      if (newLevel > 1) _pushFx('LEVEL $newLevel');
      GameAudio.instance.levelUp();
    }
    if (mounted) setState(() {});
  }

  /// 按 marathon 局内加速规则刷新重力间隔。
  void _applyFallSpeed() {
    if (_levelUpLines <= 0) return;
    final fallLevels = _linesTotal ~/ _levelUpLines;
    final ms = (_fallMsBase * pow(_speedFactor, fallLevels)).round();
    _currentFallMs = max(_fallMin, ms);
    _restartGravityTimer();
  }

  /// 通关检测（消行/计分后调用）。
  ///
  /// 延迟结算（2026-10-10 用户需求）：马拉松/每日/闪电/挑战/生存五模式
  /// 首次达标不立即结束，置 [_goalReached] 继续游戏刷更高分——玩家可点
  /// 「确认结算」提前落袋，或玩到自然封顶（顶死/超时/块尽）按累计值
  /// 正常结算；竞速（用时语义）/挖掘（挖穿即胜）/Boss（血空即胜）
  /// 达标即结算不延续。
  bool _checkWin() {
    if (_finished) return true;
    if (_goalReached) return false; // 已达标待结算，不再重复判定
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        if (_linesTarget > 0 && _linesTotal >= _linesTarget) {
          if (_supportsContinue) {
            _goalReached = true;
            _pushFx('目标达成! 可继续');
            GameAudio.instance.levelUp();
            if (mounted) setState(() {});
            return false;
          }
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        if (_scoreTarget > 0 && _score >= _scoreTarget) {
          if (_supportsContinue) {
            _goalReached = true;
            _pushFx('目标达成! 可继续');
            GameAudio.instance.levelUp();
            if (mounted) setState(() {});
            return false;
          }
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.dig:
        // 挖掘：预填垃圾行全部清除即通关（挖光必然触达地板）
        if (_digRows > 0 && _garbageRowsRemaining == 0) {
          _finish(true);
          return true;
        }
        break;
      case TetrisMode.boss:
        if (_bossMaxHp > 0 && _bossHp <= 0) {
          _finish(true);
          return true;
        }
        break;
    }
    return false;
  }

  /// 消行闪烁动画结束：真正删行（含垃圾砖统计）→ 计分 → 通关/续 spawn。
  void _finishLineClear(_TetrisSpin? spin) {
    if (_finished) return; // 闪烁期间对局可能已被超时/放弃路径结束
    final n = _flashRows.length;
    // 垃圾砖统计在删前进行（dig/digger 成就数据源）
    for (final r in _flashRows) {
      if (_board[r].contains(kGarbageColorIndex)) _garbageCleared++;
    }
    // 重建棋盘：剔除被消行、顶部补等量空行（保持行序，等价 removeAt+insert）
    final kept = <List<int?>>[
      for (var r = 0; r < kTetrisRows; r++)
        if (!_flashRows.contains(r)) _board[r],
    ];
    _board = <List<int?>>[
      for (var i = 0; i < n; i++) List<int?>.filled(kTetrisCols, null),
      ...kept,
    ];
    _flashRows = <int>[];
    _boardRev++;
    _applyClearScore(n, spin);

    // Boss 伤害结算（三期 T3-01）：普通消行 = 行数 ×1；T-Spin full +2 /
    // mini +1 额外加成；删行补空后盘面全空 = Perfect Clear，额外 +10% 最大
    // 血量。血条归零 → 通关。
    if (_bossMaxHp > 0 && n > 0) {
      var dmg = n;
      if (spin == _TetrisSpin.full) {
        dmg += 2;
      } else if (spin == _TetrisSpin.mini) {
        dmg += 1;
      }
      _bossHp = max(0, _bossHp - dmg);
      if (_board.every((row) => row.every((c) => c == null))) {
        _bossHp = max(0, _bossHp - (_bossMaxHp * 0.10).round());
        _pushFx('BOSS -10%');
      }
      if (mounted) setState(() {});
    }

    // 挑战模式块数耗尽：spawn 前结算（计分后用最新分判定，比一期更准确）
    if (_piecesLimit != null && _piecesPlaced >= _piecesLimit!) {
      _finish(_score >= _scoreTarget);
      return;
    }
    if (_checkWin()) return;
    _holdUsed = false;
    _spawnPiece();
  }

  /// Block Out（顶死）结算：达标仍算通关（最后一消恰好达标、顶死在后的情况）。
  void _onBlockOut() {
    final bool win;
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        win = _linesTarget > 0 && _linesTotal >= _linesTarget;
        break;
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        win = _scoreTarget > 0 && _score >= _scoreTarget;
        break;
      case TetrisMode.dig:
      case TetrisMode.boss:
        win = false; // 挖掘顶死=未挖穿；Boss 顶死=血量未清空
    }
    _finish(win, reason: win ? null : '方块堆到顶部，对局结束');
  }

  /// 消行大字反馈队列（board 上层浮现 1.2s 后淡出）。
  void _pushFx(String text) {
    final fx = _TetrisFx(text, DateTime.now());
    _fxMessages.add(fx);
    if (_fxMessages.length > 3) _fxMessages.removeAt(0);
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _fxMessages.isEmpty) return;
      _fxMessages.remove(fx);
      if (mounted) setState(() {});
    });
  }
}

/// 末次操作语义（T-Spin 判定依据：仅旋转末态成立）。
enum _TetrisAction { spawn, move, rotate, drop }

/// T-Spin 类型。
enum _TetrisSpin { full, mini }

/// 消行大字特效条目。
class _TetrisFx {
  final String text;
  final DateTime at;
  const _TetrisFx(this.text, this.at);
}
