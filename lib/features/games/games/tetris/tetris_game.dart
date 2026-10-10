import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../game_play_helpers.dart';
import '../../models/game_level_model.dart';
import '../../services/game_service.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_shell.dart';
import 'tetris_mode.dart';

// 【文件拆分】单文件 ≤500 行红线：本文件为宿主 State（配置/HUD/流程），
// 引擎逻辑见 tetris_engine.dart（part）、渲染见 tetris_board.dart（part）、
// 手势与按钮行见 tetris_input.dart（part）。
part 'tetris_engine.dart';
part 'tetris_board.dart';
part 'tetris_input.dart';

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
  final List<Tetromino> _queue = <Tetromino>[];
  Piece? _current;
  Tetromino? _held;
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
  final Random _rng = Random();

  // 计时器组
  Timer? _gravityTimer;
  Timer? _lockTimer;
  Timer? _tickTimer; // blitz 倒计时轮询
  int _lockResets = 0;
  int _lastTickSecond = -1;

  /// 消行大字特效（board 上层浮现）
  final List<_TetrisFx> _fxMessages = <_TetrisFx>[];

  /// 棋盘内容版本号：board 原地写改（锁定/消行/重置）时递增，
  /// 供 painter shouldRepaint 精确判重（不依赖 current 间接覆盖——
  /// 二期 garbage 顶起只改 board 不动 current，无此旗标会漏重绘）。
  int _boardRev = 0;

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
    // 下落间隔按模式兜底（sprint 800 恒速 / blitz·challenge 900 / marathon 1000）
    final fallbackFall = switch (_mode) {
      TetrisMode.marathon => 1000,
      TetrisMode.sprint => 800,
      TetrisMode.blitz => 900,
      TetrisMode.challenge => 900,
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
  }

  int _intOf(dynamic v, int fallback) =>
      v is int ? v : (v is num ? v.toInt() : fallback);

  void _reset() {
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
    _startTime = DateTime.now();
    _restartGravityTimer();
    _startTickTimer();
    _spawnPiece();
  }

  // ───────── 计时器管理 ─────────

  void _restartGravityTimer() {
    _gravityTimer?.cancel();
    _gravityTimer = Timer.periodic(Duration(milliseconds: _currentFallMs), (_) {
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

  /// blitz 倒计时轮询（250ms 轮询、整秒变化才重建，g2048 同款节流）
  void _startTickTimer() {
    _tickTimer?.cancel();
    if (_timeLimit == null) return;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_finished) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds() <= 0) {
        _finish(_scoreTarget > 0 && _score >= _scoreTarget,
            reason: '时间到');
        return;
      }
      final s = _remainingSeconds();
      if (s != _lastTickSecond) {
        _lastTickSecond = s;
        if (mounted) setState(() {});
      }
    });
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
    super.dispose();
  }

  // ───────── 结束 / 结算 ─────────

  void _finish(bool cleared, {String? reason}) {
    if (_finished) return;
    _finished = true;
    _gravityTimer?.cancel();
    _cancelLockTimer();
    _tickTimer?.cancel();
    if (cleared) {
      GameAudio.instance.win();
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
        return '${max(0, _linesTarget - _linesTotal)} 行';
      case TetrisMode.blitz:
      case TetrisMode.challenge:
        return '$_scoreTarget 分';
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
      hint: '左右滑移动 · 点按旋转 · 下滑软降 · 快速下滑硬降',
      propPlaceholder: '',
      actions: <GameAction>[
        GameAction(
          icon: Icons.refresh,
          label: '重新开始',
          primary: true,
          onPressed: widget.onRestart == null ? null : _confirmRestartViaHost,
        ),
      ],
      content: Column(
        children: <Widget>[
          _buildNextHoldBar(),
          Expanded(
            child: Stack(
              children: <Widget>[
                _buildGestureBoard(),
                if (_fxMessages.isNotEmpty) _buildFxOverlay(),
              ],
            ),
          ),
          if (_buttonsEnabled) ..._buildControlButtons(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
