import 'candy_component.dart';

/// 消消乐一次连线（用于生成特殊糖与消除判定）。
///
/// `orient` 为 `'h'`（横向）或 `'v'`（纵向）；`cells` 为该连线覆盖的 (行, 列) 列表。
class MatchRun {
  final String orient;
  final List<(int, int)> cells;
  MatchRun(this.orient, this.cells);
}

/// 检测棋盘上所有 >=3 连的连线（横/纵）。
///
/// 纯函数：只读取 [grid]，不修改任何状态。[rows]/[cols] 为棋盘维度。
List<MatchRun> findRuns(List<List<Candy?>> grid, int rows, int cols) {
  final runs = <MatchRun>[];
  // 横向
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
        runs.add(MatchRun('h', cells));
      }
      c = end + 1;
    }
  }
  // 纵向
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
        runs.add(MatchRun('v', cells));
      }
      r = end + 1;
    }
  }
  return runs;
}

/// 计算一颗特殊糖的影响范围（纯函数）。
///
/// - `row`：清整行；`col`：清整列；`wrap`：3×3；`bomb`：清同色；其他：空。
/// [grid]/[rows]/[cols] 仅用于 row/col/wrap/bomb 的边界与同色判定，不修改任何状态。
List<(int, int)> effectCells(
  Candy cand,
  int r,
  int c,
  List<List<Candy?>> grid,
  int rows,
  int cols,
) {
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

/// 生成初始棋盘（纯函数）：逐格随机取类型，并回避初始 3 连。
///
/// [nextType] 返回 [0, typeCount) 的随机类型；[make] 由宿主构造 Candy，
/// 以便其注入画布偏移等宿主状态。返回的棋盘保证开局无可消除连线。
List<List<Candy?>> newBoard({
  required int rows,
  required int cols,
  required int Function() nextType,
  required double offsetX,
  required double offsetY,
  required double cell,
  required Candy Function(int type, int row, int col, double x, double y) make,
}) {
  final grid = List.generate(rows, (_) => List<Candy?>.filled(cols, null));
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      int t;
      do {
        t = nextType();
      } while ((c >= 2 &&
              grid[r][c - 1]?.type == t &&
              grid[r][c - 2]?.type == t) ||
          (r >= 2 && grid[r - 1][c]?.type == t && grid[r - 2][c]?.type == t));
      grid[r][c] = make(t, r, c, offsetX + c * cell, offsetY + r * cell);
    }
  }
  return grid;
}

/// 清空指定格（纯盘面运算）：把 [toClear] 中每格的引用置空。
void removeCleared(List<List<Candy?>> grid, Set<(int, int)> toClear) {
  for (final cell in toClear) {
    grid[cell.$1][cell.$2] = null;
  }
}

/// 重力下落 + 顶部补充（纯盘面运算）。
///
/// 每列剩余糖块沉底，顶部空缺由 [spawn] 生成的新糖填充；新糖初始 y 坐标
/// 位于画布上方（[spawnY] 为负），配合宿主的缓动 update 形成「从上方落入」
/// 的动画。仅重排 [grid] 引用并改写 Candy.row，不触碰任何渲染状态。
///
/// [spawn] 由宿主提供，便于其注入随机类型与画布偏移等宿主状态。
void applyGravity({
  required List<List<Candy?>> grid,
  required int rows,
  required int cols,
  required Candy Function(int row, int col, double x, double y) spawn,
  required double offsetX,
  required double offsetY,
  required double cell,
}) {
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
      grid[r][c] = spawn(r, c, offsetX + c * cell, offsetY + spawnY * cell);
      spawnY--;
    }
  }
}
