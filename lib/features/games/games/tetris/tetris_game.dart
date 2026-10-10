import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../services/game_service.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_shell.dart';
import 'tetris_mode.dart';
import 'tetris_props.dart';

// 【文件拆分】单文件 ≤500 行红线：本文件为宿主 State（配置/HUD/流程），
// 引擎逻辑见 tetris_engine.dart（part）、渲染见 tetris_board.dart（part）、
// 手势与按钮行见 tetris_input.dart（part）、垃圾行系统见 tetris_garbage.dart（part）、
// 道具栏与道具执行见 tetris_props_actions.dart（part，二期）。
part 'tetris_engine.dart';
part 'tetris_board.dart';
part 'tetris_input.dart';
part 'tetris_garbage.dart';
part 'tetris_props_actions.dart';

/// 俄罗斯方块（市场驱动一期「标准四艺」）
///
/// 操作：左右滑/拖=移动、下滑=软降、快速下滑=硬降、点按棋盘=顺时针旋转；
/// 底部辅助按钮行（Hold/⟲/←/↓/→）config `buttons` 可关。
///
/// 现代机制：7-bag 发牌 / SRS+踢墙 / ghost / Next×3 / Hold / lock delay 500ms；
/// 计分深度：T-Spin / B2B×1.5 / Combo / Perfect Clear / Frenzy（blitz 专属）。
/// 模式行为全部由 `game_levels.config` 驱动（真相源 §2.4/§6.5），引擎零硬编码分值。
class TetrisGame extends StatefulWidget {
  /// 结束回调（结算协议见 GamePlayOutcome）
  final void Function(GamePlayOutcome) onFinished;

  /// 当前关卡（config 含 lines/score_target/fall_ms/...）
  final GameLevelModel level;

  /// 宿主重开回调（aborted 上报 + 引擎重建，三游戏统一口径）
  final VoidCallback? onRestart;

  const TetrisGame({
    super.key,
    required this.onFinished,
    required this.level,
    this.onRestart,
  });

  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  // ───────── 模式与配置（config 驱动，带默认兜底） ─────────
  late TetrisMode _mode;
  int _linesTarget = 0;
  int _scoreTarget = 0;
  int? _timeLimit; // 秒
  int? _piecesLimit;
  late int _fallMsBase;
  late int _fallMin;
  late int _levelUpLines; // 局内下落加速开关（每 N 行升一级，0=禁用）
  late double _speedFactor;
  late bool _frenzyEnabled;
  late bool _holdEnabled;
  late bool _buttonsEnabled;
  late bool _ghostEnabled;
  int _nextPreview = 3;

  /// lock delay 刷新上限（防触底后无限拖延）
  static const int _kMaxLockResets = 15;
  static const int _kLockDelayMs = 500;

  // ───────── 引擎状态（tetris_engine.dart 消费） ─────────
  List<List<int?>> _board = <List<int?>>[];
  final List<Tetromino> _bag = <Tetromino>[];
  final List<QueuedPiece> _queue = <QueuedPiece>[];
  Piece? _current;
  Tetromino? _held;

  /// 暂存块的特殊标记（三期 T3-02：Hold 交换时随 _held 一起保存/恢复，
  /// 防止炸弹/重块经 Hold 变普通块）
  TetrisSpecial _heldSpecial = TetrisSpecial.none;
  bool _holdUsed = false;
  Piece? get currentPiece => _current;

  bool _finished = false;
  int _score = 0;
  int _linesTotal = 0;
  int _scoreLevel = 1;
  int _piecesPlaced = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _b2bActive = false;
  int _b2bChain = 0;
  int _maxB2b = 0;
  int _tetrisCount = 0;
  int _tspinCount = 0;
  int _perfectClears = 0;

  _TetrisAction _lastAction = _TetrisAction.spawn;
  int _lastKickIndex = -1;

  /// 重力间隔（marathon 局内加速时动态变化）
  late int _currentFallMs;

