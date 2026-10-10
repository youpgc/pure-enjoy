part of 'tetris_game.dart';

// 垃圾行系统（二期 T2-01，part of _TetrisGameState）：
// dig（预填挖掘）/ survival（周期顶起）/ 三期 Boss（推行）三种驱动源共用。
// 公平规则：相邻垃圾行洞位不同列（可挖穿保证，真相源二期 T2-01 规格）。
// ignore_for_file: invalid_use_of_protected_member
// （part+extension 内调宿主 setState 属 analyzer 已知误报，g2048 同款处理）

/// 垃圾行在棋盘中的存色 id（超出 7 种方块的保留位，渲染用 [kGarbageColor]）。
const int kGarbageColorIndex = 7;

/// 垃圾砖配色（灰砖，与普通块明显区分）。
const Color kGarbageColor = Color(0xFF6B7280);

extension _TetrisGarbageOps on _TetrisGameState {
  /// 生成一个新垃圾行（洞位与上一垃圾行不同列，保证可挖穿）。
  List<int?> _buildGarbageRow() {
    int hole;
    do {
      hole = _rng.nextInt(kTetrisCols);
    } while (hole == _lastGarbageHole);
    _lastGarbageHole = hole;
    return List<int?>.generate(kTetrisCols, (c) => c == hole ? null : kGarbageColorIndex);
  }

  /// dig 预填：底部填 [n] 行垃圾（开局棋盘为空，直接写底部）。
  void _prefillGarbage(int n) {
    final count = n.clamp(1, kTetrisRows - 4);
    for (var r = 0; r < count; r++) {
      _board[kTetrisRows - 1 - r] = _buildGarbageRow();
    }
    _boardRev++;
  }

  /// survival 顶起：整盘上移一行、底部插入垃圾行。
  /// 返回 false = 顶部溢出（原顶行有块或当前块上移后碰撞），调用方结算 Block Out。
  bool _pushGarbageRow() {
    if (_finished) return true;
    // 消行闪烁中跳过本次顶起：整盘上移会让 _flashRows 行号错位、
    // 动画结束时删错行（闪烁窗口仅 ~360ms，顺延一个周期无感知）
    if (_flashRows.isNotEmpty) return true;
    // 溢出判定：顶行已有块，顶起即出界
    if (_board[0].any((c) => c != null)) return false;
    _board.removeAt(0);
    _board.insert(kTetrisRows - 1, _buildGarbageRow());
    // 当前块跟随上移；上移后碰撞（顶入垃圾/墙）即溢出
    final p = _current;
    if (p != null) {
      p.y--;
      _cancelLockTimer();
      if (_collides(p, 0, 0)) return false;
    }
    _boardRev++;
    if (mounted) setState(() {});
    return true;
  }

  /// 场上剩余垃圾行数（dig 通关判定 = 0）。
  int get _garbageRowsRemaining =>
      _board.where((row) => row.contains(kGarbageColorIndex)).length;
}
