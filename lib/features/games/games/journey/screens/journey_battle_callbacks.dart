part of 'journey_battle_screen.dart';

/// 局内对局页引擎回调（extension，同 library 访问宿主私有成员）：升级选卡、
/// 终局结算上报、结算弹窗、还魂/炼化确认与提前结算。
extension _JourneyBattleCallbacks on _JourneyBattleScreenState {
  void _onLevelUp(int newLevel) {
    if (!mounted || _levelUpSheetOpen) return;
    final game = _game;
    if (game == null) return;
    _levelUpSheetOpen = true;
    JourneyLevelUpSheet.show(
      context,
      level: newLevel,
      // 候选池构建在引擎侧（weapons part drawChoices：环绕成长+法宝槽位）
      choices: drawChoices(game),
      onPick: game.applyUpgrade,
    ).then((_) {
      _levelUpSheetOpen = false;
      if (!mounted) return;
      // 弹窗关闭后引擎仍处于选卡暂停态 → 还有未选完的卡，靠 here 续弹。
      // 引擎侧 applyUpgrade 对 controller.onLevelUp 的同步调用会被上面的
      // _levelUpSheetOpen 防重入吞掉，因此续弹必须在这里可靠接上，否则引擎
      // 永久停在选卡暂停态（无卡、无恢复蒙层、世界静止）。
      if (game.isPausedForLevelUp) _resumePendingLevelUp(game);
    });
  }