  /// 计时基准（非 final：重开必须重置，g2048 同坑）
  DateTime _startTime = DateTime.now();

  // 计时器组
  Timer? _gravityTimer;
  Timer? _lockTimer;
  Timer? _tickTimer; // blitz 倒计时 / survival 顶起倒计时轮询
  Timer? _flashTimer; // 消行闪烁动画（90ms × 4 相位）
  int _lockResets = 0;
  int _lastTickSecond = -1;

  /// 消行闪烁动画：正在闪烁的满行行号 + 当前相位（0..3，亮暗交替）
  List<int> _flashRows = <int>[];
  int _flashPhase = 0;

  /// 消行大字特效（board 上层浮现）
  final List<_TetrisFx> _fxMessages = <_TetrisFx>[];

  /// 棋盘内容版本号：board 原地写改（锁定/消行/重置）时递增，
  /// 供 painter shouldRepaint 精确判重（不依赖 current 间接覆盖——
  /// 二期 garbage 顶起只改 board 不动 current，无此旗标会漏重绘）。
  int _boardRev = 0;

  // ───────── 二期：dig / survival / 每日挑战 / 道具 ─────────

  /// dig 预填垃圾行数（config `dig_rows`，0=非 dig）
  int _digRows = 0;

  /// survival 垃圾顶起间隔秒（config `garbage_interval`，0=非 survival）
  int _garbageInterval = 0;
  Timer? _garbageTimer;

  /// 下次顶起时刻（survival HUD 倒计时）
  DateTime _garbageNextPushAt = DateTime.now();

  /// 垃圾行公平洞位（相邻行不同列）
  int _lastGarbageHole = -1;

  /// 本局清除的垃圾行数（digger 成就 / `garbage_cleared` 判定维度）
  int _garbageCleared = 0;

  /// 每日挑战：config `seed_daily=true` 时以北京日期派生发牌种子
  bool _seedDaily = false;

  // ───────── 三期：Boss 战 / 特殊方块 ─────────

  /// Boss 当前/最大血量（config `boss_hp`>0 启用；伤害模型见真相源三期）
  int _bossHp = 0;
  int _bossMaxHp = 0;

  /// 特殊方块注入概率（config `special_chance`，0..1；0=不注入）
  double _specialChance = 0;

  /// 已解析的随机源（daily 模式为日期种子实例，其余随机）
  late Random _rng;

  /// 道具域（数据驱动：game_items enabled=false 起步，由后台开启）
  final TetrisProps _props = TetrisProps();

  /// 时缓卡生效截止时刻（null=未生效）
  DateTime? _slowUntil;

  /// 每日挑战当前北京日期键（[_initRng] 填充；完成标记用）
  String _dailyDateKey = '';

  /// 初始化随机源：每日挑战 = `'tetris' + 北京日期` 自制哈希种子
  ///（跨会话稳定、同日全员同序列），其余系统熵。须在 [_reset] 洗牌前调用。
  void _initRng() {
    if (!_seedDaily) {
      _rng = Random();
      return;
    }
    final b = DateTime.now().toUtc().add(const Duration(hours: 8));
    _dailyDateKey = '${b.year.toString().padLeft(4, '0')}'
        '${b.month.toString().padLeft(2, '0')}'
        '${b.day.toString().padLeft(2, '0')}';
    var h = 0;
    for (final c in ('tetris$_dailyDateKey').codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    _rng = Random(h);
  }

  /// 手势用单格尺寸（board 布局时回填）
  double _cellExtent = 24;

  /// 手势累计位移（input 层消费）
  double _dragDx = 0;
  double _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _parseModeAndConfig();
    _reset();
    // 道具目录/库存异步加载（失败不影响对局；数据驱动 enabled 后台控制）
    _loadProps();
  }

