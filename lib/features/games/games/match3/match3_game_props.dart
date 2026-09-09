part of match3_game;

/// 消消乐宿主页道具域（part of match3_game，共享 State 私有成员）。
///
/// 目录/库存加载、死局处理器（洗牌/商城引导）、即时型与两段式道具的
/// 确认消耗流程、道具栏按钮构建（选中高亮）。
extension _Match3GameProps on _Match3GameState {
  // ---------- 道具商城（六道具，数据驱动：enabled + propUnlock） ----------

  /// 加载通用道具目录与库存（渲染条件见 Match3Props.load）。
  Future<void> _loadMatchProps() async {
    await _props.load(
      gameCode: widget.game.code,
      levelNo: widget.level?.levelNo ?? 0,
      propUnlock: (widget.level?.config ?? const <String, dynamic>{})['propUnlock'],
    );
    if (mounted) setState(() {});
  }

  /// 死局处理器（引擎 stalemateHandler 回调）：
  ///
  /// 有洗牌券 → 「使用洗牌（独立确认消耗）/ 道具商城 / 放弃对局」；
  /// 无券 → 「去商城购买 / 放弃对局」。选择商城则跳转购买，**返回后对局
  /// 状态保持**（引擎位于下层路由未被销毁），刷新库存后重新进入询问——
  /// 购买不自动使用，需再次确认消耗。返回 true = 已处理，false = 判负。
  Future<bool> _handleStalemate() async {
    final shuffle = _props.slot('shuffle')!;
    while (true) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('无可消组合'),
            content: Text(shuffle.available
                ? '盘面已无可消交换。使用洗牌卡重排盘面（特殊糖保留原位），或前往道具商城补货。'
                : '盘面已无可消交换，且没有洗牌卡。可前往道具商城购买，或放弃本局。'),
            actions: <Widget>[
              if (shuffle.available)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'use'),
                  child: Text(shuffle.free > 0
                      ? '使用洗牌（免费剩 ${shuffle.free} 次）'
                      : '使用洗牌（库存剩 ${shuffle.owned} 张）'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'shop'),
                child: const Text('道具商城'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'quit'),
                child: const Text('放弃对局'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'use') {
        // 独立确认消耗流程：弹窗确认后才扣券执行
        if (await _confirmUseProp(
          '使用洗牌卡？',
          shuffle.free > 0
              ? '确定要使用 1 次免费洗牌（剩余 ${shuffle.free} 次）吗？盘面将重排，特殊糖保留原位。'
              : '确定要消耗 1 张洗牌卡（库存剩余 ${shuffle.owned} 张）吗？盘面将重排，特殊糖保留原位。',
        )) {
          final ok = await _props.consume(shuffle);
          if (ok) {
            if (_game.doShuffle()) {
              if (mounted) setState(() {});
              return true;
            }
            // 洗牌执行失败（200 次重排仍无解，概率极低）：判负兜底防卡死
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('洗牌失败，本局结束')),
              );
            }
          }
        }
        continue; // 消耗失败/取消 → 回到询问
      }
      if (choice == 'shop') {
        // 跳转商城购买：push 保留下层路由，Flame 引擎与对局状态原样保留；
        // 返回后刷新库存，回到询问（购买后需单独确认消耗，不自动使用）
        if (!mounted) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameItemShopScreen(game: widget.game),
          ),
        );
        await _loadMatchProps();
        continue;
      }
      return false; // 放弃对局 / 未登录等异常
    }
  }

  /// 道具消耗前通用确认弹窗。返回 true = 确认使用。
  Future<bool> _confirmUseProp(String title, String body) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定使用'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  /// 即时型道具（确认 → 扣券 → 引擎能力）：shuffle/hint/add_steps。
  Future<void> _useImmediateProp(String itemType) async {
    final s = _props.slot(itemType)!;
    if (!s.available) return;
    final titles = <String, String>{
      'shuffle': '使用洗牌卡？',
      'hint': '使用提示卡？',
      'add_steps': '使用加步卡？',
    };
    final bodies = <String, String>{
      'shuffle': s.free > 0
          ? '确定要使用 1 次免费洗牌（剩余 ${s.free} 次）吗？盘面将重排，特殊糖保留原位。'
          : '确定要消耗 1 张洗牌卡（库存剩余 ${s.owned} 张）吗？盘面将重排，特殊糖保留原位。',
      'hint': s.free > 0
          ? '确定要使用 1 次免费提示（剩余 ${s.free} 次）吗？将高亮一组可消交换的糖果。'
          : '确定要消耗 1 张提示卡（库存剩余 ${s.owned} 张）吗？将高亮一组可消交换的糖果。',
      'add_steps': s.free > 0
          ? '确定要使用 1 次免费加步（剩余 ${s.free} 次）吗？剩余步数 +5。'
          : '确定要消耗 1 张加步卡（库存剩余 ${s.owned} 张）吗？剩余步数 +5。',
    };
    if (!await _confirmUseProp(titles[itemType]!, bodies[itemType]!)) return;
    if (!await _props.consume(s)) {
      if (mounted) setState(() {});
      return;
    }
    switch (itemType) {
      case 'shuffle':
        if (!_game.doShuffle()) {
          // 执行失败（概率极低）：额度已扣，提示并回补免费额度或库存
          s.owned += 1;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('洗牌失败，道具已退回')),
            );
          }
        }
      case 'hint':
        _game.highlightHint();
      case 'add_steps':
        _game.addSteps(5);
    }
    if (mounted) setState(() {});
  }

  /// 两段式道具（确认预检 → 进入待命 → 盘面执行成功才扣券）：
  /// hammer/force_swap/magic_wand。再次点击按钮取消待命（未扣券）。
  Future<void> _armProp(String itemType) async {
    final s = _props.slot(itemType)!;
    if (!s.available) return;
    // 已待命 → 取消
    final armedNow = itemType == 'hammer'
        ? _game.smashArmed
        : itemType == 'force_swap'
            ? _game.forceSwapArmed
            : _game.magicArmed;
    if (armedNow) {
      _game.cancelPropArming();
      if (mounted) setState(() {});
      return;
    }
    _game.cancelPropArming(); // 互斥：一次只有一个道具待命
    final titles = <String, String>{
      'hammer': '使用破坏锤？',
      'force_swap': '使用强制交换？',
      'magic_wand': '使用魔法棒？',
    };
    final bodies = <String, String>{
      'hammer': s.free > 0
          ? '确定要使用 1 次免费破坏（剩余 ${s.free} 次）吗？确认后点击盘面任意一颗糖直接消除（特殊糖按效果引爆）。'
          : '确定要消耗 1 张破坏锤（库存剩余 ${s.owned} 张）吗？确认后点击盘面任意一颗糖直接消除（特殊糖按效果引爆）。',
      'force_swap': s.free > 0
          ? '确定要使用 1 次免费强制交换（剩余 ${s.free} 次）吗？确认后先点选一颗糖，再点击相邻糖直接交换（无需组成三连）。'
          : '确定要消耗 1 张强制交换（库存剩余 ${s.owned} 张）吗？确认后先点选一颗糖，再点击相邻糖直接交换（无需组成三连）。',
      'magic_wand': s.free > 0
          ? '确定要使用 1 次免费魔法（剩余 ${s.free} 次）吗？确认后点击盘面任意一颗普通糖，将其变为横向条纹特效。'
          : '确定要消耗 1 张魔法棒（库存剩余 ${s.owned} 张）吗？确认后点击盘面任意一颗普通糖，将其变为横向条纹特效。',
    };
    if (!await _confirmUseProp(titles[itemType]!, bodies[itemType]!)) return;
    switch (itemType) {
      case 'hammer':
        _game.smashArmed = true;
      case 'force_swap':
        _game.forceSwapArmed = true;
      case 'magic_wand':
        _game.magicArmed = true;
    }
    if (mounted) setState(() {});
  }

  /// 道具按钮构建（道具栏：渲染于主控制栏上方）。
  List<GameAction> _buildPropActions() {
    final actions = <GameAction>[];
    void add(
      String itemType,
      IconData icon,
      String label, {
      bool selected = false,
      String? selectedLabel,
      VoidCallback? onTap,
      bool Function()? visible,
    }) {
      final s = _props.slot(itemType)!;
      if (s.item == null) return; // 未启用/未解锁：不渲染
      actions.add(GameAction(
        // 道具图标：game_items.icon 定版 SVG 资产优先（后台可配），空则内置 icon
        icon: icon,
        iconAsset: (s.item!.icon != null && s.item!.icon!.isNotEmpty)
            ? s.item!.icon
            : null,
        label: selected ? (selectedLabel ?? label) : label,
        badge: '${s.total}',
        extraTag: s.free > 0 ? '免${s.free}' : null,
        selected: selected,
        onPressed: s.available ? onTap : null,
      ));
    }

    add('hint', Icons.lightbulb_outline, '提示',
        onTap: () => _useImmediateProp('hint'));
    add('shuffle', Icons.shuffle_outlined, '洗牌',
        onTap: () => _useImmediateProp('shuffle'));
    add('hammer', Icons.construction_outlined, '破坏',
        selected: _game.smashArmed,
        selectedLabel: '点击目标',
        onTap: () => _armProp('hammer'));
    add('force_swap', Icons.swap_horiz_outlined, '强换',
        selected: _game.forceSwapArmed,
        selectedLabel: '点击目标',
        onTap: () => _armProp('force_swap'));
    add('magic_wand', Icons.auto_fix_high_outlined, '魔法',
        selected: _game.magicArmed,
        selectedLabel: '点击目标',
        onTap: () => _armProp('magic_wand'));
    // 加步卡仅限步模式渲染（不限步/限时无步数概念）
    if (_objective.steps > 0) {
      add('add_steps', Icons.exposure_plus_1, '加步',
          onTap: () => _useImmediateProp('add_steps'));
    }
    return actions;
  }


}
