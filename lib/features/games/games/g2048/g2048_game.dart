import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/error_reporter.dart';
import '../../../../services/supabase_service.dart';
import '../../game_play_helpers.dart';
import '../../shared/game_audio.dart';
import '../../shared/game_shell.dart';
import '../../models/game_level_model.dart';
import 'g2048_props.dart';
import 'g2048_tile.dart';

// 【文件拆分 2026-09-22】单文件超 500 行红线，按 part + extension 分片（逻辑零变更）：
// g2048_game_engine.dart（网格/合并/死局引擎）、g2048_game_props_actions.dart（道具栏与用道具）、
// g2048_game_board.dart（棋盘渲染与手势）、g2048_game_size_picker.dart（尺寸选择弹窗）。
part 'g2048_game_engine.dart';
part 'g2048_game_props_actions.dart';
part 'g2048_game_board.dart';
part 'g2048_game_size_picker.dart';

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

  /// 本局合成次数（每次两块合并 +1）：结算 values 上报 'merges'，
  /// 供「合成达人」累计型成就计数（GameCumulativeService）。
  int _mergeCount = 0;
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

  /// 最高分持久化 key（按「用户 + 关卡号」区分：避免不同关卡/不同账号共用同一最高分；
  /// 2026-09-14 审查修复——旧键无 userId，切号后新用户看到旧账号最高分。
  /// 未登录传 guest，登录后各自隔离）
  String get _bestKey =>
      'g2048_best_${AuthService.instance.currentUserId ?? 'guest'}_${widget.level.levelNo}';

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
        'merges': _mergeCount,
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
        builder: (ctx, constraints) => _buildBoard(constraints),
      ),
    );
  }
}