  void _parseModeAndConfig() {
    String playKind = '';
    final cfg = widget.level.config;
    if (widget.level.modeId.isNotEmpty) {
      for (final m in GameService.instance.cachedConfig.modesOf(widget.level.gameId)) {
        if (m.id == widget.level.modeId) {
          playKind = m.playKind;
          break;
        }
      }
    }
    _mode = resolveTetrisMode(playKind: playKind, config: cfg);
    _linesTarget = _intOf(cfg['lines'], 0);
    _scoreTarget = _intOf(cfg['score_target'], 0);
    _timeLimit = _intOf(cfg['time_limit'], 0) > 0 ? _intOf(cfg['time_limit'], 0) : null;
    _piecesLimit = _intOf(cfg['max_pieces'], 0) > 0 ? _intOf(cfg['max_pieces'], 0) : null;
    // 下落间隔按模式兜底（sprint 800 恒速 / blitz·challenge·dig·survival 900）
    final fallbackFall = switch (_mode) {
      TetrisMode.marathon => 1000,
      TetrisMode.sprint => 800,
      _ => 900,
    };
    _fallMsBase = max(80, _intOf(cfg['fall_ms'], fallbackFall));
    final fallbackMin = _mode == TetrisMode.marathon ? 60 : 80;
    _fallMin = max(50, _intOf(cfg['fall_min'], fallbackMin));
    _levelUpLines = _intOf(cfg['level_up_lines'], _mode == TetrisMode.marathon ? 10 : 0);
    _speedFactor = (cfg['speed_factor'] is num)
        ? (cfg['speed_factor'] as num).toDouble()
        : 0.85;
    _frenzyEnabled = _mode == TetrisMode.blitz && cfg['frenzy'] != false;
    _holdEnabled = cfg['hold'] != false;
    _buttonsEnabled = cfg['buttons'] != false;
    _ghostEnabled = cfg['ghost'] != false;
    _nextPreview = _intOf(cfg['next'], 3).clamp(1, 5);
    // 二期：dig 预填 / survival 顶起 / 每日挑战种子
    _digRows = _intOf(cfg['dig_rows'], 0);
    _garbageInterval = _intOf(cfg['garbage_interval'], 0);
    _seedDaily = cfg['seed_daily'] == true || _mode == TetrisMode.daily;
    _specialChance = (cfg['special_chance'] is num)
        ? (cfg['special_chance'] as num).toDouble().clamp(0.0, 1.0)
        : 0.0;
    _bossMaxHp = _intOf(cfg['boss_hp'], 0);
    _bossHp = _bossMaxHp;
    _initRng();
  }

  int _intOf(dynamic v, int fallback) =>
      v is int ? v : (v is num ? v.toInt() : fallback);

  void _reset() {
    _flashTimer?.cancel();
    _flashRows = <int>[];
    _flashPhase = 0;
    _board = List<List<int?>>.generate(
        kTetrisRows, (_) => List<int?>.filled(kTetrisCols, null));
    _boardRev++;
    _bag.clear();
    _queue.clear();
    while (_queue.length <= _nextPreview) {
      _queue.add(_nextFromBag());
    }
    _current = null;
    _held = null;
    _heldSpecial = TetrisSpecial.none;
    _holdUsed = false;
    _finished = false;
    _score = 0;
    _linesTotal = 0;
    _scoreLevel = 1;
    _piecesPlaced = 0;
    _combo = 0;
    _maxCombo = 0;
    _b2bActive = false;
    _b2bChain = 0;
    _maxB2b = 0;
    _tetrisCount = 0;
    _tspinCount = 0;
    _perfectClears = 0;
    _fxMessages.clear();
    _lockResets = 0;
    _lastTickSecond = -1;
    _currentFallMs = _fallMsBase;
    _garbageCleared = 0;
    _lastGarbageHole = -1;
    _slowUntil = null; // 时缓不跨局（重开后重力间隔恢复原速）
    _bossHp = _bossMaxHp; // Boss 血量每局回满
    _startTime = DateTime.now();
    // dig：先预填垃圾行再落首块（board 为空，直接写底部）
    if (_mode == TetrisMode.dig && _digRows > 0) {
      _prefillGarbage(_digRows);
    }
    _restartGravityTimer();
    _startTickTimer();
    _startGarbageTimer();
    _spawnPiece();
  }

