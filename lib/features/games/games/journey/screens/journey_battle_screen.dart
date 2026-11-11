import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';

import '../../../../../utils/cache_helper.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_score_reporter.dart';
import '../services/journey_seed.dart' show kJourneyMonsterSeed;
import 'journey_battle_setup.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_loading.dart';
import '../battle/journey_battle_controller.dart';
import '../battle/journey_battle_overlays.dart';
import '../battle/journey_attributes_sheet.dart';
import '../battle/journey_flame_game.dart';
import '../battle/journey_sprites.dart';
import '../battle/journey_levelup_sheet.dart';
import '../battle/journey_settlement_sheet.dart';
import '../battle/journey_hud_overlay.dart';
import '../battle/journey_hit_vignette.dart';
import '../widgets/journey_busy.dart';
import '../battle/journey_settle_button.dart';

/// 局内对局页：Flame 战斗 + HUD 覆盖层 + 虚拟摇杆 + 升级/结算弹窗。
///
/// 平铺大地图全向自由探索；摇杆全屏左下区（动态浮现），环绕法宝自动收割。
class JourneyBattleScreen extends StatefulWidget {
  const JourneyBattleScreen({super.key, required this.level});

  final JourneyLevelModel level;

  @override
  State<JourneyBattleScreen> createState() => _JourneyBattleScreenState();
}

