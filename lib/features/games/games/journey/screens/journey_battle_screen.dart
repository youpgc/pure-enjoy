import 'dart:math' as math;

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_score_reporter.dart';
import '../services/journey_seed.dart' show kJourneyMonsterSeed;
import '../widgets/journey_theme.dart';
import '../widgets/journey_widgets.dart';
import '../widgets/journey_loading.dart';
import '../battle/journey_battle_controller.dart';
import '../battle/journey_attributes_sheet.dart';
import '../battle/journey_flame_game.dart';
import '../battle/journey_sprites.dart';
import '../battle/journey_levelup_sheet.dart';
import '../battle/journey_settlement_sheet.dart';
import '../battle/journey_hud_overlay.dart';

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
  Offset _stickDelta = Offset.zero;
  Offset? _stickBase; // 底座浮现位置（跟随触点，动态摇杆）

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

  void _onStickUpdate(DragUpdateDetails d) {
    if (_stickBase == null) return;
    final delta = d.localPosition - _stickBase!;
    const maxR = 46.0;
    final clamped =
        delta.distance <= maxR ? delta : delta / delta.distance * maxR;
    setState(() => _stickDelta = clamped);
    _controller?.input.vector = clamped / maxR;
  }

  void _onStickEnd(DragEndDetails d) {
    setState(() {
      _stickBase = null;
      _stickDelta = Offset.zero;
    });
    _controller?.input.reset();
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
      themeColor:
          snapshot.regionOf(widget.level.regionCode)?.themeColor ?? '#E8C470',
      onLevelUp: _onLevelUp,
      onFinished: _onFinished,
      onBossSpawn: _onBossSpawn,
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
    ]);
    if (!mounted) return;
    _runNonce++;
    // 单关运行时配置（波次/热区/参照物）：远端行 id 为空（内置兜底关卡）
    // 时返回空配置，引擎走兜底刷怪——按需拉取，不预载全关卡。
    final runtime = await JourneyConfigService.instance
        .fetchLevelRuntime(widget.level.id);
    if (!mounted) return;
    final newGame = JourneyFlameGame(
      level: widget.level,
      character: character,
      controller: controller,
      loadout: _buildLoadout(progress.state),
      monsterCap: snapshot.monsterCap,
      config: snapshot,
      runtime: runtime,
    );
    setState(() {
      _controller = controller;
      _game = newGame;
      _gameWidget = GameWidget(key: ValueKey(_runNonce), game: newGame);
      _loading = false;
    });
  }

  /// 局外预注入：已点天赋层映射为对局初始增量（轻量口径，灼烧/暴击/击退
  /// 等战斗未支持的属性暂不接入，标志层走独立效果）。
  JourneyLoadout _buildLoadout(JourneyProgressModel p) {
    int lv(String e) => p.talentLevelsOf(e);
    bool sig(String e) => p.talentPointsOf(e, 17) > 0;
    return JourneyLoadout(
      damageAmp: lv('metal') * 0.02 + lv('fire') * 0.03,
      spinAmp: lv('water') * 0.03,
      armorFlat: lv('earth') * 0.8,
      bonusMaxHp: lv('wood') * 6.0,
      regenFlat: lv('wood') * 0.15,
      pickupRangeFlat: lv('earth') * 5.0,
      signatures: <String>{
        for (final e in const <String>['metal', 'wood', 'water', 'fire', 'earth'])
          if (sig(e)) 'signature_$e',
      },
    );
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
      levelTitle: widget.level.title,
    );
    // 首通判定：通关且超越进关时的最远记录（与引擎发奖口径一致）。
    final firstClear =
        cleared && widget.level.levelNo > (_controller?.farthestAtStart ?? 0);
    final (granted, earnedPoint) =
        await JourneyProgressService.instance.settleRun(
      merit: result.meritTotal,
      kills: kills,
      levelNo: cleared ? widget.level.levelNo : 0,
    );
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
      onRetry: () {
        _lastResult = null; // 出口按钮已处理，关闭后无需重弹
        Navigator.of(context).pop(); // 关结算浮层
        // 清空对局再重建：加载期无残留引擎，重试重建完全重置
        setState(() {
          _game = null;
          _controller = null;
          _gameWidget = null;
          _paused = false;
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

  void _onBossSpawn(String bossName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('妖王降临 · $bossName'),
        backgroundColor: JourneyTheme.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---- 摇杆（处理器见 _onStickStart/_onStickUpdate/_onStickEnd） ----

  @override
  Widget build(BuildContext context) {
    return Container(
      color: JourneyTheme.bgDeep,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            // 战斗画布（key 随重建计数变化，保证重试时引擎完全重建）
            if (_gameWidget != null) _gameWidget!,
            if (_loading)
              const Center(
                child: JourneyLoading(label: '进入此难…'),
              ),
            // HUD 覆盖层（血条/经验/状态行 + 妖王罗盘）
            if (_controller != null)
              JourneyHudOverlay(controller: _controller!),
            // 虚拟摇杆（左下，动态浮现）
            _buildJoystick(),
            // 暂停按钮（右上角第一位，罗盘列在其下方，避免重叠）
            Positioned(
              top: 4,
              right: 10,
              child: IconButton(
                onPressed: _togglePause,
                icon: const Icon(Icons.pause_circle_outline,
                    color: JourneyTheme.textPrimary, size: 30),
              ),
            ),
            if (_paused) _buildPauseOverlay(),
          ],
        ),
      ),
    );
  }


  /// 虚拟摇杆：触点处动态浮现底座（左下操作区），拖移驱动摇杆帽。
  Widget _buildJoystick() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 底座 104：触点贴边时中心钳进安全区，底座始终完整可见不截断
          const half = 52.0;
          double clampX(double x) =>
              x.clamp(half, math.max(half, constraints.maxWidth - half));
          double clampY(double y) =>
              y.clamp(half, math.max(half, constraints.maxHeight - half));
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _onStickStart(d, clampX, clampY),
            onPanUpdate: _onStickUpdate,
            onPanEnd: _onStickEnd,
            child: Container(
              height: 170,
              color: Colors.transparent,
              child: _stickBase == null
                  ? const SizedBox.expand()
                  : Stack(
                      children: <Widget>[
                        Positioned(
                          left: _stickBase!.dx - 52,
                          top: _stickBase!.dy - 52,
                          child: SvgPicture.asset(
                            'assets/games/journey/stick_base.svg',
                            width: 104,
                            height: 104,
                          ),
                        ),
                        Positioned(
                          left: _stickBase!.dx + _stickDelta.dx - 24,
                          top: _stickBase!.dy + _stickDelta.dy - 24,
                          child: SvgPicture.asset(
                            'assets/games/journey/stick_cap.svg',
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  void _onStickStart(
    DragStartDetails d,
    double Function(double) clampX,
    double Function(double) clampY,
  ) {
    setState(() {
      // 中心钳进安全区：贴边触点也完整显示底座；拖移 delta 以可见中心为基准
      _stickBase =
          Offset(clampX(d.localPosition.dx), clampY(d.localPosition.dy));
      _stickDelta = Offset.zero;
    });
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
      if (!game.isPausedForLevelUp) game.resumeEngine();
    }
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: JourneyTheme.bgDeep.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: SizedBox(
        width: 240,
        child: JourneyPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('暂 停', style: JourneyTheme.titleLg),
              const SizedBox(height: 14),
              JourneyButton(
                text: '继续战斗',
                onTap: _togglePause,
              ),
              const SizedBox(height: 10),
              JourneyButton(
                text: '属性详情',
                secondary: true,
                onTap: () {
                  final game = _game;
                  if (game != null) {
                    JourneyAttributesSheet.show(context, game: game);
                  }
                },
              ),
              const SizedBox(height: 10),
              JourneyButton(
                text: '放弃本难（不发奖）',
                secondary: true,
                onTap: _popToHub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
