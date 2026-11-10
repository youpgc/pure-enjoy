part of 'game_home_screen.dart';

// 主界面的引导弹窗、导航跳转与模式点击分流逻辑；与主文件同库、共享其 import。
// 【误报说明】extension 内调用 _load/_refreshDailyDone 等 State 私有方法，分析器
// 对 part+extension 的隐式引用计数有漏计，可能误报 unused_element；运行期语义安全。
// ignore_for_file: unused_element

extension _GameHomeScreenActions on _GameHomeScreenState {
  void _showGuide() {
    final guide = gameGuideOf(widget.game);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SheetContainer(
        // 手势条 SafeArea（统一容器规范）；内容自带可拖拽滚动，scrollable=false
        scrollable: false,
        padding: EdgeInsets.zero,
        bottomSpacing: 0,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: <Widget>[
            Text(guide.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (guide.intro != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(guide.intro!, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 16),
            ...guide.sections.map((s) => _GuideSectionView(section: s)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _openBest() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameBestScreen(game: widget.game)),
    );
  }

  /// 排行榜（P2）：总榜/周榜，跨玩家最佳成绩（入口仅游戏详情页）
  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => GameLeaderboardScreen(game: widget.game)),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameHistoryScreen(game: widget.game)),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameItemShopScreen(game: widget.game)),
    );
  }

  /// 模式点击分流：
  /// - 自由模式：弹难度档位选择，按档合成关开局（反复游玩，按局发分）；
  /// - 无尽模式（endless）：无具体关，直接开合成无尽局；
  /// - 允许选关（后台 level_selectable=true 且 levelSelect 节点开启）：
  ///   打开选关弹窗（按 mode_id 过滤该模式关卡）；
  /// - 关闭选关：不弹选关，直接进该模式的最新关卡（frontier：
  ///   第一个未通关，全通关取末关）。
  Future<void> _onModeTap(GameModeModel mode) async {
    // 自由模式（常驻经典）：档位来自后台 mode.config.tiers，
    // 选档后合成关开局；积分=档位配置，结算只发按局可重复奖励一类。
    if (mode.isFreeMode) {
      final tier = await GameFreeModeSheet.show(
        context: context,
        mode: mode,
        gameCode: widget.game.code,
      );
      if (!mounted || tier == null) return;
      final lv = GameLevelModel.freeMode(
        gameId: widget.game.id,
        gameCode: widget.game.code,
        modeId: mode.id,
        tierKey: tier['key']?.toString() ?? 'classic',
        tierName: tier['name']?.toString() ?? '经典',
        points: (tier['points'] as num?)?.toInt() ?? 0,
        tierConfig: (tier['config'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
        modeName: mode.name,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(game: widget.game, level: lv),
        ),
      );
      if (mounted) await _load(force: true);
      return;
    }
    if (mode.isEndless) {
      final lv = GameLevelModel.endless2048(
        gameId: widget.game.id,
        modeId: mode.id,
        size: 4,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(game: widget.game, level: lv),
        ),
      );
      if (mounted) await _load(force: true);
      return;
    }
    // 俄罗斯方块每日挑战：无 server 关，直接开当日种子合成关
    //（奖励走 daily_first_clear 日期幂等；返回后刷新完成标记）
    if (_isDailyMode(mode)) {
      final lv = GameLevelModel.tetrisDaily(
        gameId: widget.game.id,
        modeId: mode.id,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(game: widget.game, level: lv),
        ),
      );
      if (mounted) await _refreshDailyDone();
      return;
    }
    final selectable =
        widget.game.levelSelectable && (_flow?.levelSelectAvailable ?? false);
    if (!selectable) {
      final plan = GameFlowRunner.instance.resolvePlayPlan(
        widget.game,
        modeId: mode.id,
        levels: _levels,
        clearedIds: _clearedIds,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(game: widget.game, level: plan.level),
        ),
      );
      if (mounted) await _load(force: true);
      return;
    }
    await _openPickerForMode(mode);
  }

  Future<void> _openPickerForMode(GameModeModel mode) async {
    await GameLevelPicker.show(
      context: context,
      game: widget.game,
      levels: _levels,
      clearedIds: _clearedIds,
      mode: mode,
    );
    if (mounted) await _load(force: true);
  }
}