class _JourneyBattleScreenState extends State<JourneyBattleScreen>
    with WidgetsBindingObserver {
  JourneyFlameGame? _game;
  JourneyBattleController? _controller;

  /// 战斗画布实例缓存：摇杆/暂停等 setState 重建时以 identical 短路，
  /// 避免 GameWidget 内部 LayoutBuilder 反复重跑（其内含引擎 resize 空刷）。
  GameWidget? _gameWidget;
  bool _loading = true;
  bool _paused = false;
  int _runNonce = 0;

  /// 出战角色 code（HUD 顶部头像用；配置异常兜底时保持默认）。
  String _characterCode = 'tang';

  /// 三步引导（节点12）：标记不存在且 levelNo<=1 时展示（边玩边看）。
  bool _guideVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.input.reset();
    super.dispose();
  }

  /// 断局口径（切后台=自动暂停）：回前台/熄屏/切走即暂停对局，防挂机白嫖。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_paused) _togglePause();
    }
  }

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
      'assets/games/journey/pickup_xianghuo.svg',
      'assets/games/journey/pickup_coin.svg',
      'assets/games/journey/pickup_peach.svg',
      'assets/games/journey/pickup_chest.svg',
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
    final runtime = await JourneyConfigService.instance
        .fetchLevelRuntime(widget.level.id);
    if (!mounted) return;
    // 局外设置：环绕旋转方向（hub 设置面板可切换，默认顺时针）
    final spinRaw = await CacheHelper.instance.loadMap('journey_spin_dir');
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
    setState(() {
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
        setState(() => _guideVisible = true);
      }
    });
  }

  // ---- 引擎回调 ----

  /// 升级/结算弹窗占用标记：防重弹 + 识别非选卡途径关闭（如系统返回键）。
  bool _levelUpSheetOpen = false;
  JourneyRunResult? _lastResult;
  int _lastGranted = 0;
  bool _lastFirstClear = false;

  void _onLevelUp(int newLevel, {required bool paused}) {
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
      // 弹窗被非选卡途径关闭时选卡仍未完成 → 延迟重弹（等旧浮层退场动画
      // 结束，避免过渡期间 push 触发 Navigator 锁断言），
      // 否则引擎停在选卡暂停态再无出口（死锁）。
      if (game.isPausedForLevelUp) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          if (game.isPausedForLevelUp) {
            _onLevelUp(game.controller.hud.level.value, paused: true);
          }
        });
      }
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
      // 对局记录/结算标题统一带关号（虚拟关保持模式名/地图名）
      levelTitle: widget.level.levelNo > 0
          ? '第${widget.level.levelNo}难 · ${widget.level.title}'
          : widget.level.title,
    );
    // 首通判定：通关且超越进关时的最远记录（与引擎发奖口径一致）。
    final firstClear =
        cleared && widget.level.levelNo > (_controller?.farthestAtStart ?? 0);
    final (granted, earnedPoint) = await JourneyBusy.run(
      context,
      () => JourneyProgressService.instance.settleRun(
        merit: result.meritTotal,
        kills: kills,
        levelNo: widget.level.levelNo,
        durationMs: durationSec * 1000,
        cleared: cleared,
        kind: widget.level.levelNo > 0 ? 'mainline' : widget.level.kind,
        // 对局记录标题统一带关号（与结算浮层同源）
        levelTitle: result.levelTitle,
      ),
      label: '结算中…',
    );
    // 每日游历 gate 已在进关入口写入（进入即计次，主动放弃同样占次），
    // 此处不再重复写。
    // 成绩上报（成绩看板/排行榜/数据分析链路；未就绪静默跳过）
    JourneyScoreReporter.report(
      result: result,
      cleared: cleared,
      levelId: widget.level.id,
      snapshot: JourneyConfigService.instance.cached,
    );
    if (!mounted) return;
    _lastResult = result;
    _lastGranted = granted;
    _lastFirstClear = firstClear && earnedPoint;
    _showSettlement();
  }

  void _showSettlement() {
    final result = _lastResult;
    if (result == null || !mounted) return;
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
        setState(() {
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
        _popToHub();
      },
    ).then((_) {
      if (!mounted) return;
      // 弹窗被非出口按钮途径关闭（对局已终局、引擎停止，不重弹会卡在
      // 无出口的对局页）：延迟重弹，等旧浮层退场动画结束防过渡期 push 断言。
      if (_lastResult != null) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!mounted || _lastResult == null) return;
          _showSettlement();
        });
      }
    });
  }

  /// 退回西行主页：沿途弹掉结算/暂停浮层与对局、关卡选择页。
  /// isFirst 保底：路由名缺失时至少停在栈根，避免把整栈弹空。
  void _popToHub() {
    Navigator.of(context).popUntil(
      (r) => r.settings.name == 'journey_hub' || r.isFirst,
    );
  }

  /// 属性详情面板：顶部状态面板与暂停菜单共用同一 sheet。
  /// 查看属性先进入暂停浮层（引擎暂停、摇杆输入清空），关闭属性窗口后
  /// 仍保持暂停态，由浮层「继续战斗」统一恢复。
  void _showAttributes() {
    final game = _game;
    if (game == null || !mounted) return;
    if (!_paused) {
      setState(() => _paused = true);
      game.pauseEngine();
      _controller?.input.reset();
    }
    JourneyAttributesSheet.show(context, game: game);
  }

  void _onBossSpawn(String bossName) {
    // 妖王降临（节点11）：改用开场横幅位展示（引擎 respawn 前调用）
    _controller?.hud.banner.value = '妖王降临 · $bossName';
    if (mounted) {
      setState(() {});
    }
  }

  // ---- 还魂/炼化弹窗（节点5/8）：引擎弹窗期已 pauseEngine，UI 返回 bool ----

  Future<bool> _onRevivePrompt(int cost) async {
    if (!mounted) return false;
    final balance = JourneyProgressService.instance.state.meritBalance;
    return JourneyPromptSheets.showRevive(
      context,
      cost: cost,
      meritBalance: balance,
    );
  }

  Future<bool> _onAlchemyPrompt(String resultName) async {
    if (!mounted) return false;
    return JourneyPromptSheets.showAlchemy(context, resultName: resultName);
  }

  /// 主动结算（满足通关条件后的「结算」按钮/暂停面板「提前结算」）：
  /// 结算浮层由 _onFinished 链路弹出。
  void _earlySettle() {
    _game?.settleNow();
    if (mounted) setState(() => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).viewPadding.top;
    final bottoms = journeyControlBottoms(screenH: screenH, topInset: topInset);
    final double pauseBottom = bottoms.$1;
    final settleBottom = bottoms.$2;
    // 全屏沉浸：不包 SafeArea（状态栏/手势区也画游戏与蒙层，修「蒙层
    // 上下留白」），HUD 自行下移状态栏高度；DefaultTextStyle 显式无装饰
    // （文字继承链路出现金色下划线，对局内一律无下划线）。
    return Container(
      color: JourneyTheme.bgDeep,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Stack(
          children: <Widget>[
            // 战斗画布（key 随重建计数变化，保证重试时引擎完全重建）
            if (_gameWidget != null) _gameWidget!,
            if (_loading)
              const Center(
                child: JourneyLoading(label: '进入此难…'),
              ),
            // 受击提醒：屏幕边缘泛红呼吸，位于 HUD 之下不遮挡信息
            if (_controller != null)
              Positioned.fill(
                child: JourneyHitVignette(controller: _controller!),
              ),
            // HUD 覆盖层（头像/血条/经验/状态行 + 槽栏 + 妖王罗盘 + 大血条/小地图/横幅）
            if (_controller != null)
              JourneyHudOverlay(
                controller: _controller!,
                characterCode: _characterCode,
                onTopPanelTap: _showAttributes,
              ),
            // 虚拟摇杆（下半屏任意触点按下；手势状态由组件自管）
            if (_controller != null)
              JourneyJoystick(
                controller: _controller!,
                onEngage: _onJoystickEngage,
              ),
            // 暂停按钮：叠在摇杆触控区之上，命中优先按钮；与功成按钮
            // 同款圆形底板，位置随摇杆区顶边上移
            if (_controller != null)
              JourneyPauseButton(onTap: _togglePause, bottom: pauseBottom),
            // 「功成」按钮（暂停键正上方）：满足通关条件（妖王伏诛/坚持
            // 功成/无尽末波）后亮出，点击即主动结算；未满足时隐藏
            if (_controller != null)
              ValueListenableBuilder<bool>(
                valueListenable: _controller!.hud.bossDefeated,
                builder: (context, available, _) => available
                    ? JourneySettleButton(
                        onTap: _earlySettle,
                        bottom: settleBottom,
                      )
                    : const SizedBox.shrink(),
              ),
            if (_paused)
              JourneyPauseOverlay(
                onResume: _togglePause,
                onAttributes: _showAttributes,
                onQuit: _popToHub,
                // 妖王伏诛后可用：提前结算（金色主按钮）
                onEarlySettle:
                    (_game?.bossDefeated ?? false) ? _earlySettle : null,
              ),
            // 三步引导（节点12）：首次进关逐页点按推进，边玩边看
            if (_guideVisible)
              JourneyGuideOverlay(
                onFinished: () => setState(() => _guideVisible = false),
              ),
          ],
        ),
      ),
    );
  }

  void _togglePause() {
    final game = _game;
    if (game == null || game.isEnded) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      game.pauseEngine();
      _controller?.input.reset();
    } else {
      // 升级选卡造成的引擎暂停不在此恢复：选卡期间世界必须静止，
      // 恢复由最后一张选卡后的 applyUpgrade 负责。
      if (!game.isPausedForLevelUp) game.armJoystickResume();
    }
  }

  /// 玩家按下摇杆：结束等待接管态，正式恢复对局运行。
  void _onJoystickEngage() => _game?.resumeFromJoystick();
}
