part of 'match3_flame_game.dart';

/// 乱斗模式引擎侧（part of match3_flame_game，共享引擎私有状态）。
///
/// 乱斗（自由模式专属）：Boss 血条 + 果冻 + 冰封混合——
/// - Boss 血量随时间自动回复（速率 = tier config `regenPerSec`，按 §20 容量
///   模型从既往实测 D 值推演：玩家输出 ≈4.2 血/秒，回复占比 24%/36%/60%）；
/// - 果冻/冰封随时间随机自增（间隔 = tier config `spawnEverySec`，
///   3.3/5/7.5 格/分，远低于玩家 ≈24 格/分的清格能力，按难度加压）；
/// - 消除带果冻/冰封的格子掉血 ×2/×4（Objective.onCleared 实现）；
/// - 果冻+冰封占满盘面判负（自增后与连锁收尾双检查）；
/// - 不限步数，击破 Boss 即胜；支持手动暂停（暂停引擎 update 循环 +
///   锁交互，配合宿主弹窗）。
/// 扩展名公开（宿主 match3_game.dart 跨库调用 setUserPaused 等 API）。
extension Match3Brawl on Match3FlameGame {
  // 累计器与 userPaused 字段在主类（Dart 扩展不能声明实例字段）。

  /// 本局是否为乱斗模式
  bool get isBrawlMode => objective.mode == Match3Mode.brawl;

  /// 暂停/恢复（宿主按钮调用）。暂停同时停用 Flame update（动画冻结，
  /// 体感即「时间停止」）；恢复后累计器继续，不补偿暂停期间时长。
  void setUserPaused(bool paused) {
    if (_over || !isBrawlMode) return;
    if (userPaused == paused) return;
    userPaused = paused;
    if (paused) {
      pauseEngine();
    } else {
      resumeEngine();
    }
    notifyHud();
  }

  /// 等待暂停解除（pauseEngine 只停 update 循环，
  /// 连锁的 Future.delayed 回调在暂停期间照跑——盘面逻辑会在暂停弹窗
  /// 背后继续推进甚至自动结算）。连锁各延迟续延点调用本门，
  /// 暂停期间挂起、恢复后继续，保证「暂停即时间停止」语义完整。
  Future<void> waitWhilePaused() async {
    while (userPaused && isMounted && !_over) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 引擎 update 每帧调用（宿主在 update 内转发 dt）。
  /// 暂停时 update 整体已停（pauseEngine），此处只防御 _over/_loaded。
  void brawlTick(double dt) {
    if (!isBrawlMode || !_loaded || _over || userPaused) return;
    var dirty = false;

    // 1) Boss 血量自动回复（Boss 已破不回血；上限钳制 bossHp）
    if (objective.bossLeft > 0 && objective.brawlRegenPerSec > 0) {
      _brawlRegenAcc += dt * objective.brawlRegenPerSec;
      while (_brawlRegenAcc >= 1 && objective.bossLeft < objective.bossHp) {
        _brawlRegenAcc -= 1;
        objective.bossLeft++;
        dirty = true;
      }
      if (_brawlRegenAcc >= 1) _brawlRegenAcc = 0; // 已满血，丢弃余量
    }

    // 2) 果冻/冰封随机自增：到点在无障碍格随机铺 1 格（果冻/冰封各半概率）
    if (objective.brawlSpawnEverySec > 0) {
      _brawlSpawnAcc += dt;
      if (_brawlSpawnAcc >= objective.brawlSpawnEverySec) {
        _brawlSpawnAcc = 0;
        dirty = _brawlSpawnObstacle() || dirty;
      }
    }

    if (dirty) notifyHud();
  }

  /// 随机自增一格障碍。返回是否实际放置（无可放格 = 占满 → 判负结算）。
  bool _brawlSpawnObstacle() {
    final empty = <(int, int)>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          if (objective.jelly[r][c] == 0 && objective.ice[r][c] == 0) (r, c),
    ];
    if (empty.isEmpty) {
      // 占满判负：果冻格和冰封格占满即失败。Boss 已破（延迟结算续玩中）
      // 不判负——cleared 跟随 achieved 为真，以失败文案弹胜利结算自相矛盾，
      // 直接跳过自增即可。
      if (!objective.achieved) {
        _finishByObjective(failReason: '果冻与冰封占满盘面，对局失败');
      }
      return false;
    }
    final (r, c) = empty[_rng.nextInt(empty.length)];
    if (_rng.nextBool()) {
      objective.jelly[r][c] = 1;
    } else {
      objective.ice[r][c] = 2;
    }
    return true;
  }
}