  /// 续弹兜底：引擎仍在选卡暂停态就持续重试，等浮层退场动画结束后弹出
  /// 下一张卡。仅在引擎脱离选卡暂停态时停止，避免一次性延迟因浮层仍被
  /// 占用而 return 后无人再触发、把玩家锁死在静止世界。
  void _resumePendingLevelUp(JourneyFlameGame game) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      // 屏幕销毁、引擎被重建替换（重试/退出流程会置空并重建 _game）或对局已
      // 终局 → 停止续弹，避免操作旧引擎引用或在结算后仍弹选卡。
      if (!mounted || !identical(_game, game) || game.isEnded) return;
      if (!game.isPausedForLevelUp) return;
      if (_levelUpSheetOpen) {
        _resumePendingLevelUp(game);
        return;
      }
      // 等级取引擎真实值而非 hud.level：连升时 HUD 两段式动画延迟同步，
      // 直接读 hud 会让续弹弹窗标题滞后一级。
      _onLevelUp(game.charLevel);
    });
  }

  void _onFinished({
    required bool cleared,
    required int kills,
    required int meritFromCoins,
    required int meritClearBonus,
    required int durationSec,
  }) async {
    if (!mounted) return;
    final result = JourneyRunResult(
      cleared: cleared,
      kills: kills,
      meritFromCoins: meritFromCoins,
      meritClearBonus: meritClearBonus,
      durationSec: durationSec,
      firstClearMerit: widget.level.firstClearMerit,
      levelNo: widget.level.levelNo,
      // 西行记录/结算标题统一带关号（虚拟关保持模式名/地图名）
      levelTitle: widget.level.levelNo > 0
          ? '第${widget.level.levelNo}难 · ${widget.level.title}'
          : widget.level.title,
    );
    // 首通判定：通关且超越进关时的最远记录（与引擎发奖口径一致）。
    final firstClear =
        cleared && widget.level.levelNo > (_controller?.farthestAtStart ?? 0);
    // 对局属性快照只采集一次：本地记录（历史详情）与成绩上报共用同一份。
    final runDetail = JourneyScoreReporter.buildRunDetail(
      _game,
      characterCode: _characterCode,
      modeCode: widget.level.levelNo > 0 ? 'main' : widget.level.kind,
    );
    final (granted, earnedPoint) = await JourneyBusy.run(
      context,
      () => JourneyProgressService.instance.settleRun(
        merit: result.meritTotal,
        kills: kills,
        levelNo: widget.level.levelNo,
        durationMs: durationSec * 1000,
        cleared: cleared,
        kind: widget.level.levelNo > 0 ? 'mainline' : widget.level.kind,
        // 西行记录标题统一带关号（与结算浮层同源）
        levelTitle: result.levelTitle,
        runDetail: runDetail,
      ),
      label: '结算中…',
    );
    // 每日游历 gate 已在进关入口写入（进入即计次，主动放弃同样占次），
    // 此处不再重复写。
    // 成绩上报（成绩看板/排行榜/数据分析链路；未就绪静默跳过）。
    // run_detail 对局详情快照与本地记录同源，终局无论胜败随主记录落库。
    JourneyScoreReporter.report(
      result: result,
      cleared: cleared,
      levelId: widget.level.id,
      snapshot: JourneyConfigService.instance.cached,
      runDetail: runDetail,
    );
    // 击杀图鉴上报（分类型击杀 RPC 原子累加；终局无论胜败，best-effort）
    if (_game != null && _game!.killsByCode.isNotEmpty) {
      unawaited(JourneyKillStatsService.report(
        Map<String, int>.of(_game!.killsByCode),
      ));
    }
    if (!mounted) return;
    _lastResult = result;
    _lastGranted = granted;
    _lastFirstClear = firstClear && earnedPoint;
    _showSettlement();
  }

  void _showSettlement() {
    final result = _lastResult;
    if (result == null || !mounted || _settlementSheetOpen) return;
    _settlementSheetOpen = true;
    JourneySettlementSheet.show(
      context,
      result: result,
      meritGranted: _lastGranted,
      firstClear: _lastFirstClear,
      allowRetry: widget.level.kind != 'daily',
      onRetry: () {
        _lastResult = null; // 出口按钮已处理，关闭后无需重弹
        Navigator.of(context).pop(); // 关结算浮层
        // 清空对局再重建：加载期无残留引擎，重试重建完全重置
        _rebuild(() {
          _game = null;
          _controller = null;
          _gameWidget = null;
          _paused = false;
          _guideVisible = false;
          _loading = true;
        });
        _setup();
      },
      onExit: () {
        _lastResult = null;
        // 结算退出直达西行主页（结算浮层随 popUntil 一并出栈）
        popToHub();
      },
    ).then((_) {
      _settlementSheetOpen = false;
      if (!mounted) return;
      // 弹窗被非出口按钮途径关闭（对局已终局、引擎停止，不重弹会卡在
      // 无出口的对局页）：仍有结果就走持续重试，等旧浮层退场结束再弹，
      // 过渡期被占用则继续下一轮，避免一次性延迟 return 后无人再触发。
      if (_lastResult != null) _resumeSettlement();
    });
  }

  /// 结算浮层续弹兜底：结果仍在就持续重试，出口按钮已处理结果时停止。
  void _resumeSettlement() {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _lastResult == null) return;
      if (_settlementSheetOpen) {
        _resumeSettlement();
        return;
      }
      _showSettlement();
    });
  }

  /// 属性详情面板：顶部状态面板与暂停菜单共用同一 sheet。
  /// 查看属性先进入暂停浮层（引擎暂停、摇杆输入清空），关闭属性窗口后
  /// 仍保持暂停态，由浮层「继续战斗」统一恢复。
  void _showAttributes() {
    final game = _game;
    if (game == null || !mounted) return;
    if (!_paused) {
      _rebuild(() => _paused = true);
      game.pauseEngine();
      _controller?.input.reset();
    }
    JourneyAttributesSheet.show(context, game: game);
  }

  void _onBossSpawn(String bossName) {
    // 妖王降临（节点11）：改用开场横幅位展示（引擎 respawn 前调用）
    _controller?.hud.banner.value = '妖王降临 · $bossName';
    if (mounted) {
      _rebuild(() {});
    }
  }

  // ---- 还魂/炼化弹窗（节点5/8）：引擎弹窗期已 pauseEngine，UI 返回 bool ----

  Future<bool> _onRevivePrompt(int cost) async {
    if (!mounted) return false;
    final balance = JourneyProgressService.instance.state.meritBalance;
    final confirmed = await JourneyPromptSheets.showRevive(
      context,
      cost: cost,
      meritBalance: balance,
    );
    if (!confirmed || !mounted) return false;
    // 确认即扣功德（与局内确认价同源：基准价×当前角色等级并封顶）；
    // 扣费失败（结算期间余额变动不足）按拒绝处理走结算路径。弹窗关闭后
    // 引擎仍暂停，这段持久化往返用遮罩 loading 覆盖，避免静止画面像卡顿。
    final ok = await JourneyBusy.run(
      context,
      () => JourneyProgressService.instance
          .spendRevive(_controller?.hud.level.value ?? 1),
      label: '还魂中…',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('功德不足，还魂失败')),
      );
    }
    return ok;
  }

  Future<bool> _onAlchemyPrompt(String resultName) async {
    if (!mounted) return false;
    return JourneyPromptSheets.showAlchemy(context, resultName: resultName);
  }

  /// 主动结算（满足通关条件后的「结算」按钮/暂停面板「提前结算」）：
  /// 结算浮层由 _onFinished 链路弹出。
  void _earlySettle() {
    _game?.settleNow();
    if (mounted) _rebuild(() => _paused = false);
  }
}
