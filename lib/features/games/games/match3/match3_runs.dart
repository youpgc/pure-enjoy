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
