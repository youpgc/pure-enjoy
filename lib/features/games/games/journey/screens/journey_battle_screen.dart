import 'dart:async';

import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart';

import '../../../../../utils/cache_helper.dart';
import '../models/journey_models.dart';
import '../services/journey_config_service.dart';
import '../services/journey_kill_stats_service.dart';
import '../services/journey_progress_service.dart';
import '../services/journey_score_reporter.dart';
import '../services/journey_seed.dart' show kJourneyMonsterSeed;
import 'journey_battle_setup.dart';
import '../widgets/journey_theme.dart';
import '../widgets/journey_loading.dart';
import '../battle/journey_battle_controller.dart';
import '../battle/journey_battle_exit.dart';
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

part 'journey_battle_prepare.dart';
part 'journey_battle_callbacks.dart';

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
    with WidgetsBindingObserver, JourneyBattleExitMixin<JourneyBattleScreen> {
  JourneyFlameGame? _game;
  JourneyBattleController? _controller;

  /// 战斗画布实例缓存：摇杆/暂停等 setState 重建时以 identical 短路，
  /// 避免 GameWidget 内部 LayoutBuilder 反复重跑（其内含引擎 resize 空刷）。
  GameWidget? _gameWidget;
  bool _loading = true;
  bool _paused = false;
  int _runNonce = 0;

  // 退出拦截 mixin 所需的运行态（见 journey_battle_exit.dart）。
  @override
  JourneyFlameGame? get exitGame => _game;

  @override
  JourneyBattleController? get exitController => _controller;

  @override
  bool get exitPaused => _paused;

  /// 出战角色 code（HUD 顶部头像用；配置异常兜底时保持默认）。
  String _characterCode = 'tang';

  /// 三步引导（节点12）：标记不存在且 levelNo<=1 时展示（边玩边看）。
  bool _guideVisible = false;

  /// 升级/结算弹窗占用标记：防重弹 + 识别非选卡途径关闭（如系统返回键）。
  bool _levelUpSheetOpen = false;
  bool _settlementSheetOpen = false;
  JourneyRunResult? _lastResult;
  int _lastGranted = 0;
  bool _lastFirstClear = false;

  /// part 扩展共用的重建入口：扩展方法不属 State 实例成员，不能直接调 setState。
  void _rebuild(VoidCallback fn) => setState(fn);

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
    // PopScope 拦截系统返回键：对局中误触返回直接退出会丢进度，故改为弹
    // 确认弹窗（确认才退出，取消留局）。程序化退出走命令式 popUntil，可
    // 绕过本 PopScope（见 journey_battle_exit.dart 头注），故 canPop 恒 false。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        requestQuit();
      },
      child: Container(
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
              // 「功成」按钮（暂停键正上方）：满足通关条件（妖王伏诛/西行
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
                  onQuit: requestQuit,
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