  // ───────── 计时器管理 ─────────

  /// survival 垃圾顶起定时器（周期恒定 = config `garbage_interval`）；
  /// 顶起溢出（顶行有块/当前块碰撞）按 Block Out 结算（survival 口径 lines 判定）。
  void _startGarbageTimer() {
    _garbageTimer?.cancel();
    if (_garbageInterval <= 0) return;
    _garbageNextPushAt = DateTime.now().add(Duration(seconds: _garbageInterval));
    _garbageTimer = Timer.periodic(Duration(seconds: _garbageInterval), (_) {
      if (_finished) {
        _garbageTimer?.cancel();
        return;
      }
      _garbageNextPushAt = DateTime.now().add(Duration(seconds: _garbageInterval));
      if (!_pushGarbageRow()) {
        _onBlockOut();
      }
    });
  }

  void _restartGravityTimer() {
    _gravityTimer?.cancel();
    // 时缓卡生效期间下落间隔 ×2（与 marathon 局内加速叠加）
    final ms = _currentFallMs * (_isSlowed ? 2 : 1);
    _gravityTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      _gravityTick();
    });
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(milliseconds: _kLockDelayMs), () {
      _lockPiece();
    });
  }

  void _restartLockTimer() => _startLockTimer();

  void _cancelLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  /// blitz 倒计时 / survival 顶起倒计时轮询（250ms 轮询、整秒变化才重建，g2048 同款节流）
  void _startTickTimer() {
    _tickTimer?.cancel();
    if (_timeLimit == null && _garbageInterval <= 0) return;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_finished) {
        timer.cancel();
        return;
      }
      if (_timeLimit != null && _remainingSeconds() <= 0) {
        _finish(_scoreTarget > 0 && _score >= _scoreTarget,
            reason: '时间到');
        return;
      }
      final s = _hudSecond();
      if (s != _lastTickSecond) {
        _lastTickSecond = s;
        if (mounted) setState(() {});
      }
    });
  }

  /// HUD 秒级刷新值：限时模式=剩余秒；survival=顶起倒计时秒；其余=0（不刷新）。
  int _hudSecond() {
    if (_timeLimit != null) return _remainingSeconds();
    if (_garbageInterval > 0) {
      return _garbageNextPushAt.difference(DateTime.now()).inSeconds;
    }
    return 0;
  }

  int _remainingSeconds() {
    if (_timeLimit == null) return 0;
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    return max(0, _timeLimit! - elapsed ~/ 1000);
  }

  @override
  void dispose() {
    _gravityTimer?.cancel();
    _cancelLockTimer();
    _tickTimer?.cancel();
    _garbageTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  // ───────── 结束 / 结算 ─────────

  void _finish(bool cleared, {String? reason}) {
    if (_finished) return;
    _finished = true;
    _gravityTimer?.cancel();
    _cancelLockTimer();
    _tickTimer?.cancel();
    _garbageTimer?.cancel();
    _flashTimer?.cancel();
    _flashRows = <int>[];
    if (cleared) {
      GameAudio.instance.win();
      // 每日挑战：通关写本地完成标记（当日模式卡置灰；奖励走 daily_first_clear
      // 的 claim_key 日期幂等，本地标记仅控制展示）
      if (_seedDaily && _dailyDateKey.isNotEmpty) {
        SharedPreferences.getInstance().then((sp) => sp.setString(
            'tetris_daily_done_$_dailyDateKey', '1'));
      }
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      reason: reason,
      values: <String, num>{
        'score': _score,
        'lines': _linesTotal,
        'duration_ms': elapsed,
        'pieces': _piecesPlaced,
        'tetris_count': _tetrisCount,
        'tspin_count': _tspinCount,
        'max_b2b': _maxB2b,
        'max_combo': _maxCombo,
        'perfect_clears': _perfectClears,
        'level_reached': _scoreLevel,
        if (_garbageCleared > 0) 'garbage_cleared': _garbageCleared,
      },
      durationMs: elapsed,
    ));
  }

  /// 重新开始：二次确认后交宿主 _restartGame（aborted 上报 + 引擎重建）。
  Future<void> _confirmRestartViaHost() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃当前游戏？'),
        content: const Text('点击「重新开始」将放弃当前进度，确定要重新开始吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃并重新开始'),
          ),
        ],
      ),
    );
    if (sure == true && mounted) widget.onRestart?.call();
  }

  // ───────── HUD 文案 ─────────

  String get _targetLabel {
    switch (_mode) {
      case TetrisMode.marathon:
      case TetrisMode.sprint:
      case TetrisMode.survival:
      case TetrisMode.daily:
        return '${max(0, _linesTarget - _linesTotal)} 行';
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        return '$_scoreTarget 分';
      case TetrisMode.dig:
        return '$_garbageRowsRemaining 行垃圾';
      case TetrisMode.boss:
        return '血量 $_bossHp';
    }
  }

  /// Frenzy 当前倍率（blitz 专属；×1 不展示；终局最后 10s 归 1 与计分同口径）。
  bool get _frenzyActive =>
      _frenzyEnabled &&
      _combo >= 1 &&
      !(_timeLimit != null && _remainingSeconds() <= 10);

  double get _frenzyMult => 1 + 0.5 * min(_combo, 6);

  @override
  Widget build(BuildContext context) {
    // 布局（2026-10-10 二次优化，对齐消消乐深色容器）：
    // 深色容器铺满 content 全宽 → 内部三列：左=道具竖排轨（数据驱动）、
    // 中=棋盘（居中不受影响）、右=Hold/Next 竖排 + 重开小钮；
    // 底部大圆形操作按钮行不变。无道具时左列隐藏、棋盘进一步加宽。
    return GameShell(
      statusItems: <Widget>[
        GameStatusItem(label: '分数', value: '$_score'),
        GameStatusItem(label: '目标', value: _targetLabel),
        if (_timeLimit != null)
          GameStatusItem(
            label: '剩余时间',
            value: '${_remainingSeconds()}s',
            valueColor: _remainingSeconds() <= 10 ? const Color(0xFFE53935) : null,
          ),
        if (_garbageInterval > 0)
          GameStatusItem(
            label: '顶起倒计时',
            value: '${max(0, _garbageNextPushAt.difference(DateTime.now()).inSeconds)}s',
            valueColor:
                _garbageNextPushAt.difference(DateTime.now()).inSeconds <= 3
                    ? const Color(0xFFE53935)
                    : null,
          ),
        if (_piecesLimit != null)
          GameStatusItem(
            label: '剩余方块',
            value: '${max(0, _piecesLimit! - _piecesPlaced)}',
          ),
        GameStatusItem(label: '消行', value: '$_linesTotal'),
        GameStatusItem(label: '等级', value: '$_scoreLevel'),
        if (_frenzyEnabled && _frenzyActive)
          GameStatusItem(
            label: 'Frenzy',
            value: '×${_frenzyMult.toStringAsFixed(1)}',
            valueColor: const Color(0xFFEF6C00),
          ),
      ],
      propActions: const <GameAction>[],
      propPlaceholder: '',
      actions: const <GameAction>[],
      content: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF101220),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: <Widget>[
                    if (_bossMaxHp > 0) _buildBossBar(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildPropRail(),
                          Expanded(
                            child: Stack(
                              children: <Widget>[
                                _buildGestureBoard(),
                                if (_fxMessages.isNotEmpty) _buildFxOverlay(),
                              ],
                            ),
                          ),
                          _buildRightColumn(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }
}
