part of 'tetris_game.dart';

// 道具执行域（二期 T2-04，part of _TetrisGameState）：
// 六道具引擎能力（slow/laser/quake/magnet/swap/nuke）+ 道具栏构建 +
// 确认弹窗与两段式延迟扣券（确认仅预检，执行成功回调才 consume——match3 同款）。
// ignore_for_file: invalid_use_of_protected_member
// （part+extension 内调宿主 setState 属 analyzer 已知误报，g2048 同款处理）

extension _TetrisPropsActionsOps on _TetrisGameState {
  /// 时缓卡生效截止时刻（null=未生效）
  bool get _isSlowed =>
      _slowUntil != null && DateTime.now().isBefore(_slowUntil!);

  /// 载入道具目录/库存（initState 调用，失败不影响对局）
  Future<void> _loadProps() async {
    await _props.load(_mode);
    if (mounted) setState(() {});
  }

  // ───────── 道具引擎能力 ─────────

  /// 时缓卡：30 秒内下落间隔 ×2（marathon 局内加速与时缓叠加）。
  bool _execSlow() {
    if (_finished) return false;
    _slowUntil = DateTime.now().add(const Duration(seconds: 30));
    _restartGravityTimer();
    _pushFx('SLOW');
    Timer(const Duration(seconds: 30), () {
      if (!mounted || _finished) return;
      _restartGravityTimer();
      if (mounted) setState(() {});
    });
    return true;
  }

  /// 激光卡：清除底部 3 行（含垃圾行），走正常消行计分（无 spin、计入 lines）。
  bool _execLaser() {
    if (_finished) return false;
    for (var i = 0; i < 3; i++) {
      final row = _board.removeLast();
      if (row.contains(kGarbageColorIndex)) _garbageCleared++;
      _board.insert(0, List<int?>.filled(kTetrisCols, null));
    }
    _boardRev++;
    // 行删除只会腾出空间，current 不会与新盘面碰撞；若原处于锁定延迟，
    // 重力下一 tick 自然接管（悬空则取消锁定计时）
    if (!_isResting) _cancelLockTimer();
    _applyClearScore(3, null);
    _pushFx('LASER!');
    GameAudio.instance.haptic(GameHaptic.heavy);
    // laser 不换当前块：_holdUsed 保持（禁止借道具对同一块重复 Hold）；
    // 挖光垃圾行等通关场景在此收口
    _checkWin();
    if (mounted) setState(() {});
    return true;
  }

  /// 地震卡：各列压实（非空格沉底）填平空洞 + 震落悬空块。
  bool _execQuake() {
    if (_finished) return false;
    for (var c = 0; c < kTetrisCols; c++) {
      int write = kTetrisRows - 1;
      for (var r = kTetrisRows - 1; r >= 0; r--) {
        final v = _board[r][c];
        if (v != null) {
          _board[r][c] = null;
          _board[write][c] = v;
          write--;
        }
      }
    }
    _boardRev++;
    // 压实后 current 可能陷入实体：上移至合法；移出顶部即溢出判负
    final p = _current;
    if (p != null) {
      var guard = 0;
      while (_collides(p, 0, 0) && guard++ <= kTetrisRows) {
        p.y--;
      }
      if (_collides(p, 0, 0)) {
        _onBlockOut();
        return true;
      }
    }
    _pushFx('QUAKE!');
    GameAudio.instance.haptic(GameHaptic.heavy);
    if (mounted) setState(() {});
    return true;
  }

  /// 磁铁卡：全局搜索「消行数最多、其次落点最低」的旋转+列组合，
  /// 直接吸附锁定（复用硬降的锁定路径）。
  bool _execMagnet() {
    final p = _current;
    if (p == null || _finished) return false;
    int bestRot = p.rot, bestX = p.x, bestY = -1;
    var bestClears = -1;
    for (var rot = 0; rot < 4; rot++) {
      for (var x = -2; x < kTetrisCols + 2; x++) {
        // 起点（顶部）合法性：当前 y 处必须不碰撞才可旋转/平移到位
        if (_collidesRotX(p.type, rot, x, p.y)) continue;
        final gy = _ghostYRotX(p.type, rot, x, p.y);
        final clears = _simClears(p.type, rot, x, gy);
        if (clears > bestClears ||
            (clears == bestClears && gy > bestY)) {
          bestClears = clears;
          bestRot = rot;
          bestX = x;
          bestY = gy;
        }
      }
    }
    if (bestY < 0) return false;
    p.rot = bestRot;
    p.x = bestX;
    p.y = bestY;
    _lastAction = _TetrisAction.drop;
    _cancelLockTimer();
    _lockPiece();
    _pushFx('MAGNET!');
    GameAudio.instance.haptic(GameHaptic.medium);
    return true;
  }

  /// 换块卡：当前方块重掷为随机方块（不受 7-bag 约束），位置重置居中。
  bool _execSwapPiece() {
    final p = _current;
    if (p == null || _finished) return false;
    p.type = Tetromino.values[_rng.nextInt(Tetromino.values.length)];
    p.rot = 0;
    p.x = (kTetrisCols - _pieceWidth(p.type)) ~/ 2;
    var guard = 0;
    while (_collides(p, 0, 0) && guard++ <= 2) {
      p.y--;
    }
    if (_collides(p, 0, 0)) {
      _onBlockOut();
      return true;
    }
    _lastAction = _TetrisAction.spawn;
    _pushFx('SWAP!');
    GameAudio.instance.select();
    if (mounted) setState(() {});
    return true;
  }

