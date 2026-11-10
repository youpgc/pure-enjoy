part of 'match3_flame_game.dart';

// 相邻交换发起与否定判定（无消除回弹/道具触发入口）；与主文件同库、共享其 import。
// 【误报说明】onTapUp 调用 _trySwap 的引用因 part+extension 隐式调用漏计可能误报
// unused_element；运行期语义安全（同库实例方法）。
// ignore_for_file: unused_element

extension _Match3FlameGameInput on Match3FlameGame {
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

    Future.delayed(Match3FlameGame._anim, () async {
      if (!isMounted) return;
      // 乱斗暂停门：暂停期间交换判定挂起（暂停即时间停止）
      await waitWhilePaused();
      if (!isMounted) return;
      if (findRuns(grid, rows, cols).isEmpty) {
        grid[r1][c1] = a;
        grid[r2][c2] = b;
        a.row = r1;
        a.col = c1;
        b.row = r2;
        b.col = c2;
        GameAudio.instance.tap();
        Future.delayed(Match3FlameGame._anim, () {
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
