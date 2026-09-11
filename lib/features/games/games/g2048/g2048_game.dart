import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/error_reporter.dart';
import '../../../../services/supabase_config.dart';
import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_shell.dart';
import '../../models/game_level_model.dart';
import 'g2048_props.dart';
import 'g2048_tile.dart';

/// 2048（成熟手感版）
///
/// 操作方式：**在棋盘上朝上/下/左/右拖动（滑动）**，同方向所有数字整体推移，
/// 相邻且数字相同的两块合并成一块（2+2=4）。本游戏**没有点击操作**。
///
/// - 滑动判定用「拖动总位移」而非抬手瞬时速度，慢速拖动同样生效（v2 修复）。
/// - 方块用 [G2048Tile] 做丝滑滑动 + 出现/合并弹跳。
/// - 触感 + 音效：每次移动轻触感 + 点击音；合并中触感 + 合并音。
/// - 最高分本地持久化（shared_preferences）。
/// - 到达 2048 记「通关」；无可移动空间记「失败」。成绩维度：score + duration_ms。
class G2048Game extends StatefulWidget {
  /// 结束回调
  final void Function(GamePlayOutcome) onFinished;

  /// 当前关卡（含 size / target 配置）
  final GameLevelModel level;

  /// 宿主重开回调（2026-09-10 审查补接线：走 GamePlayScreen._restartGame，
  /// aborted 上报 + 引擎重建，与消消乐同口径；null 时重开按钮禁用）
  final VoidCallback? onRestart;

  G2048Game({
    super.key,
    required this.onFinished,
    required this.level,
    this.onRestart,
  });

  @override
  State<G2048Game> createState() => _G2048GameState();
}

class _G2048GameState extends State<G2048Game> {
  late int _size;
  late int _target;
  /// 无通关条件（经典「棋盘选择」无尽模式）：达到目标方块也不结束，
  /// 仅当棋盘无法再移动时判负结束。由 config['noClear'] 驱动。
  late bool _noClear;
  static const Duration _slide = Duration(milliseconds: 120);

  /// 判定为「一次滑动」的最小拖动距离（逻辑像素）。
  /// 取 24：既能过滤误触抖动，又让短距离轻扫可用。
  static const double _swipeThreshold = 24.0;

  /// 本次拖动的累计位移（onPanStart 归零，onPanUpdate 累加，onPanEnd 判方向）
  Offset _dragDelta = Offset.zero;

  /// 本次拖动是否已经触发过移动（防止一次长拖连续触发多次）
  bool _dragConsumed = false;

  /// 动画期间缓存的待执行方向：若滑动发生在下落动画进行中，
  /// 先缓存、动画结束后再执行，避免「多次交互后无响应」的输入丢失。
  String? _pendingDir;

  final List<TileModel> _tiles = <TileModel>[];
  late List<List<TileModel?>> _grid;
  int _score = 0;
  int _best = 0;
  bool _animating = false;
  bool _finished = false;
  bool _pendingWin = false;
  int _movesUsed = 0;
  int? _movesLimit;
  int? _timeLimit;
  int? _scoreTarget;
  bool _reachedTarget = false;

  /// 目标语义：true = config.target 是分数门槛（限时/挑战）；false = 方块数值（经典）
  bool _isScoreGoal = false;

  /// 道具域（2026-09-10）：加时卡（限时）/ 加步卡（挑战），数据驱动
  final G2048Props _props = G2048Props();

  /// 加时卡累计加时（秒）：新开局归零，叠加到限时上限
  int _bonusSeconds = 0;

  /// 加步卡累计加步：新开局归零，叠加到步数上限
  int _movesBonus = 0;

  /// 本局有效步数上限（配置值 + 道具加步）
  int? get _effectiveMovesLimit =>
      _movesLimit == null ? null : _movesLimit! + _movesBonus;

  Timer? _tickTimer;
  int _nextId = 1;

  /// 本局起始时刻（**非 final**：重开必须重置——否则限时关重开时 elapsed
  /// 已超限立即判负、duration_ms 含上一局时长，2026-09-10 审查修复）
  DateTime _startTime = DateTime.now();
  final Random _rng = Random();