  /// 清屏卡：整盘清空终局翻盘（不计分、不计 Perfect Clear，防成就刷分）。
  bool _execNuke() {
    if (_finished) return false;
    for (var r = 0; r < kTetrisRows; r++) {
      _board[r] = List<int?>.filled(kTetrisCols, null);
    }
    _boardRev++;
    final p = _current;
    if (p != null && _collides(p, 0, 0)) {
      // 理论不可能（盘已空），防御兜底
      _onBlockOut();
      return true;
    }
    _pushFx('NUKE!');
    GameAudio.instance.haptic(GameHaptic.heavy);
    if (mounted) setState(() {});
    return true;
  }

  // ───────── magnet 辅助（旋转/列枚举的碰撞与消行模拟） ─────────

  bool _collidesRotX(Tetromino t, int rot, int x, int y) {
    for (final c in _kCells[t]![rot]) {
      if (_cellBlocked(y + c.y, x + c.x)) return true;
    }
    return false;
  }

  int _ghostYRotX(Tetromino t, int rot, int x, int y) {
    var gy = y;
    while (!_collidesRotX(t, rot, x, gy + 1)) {
      gy++;
    }
    return gy;
  }

  /// 模拟 (rot,x,gy) 锁定后的满行数（克隆行统计，不写真实盘面）。
  int _simClears(Tetromino t, int rot, int x, int gy) {
    final grid = List<List<int?>>.generate(kTetrisRows,
        (r) => List<int?>.from(_board[r]));
    for (final c in _kCells[t]![rot]) {
      final r = gy + c.y;
      final col = x + c.x;
      if (r >= 0 && r < kTetrisRows && col >= 0 && col < kTetrisCols) {
        grid[r][col] = t.index;
      }
    }
    return grid.where((row) => row.every((v) => v != null)).length;
  }

  // ───────── 道具栏 ─────────

  /// 道具名映射（后台 name 缺失时的兜底）。
  static const Map<String, String> _propLabels = <String, String>{
    'slow': '时缓卡',
    'laser': '激光卡',
    'quake': '地震卡',
    'magnet': '磁铁卡',
    'swap': '换块卡',
    'nuke': '清屏卡',
  };

  /// 道具效果描述（确认弹窗用）。
  static const Map<String, String> _propEffects = <String, String>{
    'slow': '30 秒内下落速度减半',
    'laser': '清除底部 3 行',
    'quake': '震落实块并填平空洞',
    'magnet': '自动吸附到最优落点',
    'swap': '当前方块随机重掷',
    'nuke': '清空整块棋盘',
  };

  IconData _propIcon(String itemType) {
    switch (itemType) {
      case 'slow':
        return Icons.slow_motion_video;
      case 'laser':
        return Icons.flash_on;
      case 'quake':
        return Icons.vibration;
      case 'magnet':
        return Icons.attractions;
      case 'swap':
        return Icons.casino_outlined;
      case 'nuke':
        return Icons.local_fire_department;
    }
    return Icons.extension_outlined;
  }

  /// 左列道具竖排轨（2026-10-10 布局：深色容器内左侧从上到下）。
  /// 无可用道具时返回窄空条（保持深色容器左缘节奏，不挤压棋盘）。
  Widget _buildPropRail() {
    final available = _props.slots.where((s) => s.available).toList();
    return SizedBox(
      width: 60,
      child: available.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
              child: Column(
                children: <Widget>[
                  for (final s in available)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPropRailButton(s),
                    ),
                ],
              ),
            ),
    );
  }

  /// 道具轨按钮：深色圆钮 + 右上角库存角标，点击走确认→执行→扣券。
  /// 图标优先渲染 game_items.icon 定版 SVG（assets/games/items/），
  /// 空/缺失回落内置 Material 图标（itemIconFor 同款兜底语义）。
  Widget _buildPropRailButton(TetrisPropSlot s) {
    final label = (s.item?.name.isNotEmpty ?? false)
        ? s.item!.name
        : (_propLabels[s.itemType] ?? s.itemType);
    final hasAsset = (s.item?.icon?.isNotEmpty ?? false);
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _useProp(s),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E2230),
                  border: Border.all(color: const Color(0xFF2E3245)),
                ),
                padding: const EdgeInsets.all(8),
                child: hasAsset
                    ? SvgPicture.asset(
                        'assets/games/items/${s.item!.icon}.svg',
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) => Icon(_propIcon(s.itemType),
                            size: 24, color: const Color(0xFFFFB74D)),
                      )
                    : Icon(_propIcon(s.itemType),
                        size: 24, color: const Color(0xFFFFB74D)),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF6C00),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${s.total}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 使用道具：确认弹窗 → 引擎执行 → 成功才扣券（两段式延迟扣券）。
  Future<void> _useProp(TetrisPropSlot s) async {
    if (_finished || !s.available) return;
    // 消行闪烁动画中禁止使用（laser/quake 与动画后的删行会并发冲突）
    if (_flashTimer != null || _flashRows.isNotEmpty) return;
    final label = (s.item?.name.isNotEmpty ?? false)
        ? s.item!.name
        : (_propLabels[s.itemType] ?? s.itemType);
    final sure = await confirmTetrisPropDialog(
      context,
      label: label,
      effectText: _propEffects[s.itemType] ?? '',
      free: s.free,
      owned: s.owned,
      icon: _propIcon(s.itemType),
      iconAsset: (s.item?.icon?.isNotEmpty ?? false) ? s.item!.icon : null,
    );
    if (sure != true || !mounted || _finished) return;
    final ok = switch (s.itemType) {
      'slow' => _execSlow(),
      'laser' => _execLaser(),
      'quake' => _execQuake(),
      'magnet' => _execMagnet(),
      'swap' => _execSwapPiece(),
      'nuke' => _execNuke(),
      _ => false,
    };
    if (!ok) return; // 执行失败不扣券（防「确认后未执行券已扣」）
    await _props.consume(s);
    if (mounted) setState(() {});
  }
}
