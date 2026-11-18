part of 'journey_battle_screen.dart';

/// 对局准备（extension，同 library 访问宿主私有成员）：配置拉取、角色校验、
/// 精灵预热、引擎装配与首次进关引导。
extension _JourneyBattlePrepare on _JourneyBattleScreenState {
  /// 本关怪物精灵预热名单：远端怪物池优先（后台新增怪种即时生效），
  /// 远端空回落内置种子；妖王/普通怪全预热（池随机 + 妖王据点守卫）。
  List<String> gamePoolCodes(JourneyConfigSnapshot? snapshot) {
    final remote = snapshot?.monsters;
    final source = (remote != null && remote.isNotEmpty)
        ? remote.map((m) => m.code)
        : kJourneyMonsterSeed.map((m) => m['code'] as String);
    return source.toSet().toList(growable: false);
  }

  Future<void> _setup() async {
    final snapshot = await JourneyConfigService.instance.fetch();
    final progress = JourneyProgressService.instance;
    await progress.ensureLoaded();
    if (!mounted) return;

    // 出战角色校验：未解锁/不存在回落初始角色唐僧
    JourneyCharacterModel? findChar(bool Function(JourneyCharacterModel) test) {
      for (final c in snapshot.characters) {
        if (test(c)) return c;
      }
      return null;
    }

    final state = progress.state;
    final character = findChar((c) =>
            c.code == progress.selectedCharacterCode &&
            state.characterUnlocked(c.code)) ??
        findChar((c) => state.characterUnlocked(c.code));
    if (character == null) {
      // 配置异常兜底：无可用角色直接退回上一页
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final controller = JourneyBattleController(
      themeColor: journeyThemeColorOf(widget.level, snapshot),
      onLevelUp: _onLevelUp,
      onFinished: _onFinished,
      onBossSpawn: _onBossSpawn,
      onRevivePrompt: _onRevivePrompt,
      onAlchemyPrompt: _onAlchemyPrompt,
    );
    controller.farthestAtStart = progress.state.farthestLevelNo;
    // 预热战斗精灵（怪种池/拾取物/出战角色/武器臂法器+被动加持）；
    // 失败由渲染层几何兜底。武器键不预热会导致环绕臂退化成圆点。
    final monsterCodes = gamePoolCodes(snapshot);
    await JourneySprites.warmUp(context, <String>[
      for (final c in monsterCodes) JourneySprites.monster(c),
      // 拾取物 7 种全覆盖（漏预热的 kind 会退化为色块圆点）
      JourneySprites.pickup('xianghuo'),
      JourneySprites.pickup('coin'),
      JourneySprites.pickup('peach'),
      JourneySprites.pickup('chest'),
      JourneySprites.pickup('yaodan'),
      JourneySprites.pickup('lingzhu'),
      JourneySprites.pickup('jinding'),
      JourneySprites.character(character.code),
      // 初始武器 + 被动加持资源（武器 SVG=纯武器内容）
      JourneySprites.weapon(character.weaponCode),
      for (final c in kJourneyPassiveEffects.keys) JourneySprites.weapon(c),
      // 场景道具（参照物供台/山石 + 路旁石碑/驿亭装饰）
      JourneySprites.prop('gongtai'),
      JourneySprites.prop('shikuai'),
      JourneySprites.prop('shibei'),
      JourneySprites.prop('yiting'),
    ]);
    if (!mounted) return;
    _runNonce++;
    // 单关运行时配置（波次/热区/参照物）：远端行 id 为空（内置兜底关卡）
    // 时返回空配置，引擎走兜底刷怪——按需拉取，不预载全关卡。
    final runtime =
        await JourneyConfigService.instance.fetchLevelRuntime(widget.level.id);
    if (!mounted) return;
    // 局外设置：环绕旋转方向（hub 设置面板可切换，默认顺时针）
    final spinRaw = await CacheHelper.instance.loadMap('journey_spin_dir');
    // 局外设置：全图追猎（仅无尽妖潮生效，默认关闭）
    final autoHuntRaw = await CacheHelper.instance.loadMap('journey_auto_hunt');
    if (!mounted) return;
    final newGame = JourneyFlameGame(
      level: widget.level,
      character: character,
      controller: controller,
      loadout: buildJourneyLoadout(progress.state, character.code),
      monsterCap: snapshot.monsterCap,
      config: snapshot,
      runtime: runtime,
    );
    newGame.spinDirection =
        (spinRaw?['dir'] as String? ?? 'cw') == 'ccw' ? -1.0 : 1.0;
    newGame.autoHuntSetting = autoHuntRaw?['enabled'] as bool? ?? false;
    _rebuild(() {
      _controller = controller;
      _game = newGame;
      _characterCode = character.code;
      _gameWidget = GameWidget(key: ValueKey(_runNonce), game: newGame);
      _loading = false;
    });
    // 开场横幅（节点11）：难名展示（覆盖层挂载后由横幅 host 补播本值）；
    // 无尽/游历为虚拟关（level_no=0），横幅直接用模式名/地图名
    controller.hud.banner.value = widget.level.levelNo > 0
        ? '第${widget.level.levelNo}难 · ${widget.level.title}'
        : widget.level.title;
    if (widget.level.kind == 'daily') {
      scheduleDailyMilestone(controller, widget.level,
          stillMounted: () => mounted);
    }
    _maybeShowGuide();
  }

  /// 首次进关三步引导（节点12）：标记不存在且 levelNo<=1 时展示，
  /// 进关横幅之后延迟 2.5s 出现；轻引导不暂停引擎（边玩边看）。
  Future<void> _maybeShowGuide() async {
    if (widget.level.levelNo > 1 || _guideVisible) return;
    final raw = await CacheHelper.instance.loadMap('journey_guide_done');
    if (raw?['done'] == true || !mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_guideVisible) {
        _rebuild(() => _guideVisible = true);
      }
    });
  }
}