  /// 最高分持久化 key（按关卡号区分，避免不同关卡共用同一最高分）
  String get _bestKey => 'g2048_best_${widget.level.levelNo}';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // 从后台关卡配置读取棋盘尺寸与目标分（含安全边界，异常值回退默认）
    final cfgSize = widget.level.config['size'];
    final cfgTarget = widget.level.config['target'];
    final parsedSize = cfgSize is int
        ? cfgSize
        : (cfgSize is num ? cfgSize.toInt() : 4);
    _size = (parsedSize >= 3 && parsedSize <= 8) ? parsedSize : 4;
    final parsedTarget = cfgTarget is int
        ? cfgTarget
        : (cfgTarget is num ? cfgTarget.toInt() : 2048);
    _target = parsedTarget > 0 ? parsedTarget : 2048;
    // 无通关条件：config['noClear'] == true 时永不通关（仅棋盘卡死结束）
    final cfgNoClear = widget.level.config['noClear'];
    _noClear = cfgNoClear == true;
    // 扩展维度（无则该维不限制）：步数上限 / 时间上限(秒) / 分数达标。
    // 键名双兼容：DB 实配键为 snake_case（max_moves/time_limit），引擎历史键为
    // camelCase（moves/timeLimit）——两套都认（match3 同款别名惯例）。
    final cfgMoves =
        widget.level.config['moves'] ?? widget.level.config['max_moves'];
    _movesLimit = cfgMoves is int
        ? cfgMoves
        : (cfgMoves is num ? cfgMoves.toInt() : null);
    final cfgTime =
        widget.level.config['timeLimit'] ?? widget.level.config['time_limit'];
    _timeLimit =
        cfgTime is int ? cfgTime : (cfgTime is num ? cfgTime.toInt() : null);
    final cfgScore = widget.level.config['scoreTarget'];
    _scoreTarget = cfgScore is int ? cfgScore : null;
    // 目标语义判定：带步数/时间限制的关卡（挑战/限时）config.target 是
    // **分数门槛**（如 690），并非方块数值——方块只可能是 2 的幂。
    // （2026-09-07 二次修复：此前用 containsKey('moves'/'timeLimit') 判定，
    // 而 DB 实配键为 max_moves/time_limit，判定落空 → 挑战/限时永远按方块
    // 判定、永远无法通关；现以别名解析结果为准）
    _isScoreGoal = _movesLimit != null || _timeLimit != null;
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    _loadBest();
    _reset();
    // 道具目录/库存异步加载（失败不影响对局，错误上报后台可观测）
    _loadProps();
  }

  /// 加载道具：按本局模式过滤（限时→加时卡、挑战→加步卡）。
  Future<void> _loadProps() async {
    // 模式解析诊断（2026-09-11 排查「道具栏全模式为空」）：time_limit/
    // max_moves 任一解析成功才会构建对应道具按钮——若日志中 keys 缺键，
    // 说明上游给的 level.config 非真实关卡配置（如 defaultLevel 兜底）
    SecureLogger.log(
      '[G2048][props] modeId=${widget.level.modeId} levelNo=${widget.level.levelNo} '
      'configKeys=${widget.level.config.keys.toList()} '
      'timeLimit=$_timeLimit movesLimit=$_movesLimit',
    );
    await _props.load(
      hasTimeLimit: _timeLimit != null,
      hasMovesLimit: _movesLimit != null,
      modeCode: _timeLimit != null
          ? 'timed'
          : (_movesLimit != null ? 'challenge' : ''),
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    if (mounted) {
      _best = sp.getInt(_bestKey) ?? 0;
      setState(() {});
    }
  }

  void _persistBest() {
    // 用与读取一致的 _bestKey（按关卡号区分），旧版写死 'g2048_best' 导致最高分存错 key
    SharedPreferences.getInstance().then((sp) => sp.setInt(_bestKey, _best));
  }

  void _reset() {
    _tiles.clear();
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    _score = 0;
    _animating = false;
    _finished = false;
    _pendingWin = false;
    _pendingDir = null;
    _movesUsed = 0;
    _reachedTarget = false;
    _bonusSeconds = 0; // 道具加时不跨局保留
    _movesBonus = 0; // 道具加步不跨局保留
    _startTime = DateTime.now(); // 计时基准随新局重置（限时判定/duration 口径）
    _startTimer();
    _spawn();
    _spawn();
  }

  /// 启动限时倒计时（仅当本关配置 timeLimit 时）；每 250ms 检查超时并刷新显示。
  void _startTimer() {
    _tickTimer?.cancel();
    if (_timeLimit == null) return;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), _onTick);
  }

  void _onTick(Timer timer) {
    if (_finished) {
      timer.cancel();
      return;
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    if (elapsed >= (_timeLimit! + _bonusSeconds) * 1000) {
      // 归零时若分数目标已达成则判胜（最后一滑恰好达标、轮询先到的情况）
      _finish(_isScoreGoal && _score >= _target);
      return;
    }
    if (mounted) setState(() {});
  }

  /// 限时模式剩余秒数（用于状态栏展示，含加时卡加时）。
  int _remainingSeconds() {
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    return max(0, _timeLimit! + _bonusSeconds - elapsed ~/ 1000);
  }

  /// 道具按钮构建（与消消乐同口径）：目录已载入即渲染（0 库存禁用态），
  /// 有额度才可点击。
  GameAction _buildPropAction(
    String itemType, {
    required IconData icon,
    required String label,
  }) {
    final s = _props.slot(itemType);
    return GameAction(
      icon: icon,
      iconAsset: (s?.item?.icon != null && s!.item!.icon!.isNotEmpty)
          ? s.item!.icon
          : null,
      label: label,
      badge: '${s?.total ?? 0}',
      extraTag: (s?.free ?? 0) > 0 ? '免${s!.free}' : null,
      onPressed: (s?.available ?? false) ? () => _confirmProp(itemType) : null,
    );
  }

  /// 使用道具前的确认弹窗（即时型：确认即执行并扣券）。
  Future<void> _confirmProp(String itemType) async {
    final s = _props.slot(itemType);
    if (s == null || !s.available || _finished) return;
    final isTime = itemType == 'add_time';
    final sure = await confirmG2048PropDialog(
      context,
      label: isTime ? '加时卡' : '加步卡',
      effectText: isTime ? '本局剩余时间 +15 秒' : '剩余步数 +5',
      free: s.free,
      owned: s.owned,
      icon: isTime ? Icons.timer_outlined : Icons.exposure_plus_1,
      iconAsset: s.item?.icon,
    );
    if (sure == true) await _useProp(itemType);
  }

  /// 使用道具：先免费用完再消耗库存，成功后应用效果。
  Future<void> _useProp(String itemType) async {
    final s = _props.slot(itemType);
    if (s == null || !s.available || _finished) return;
    final ok = await _props.consume(s);
    if (!ok) {
      if (mounted) setState(() {});
      return;
    }
    if (itemType == 'add_time') {
      _bonusSeconds += 15; // 与消消乐加时卡同口径
    } else {
      _movesBonus += 5; // 与消消乐加步卡同口径
    }
    GameAudio.instance.prop();
    if (mounted) setState(() {});
  }

  void _rebuildGrid() {
    _grid = List.generate(_size, (_) => List.filled(_size, null));
    for (final t in _tiles) {
      if (!t.toRemove) _grid[t.row][t.col] = t;
    }
  }

  void _spawn() {
    final empties = <(int, int)>[];
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        if (_grid[r][c] == null) empties.add((r, c));
      }
    }
    if (empties.isEmpty) return;
    final cell = empties[_rng.nextInt(empties.length)];
    final t = TileModel(
      _nextId++,
      _rng.nextInt(10) == 0 ? 4 : 2,
      cell.$1,
      cell.$2,
      isNew: true,
    );
    _tiles.add(t);
    _grid[cell.$1][cell.$2] = t;
  }

  List<List<(int, int)>> _linesFor(String dir) {
    final lines = <List<(int, int)>>[];
    if (dir == 'left' || dir == 'right') {
      for (var r = 0; r < _size; r++) {
        final cells = <(int, int)>[];
        for (var c = 0; c < _size; c++) {
          final cc = dir == 'left' ? c : _size - 1 - c;
          cells.add((r, cc));
        }
        lines.add(cells);
      }
    } else {
      for (var c = 0; c < _size; c++) {
        final cells = <(int, int)>[];
        for (var r = 0; r < _size; r++) {
          final rr = dir == 'up' ? r : _size - 1 - r;
          cells.add((rr, c));
        }
        lines.add(cells);
      }
    }
    return lines;
  }

  void _move(String dir) {
    if (_animating) {
      debugPrint('[G2048] _move 忽略：动画进行中 dir=$dir');
      return;
    }
    if (_finished) {
      debugPrint('[G2048] _move 忽略：本局已结束 dir=$dir');
      return;
    }
    debugPrint('[G2048] _move 开始 dir=$dir（size=$_size target=$_target）');
    // 关键：重置合并标记。merged 只在本回合合并判定中生效，若不重置，
    // 参与过合并的方块将永久失去合并资格 → 盘面「看似可并实则不可并」，
    // 各方向 changed=false 直接 return，表现为滑动几次后卡死无响应。
    for (final t in _tiles) {
      t.merged = false;
    }
    final lines = _linesFor(dir);
    var changed = false;
    var gain = 0;

    for (final cells in lines) {
      final lineTiles = <TileModel>[];
      for (final cell in cells) {
        final t = _grid[cell.$1][cell.$2];
        if (t != null) lineTiles.add(t);
      }
      final entries = <List<TileModel>>[];
      var i = 0;
      while (i < lineTiles.length) {
        if (i + 1 < lineTiles.length &&
            lineTiles[i].value == lineTiles[i + 1].value &&
            !lineTiles[i].merged) {
          lineTiles[i].value *= 2;
          lineTiles[i].merged = true;
          gain += lineTiles[i].value;
          if (lineTiles[i].value >= _target) {
            _reachedTarget = true;
          }
          entries.add([lineTiles[i], lineTiles[i + 1]]);
          i += 2;
        } else {
          entries.add([lineTiles[i]]);
          i += 1;
        }
      }
      for (var idx = 0; idx < entries.length; idx++) {
        final cell = cells[idx];
        final e = entries[idx];
        if (e.length == 2) {
          e[0].row = cell.$1;
          e[0].col = cell.$2;
          e[1].row = cell.$1;
          e[1].col = cell.$2;
          e[1].toRemove = true;
          changed = true;
        } else {
          if (e[0].row != cell.$1 || e[0].col != cell.$2) changed = true;
          e[0].row = cell.$1;
          e[0].col = cell.$2;
        }
      }
    }

    if (!changed) {
      // 无变化：不推进步数、不调度动画回调（此前 debugPrint 误放在 return
      // 之后，有变化时反而打印「无变化」，日志与实际路径相反、误导排查）
      return;
    }
    _movesUsed++;
    debugPrint('[G2048] _move 已移动 dir=$dir gain=$gain');

    if (gain > 0) {
      GameAudio.instance.merge();
      GameAudio.instance.haptic(GameHaptic.medium);
    } else {
      GameAudio.instance.tap();
      GameAudio.instance.haptic(GameHaptic.light);
    }
    _score += gain;
    if (_score > _best) {
      _best = _score;
      _persistBest();
    }
    _rebuildGrid();
    _animating = true;
    // 通关判定（双语义）：
    // - 分数目标模式（限时/挑战）：累计分达到 config.target 即通关；
    // - 方块目标模式（经典）：合成到目标方块 且 (未设分数门槛 或 累计分已达标)。
    final scoreTarget = _scoreTarget;
    _pendingWin = _isScoreGoal
        ? (_score >= _target)
        : (_reachedTarget && (scoreTarget == null || _score >= scoreTarget));
    // 无尽模式：无论是否达成目标都不通关，仅棋盘卡死时结束
    if (_noClear) _pendingWin = false;
    setState(() {});

    Future.delayed(_slide + const Duration(milliseconds: 20), () {
      if (!mounted) return;
      final movesLimit = _effectiveMovesLimit;
      try {
        _tiles.removeWhere((t) => t.toRemove);
        _rebuildGrid();
        var lost = false;
        if (!_pendingWin) {
          _spawn();
          _rebuildGrid();
          if (!_hasMoves()) lost = true;
        }
        // 步数耗尽且未通关 → 失败（优先于棋盘卡死判定）
        if (!_pendingWin && movesLimit != null && _movesUsed >= movesLimit) {
          _finish(false);
        } else if (_pendingWin) {
          _finish(true);
        } else if (lost) {
          _finish(false);
        } else {
          // 动画期间缓存的滑动：立即补执行，保证输入不丢、不卡死。
          final buffered = _pendingDir;
          _pendingDir = null;
          if (buffered != null && !_finished) {
            _requestMove(buffered);
          } else {
            setState(() {});
          }
        }
      } catch (e, st) {
        // 兜底：任何异常都强制释放 _animating，避免棋盘永久冻结（滑动无响应）。
        debugPrint('[G2048] 动画回调异常，强制释放 _animating：$e');
        debugPrint('[G2048] $st');
        // 错误上报（2026-09-11）：此类异常会被静默吞掉、只表现为卡死，须后台可见
        ErrorReporter.report(e, st, module: 'games');
      } finally {
        _animating = false;
        if (mounted) setState(() {});
      }
    });
  }

  bool _hasMoves() {
    for (var r = 0; r < _size; r++) {
      for (var c = 0; c < _size; c++) {
        // 空格存在即可动；邻居比较必须空安全——相邻格为空时 `!` 会崩
        // （Null check operator on null value），且异常被回调 catch 吞掉后
        // 连带跳过 lost 判定/结算/缓冲补执行
        final v = _grid[r][c]?.value;
        if (v == null) return true;
        if (c + 1 < _size && _grid[r][c + 1]?.value == v) {
          return true;
        }
        if (r + 1 < _size && _grid[r + 1][c]?.value == v) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _finish(bool cleared) {
    if (_finished) return;
    _finished = true;
    _tickTimer?.cancel();
    if (cleared) {
      GameAudio.instance.win();
    } else {
      GameAudio.instance.fail();
    }
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
    widget.onFinished(GamePlayOutcome(
      cleared: cleared,
      values: <String, num>{
        'score': _score,
        'duration_ms': elapsed,
        'moves': _movesUsed,
      },
      durationMs: elapsed,
    ));
  }

  /// 重新开始按钮：进行中需二次确认，避免误触丢失当前进度。
  /// 确认后交宿主 [_restartGame]（aborted 上报 + nonce 重建引擎），与消消乐同口径。
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

  /// 按累计位移判定滑动方向。
  /// 原实现只看抬手瞬时速度（velocity），慢速拖动抬手时速度≈0 → 永远不触发，
  /// 表现为「点击不行、滑动也不行」。改为总位移判定后任意速度均可操作。
  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragConsumed) return;
    _dragDelta += d.delta;
    // 拖动过程中一旦越过阈值立即响应，手感更即时（不必等抬手）
    if (_dragDelta.distance >= _swipeThreshold) {
      _dragConsumed = true;
      debugPrint('[G2048] 越过阈值触发滑动 delta=$_dragDelta');
      _applySwipe(_dragDelta);
    }
  }

  /// 请求一次滑动移动：动画进行中则缓存方向，结束后补执行（输入不丢）。
  void _requestMove(String dir) {
    if (_finished) {
      debugPrint('[G2048] _requestMove 忽略：已结束 dir=$dir');
      return;
    }
    if (_animating) {
      _pendingDir = dir;
      debugPrint('[G2048] _requestMove 动画中→缓存 dir=$dir');
      return;
    }
    _move(dir);
  }

  void _applySwipe(Offset delta) {
    final dir = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx > 0 ? 'right' : 'left')
        : (delta.dy > 0 ? 'down' : 'up');
    debugPrint('[G2048] 判定方向=$dir');
    _requestMove(dir);
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      statusItems: <Widget>[
        GameStatusItem(label: '得分', value: '$_score'),
        if (_noClear)
          const GameStatusItem(label: '模式', value: '无尽')
        else if (_isScoreGoal)
          // 分数门槛（挑战/限时）：明确标注单位，避免与「合成方块」混淆
          GameStatusItem(label: '目标', value: '$_target 分')
        else
          // 经典模式：目标为合成方块数值
          GameStatusItem(label: '合成', value: '$_target'),
        if (_movesLimit != null)
          GameStatusItem(
            label: '剩余步数',
            value: '${max(0, _effectiveMovesLimit! - _movesUsed)}',
          ),
        if (_timeLimit != null)
          GameStatusItem(
            label: '剩余时间',
            value: '${_remainingSeconds()}s',
          ),
      ],
      hint: '在棋盘上朝上下左右拖动，相同数字相撞即合并（无需点击）',
      // 道具栏（2026-09-10）：限时模式加时卡 / 挑战模式加步卡，数据驱动。
      // 渲染条件与消消乐同口径：目录已载入即展示（0 库存为禁用态，引导购买），
      // 经典/无尽无时间/步数概念 → 道具栏为空 → 空白占位行（无文案，2026-09-11）
      propPlaceholder: '',
      propActions: <GameAction>[
        if (_timeLimit != null)
          _buildPropAction(
            'add_time',
            icon: Icons.timer_outlined,
            label: '加时卡',
          ),
        if (_movesLimit != null)
          _buildPropAction(
            'add_steps',
            icon: Icons.exposure_plus_1,
            label: '加步卡',
          ),
      ],
      actions: <GameAction>[
        GameAction(
          icon: Icons.refresh,
          // 三游戏统一文案（2026-09-10）：原「新游戏」与消消乐「重新开始」不一致
          label: '重新开始',
          primary: true,
          // 重开统一走宿主 _restartGame（aborted 上报 + 引擎重建），与消消乐同口径；
          // 未接宿主时禁用（GameFlow 体系恒传入，防御性兜底）
          onPressed: widget.onRestart == null ? null : _confirmRestartViaHost,
        ),
      ],
      content: LayoutBuilder(
        builder: (ctx, constraints) {
          // 棋盘取正方形，居中显示，避免长屏被拉伸
          final board = min(constraints.maxWidth, constraints.maxHeight);
          final gap = board * 0.03;
          final cell = (board - gap * (_size + 1)) / _size;
          double pos(int index) => gap + index * (cell + gap);

          final children = <Widget>[
            // 棋盘底格
            for (var r = 0; r < _size; r++)
              for (var c = 0; c < _size; c++)
                Positioned(
                  left: pos(c),
                  top: pos(r),
                  width: cell,
                  height: cell,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDC1B4),
                      borderRadius: BorderRadius.circular(cell * 0.14),
                    ),
                  ),
                ),
            // 方块
            for (final t in _tiles)
              G2048Tile(
                key: ValueKey<int>(t.id),
                value: t.value,
                size: cell,
                left: pos(t.col),
                top: pos(t.row),
                isNew: t.isNew,
                merged: t.merged,
                slide: _slide,
              ),
          ];

          return Center(
            child: GestureDetector(
              // opaque：棋盘空白处同样接收拖动，避免只有方块上能滑
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                debugPrint('[G2048] panStart');
                _dragDelta = Offset.zero;
                _dragConsumed = false;
              },
              onPanUpdate: _onDragUpdate,
              onPanEnd: (_) {
                // 兜底：整段拖动都很短但已越过阈值时在抬手时判定
                if (!_dragConsumed && _dragDelta.distance >= _swipeThreshold) {
                  _applySwipe(_dragDelta);
                }
                debugPrint('[G2048] panEnd consumed=$_dragConsumed');
                _dragDelta = Offset.zero;
                _dragConsumed = false;
              },
              // 手势被系统/手势竞技场取消时复位，避免 _dragConsumed 卡死导致后续无响应。
              onPanCancel: () {
                debugPrint('[G2048] panCancel');
                _dragDelta = Offset.zero;
                _dragConsumed = false;
              },
              child: Container(
                width: board,
                height: board,
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0),
                  borderRadius: BorderRadius.circular(gap * 2),
                ),
                child: Stack(children: children),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 2048 经典模式「棋盘选择」底部弹窗：尺寸 3×3 .. 8×8。
/// 返回选定尺寸；用户点「返回」取消时返回 null。
Future<int?> showG2048SizePicker(BuildContext context) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('选择棋盘尺寸', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '经典模式 · 无通关条件 · 玩到无法移动为止',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (var s = 3; s <= 8; s++)
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(s),
                  child: Text('${s}×${s}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('返回'),
            ),
          ),
        ],
      ),
    ),
  );
}
