part of 'pet_adventure_screen.dart';

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 中，分析器对本库内跨文件隐式调用的私有成员
// 引用计数有漏计（unused_element 误报）；extension 语境调 setState 触发
// protected 提示（运行时语义安全）。两处均为工具链误报，文件级压制。



extension _PetAdventureViews on _PetAdventureScreenState {
/// 历险页三态视图（出发前列表 / 进行中倒计时 / 遇险自救）：
/// 视图只消费状态机数据，不参与状态推进。

  // ---------- 出发前：历险地列表 ----------

  /// 隐秘境锁定卡：与普通卡同构（左星星图标 + 右锁标），名称保密；
  /// 点卡片确认后消耗罗盘解锁（等级未达也先展示，解锁与等级门槛独立）
  Widget _hiddenLockedCard(PetSpotModel spot) {
    final lv = spot.requiredLevel;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: cs.tertiary),
        title: const Text('未解锁的秘境'),
        subtitle: Text(
          '深处藏着独有的珍藏${lv != null && widget.petLevel < lv ? '（需 Lv.$lv）' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _unlockingCode == spot.code
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_outline, size: 18),
        onTap: _unlockingCode == spot.code
            ? null
            : () => _confirmUnlockHidden(spot),
      ),
    );
  }

  /// 解锁确认：罗盘是稀有道具，点卡片先确认再消耗
  Future<void> _confirmUnlockHidden(PetSpotModel spot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解锁秘境'),
        content: const Text('将消耗 1 个「星辰罗盘」解锁这座秘境，确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('解锁')),
        ],
      ),
    );
    if (ok == true) await _unlockHidden(spot);
  }

  /// 罗盘解锁：服务端消耗 1 个星辰罗盘（无罗盘由服务端报错转文案）
  Future<void> _unlockHidden(PetSpotModel spot) async {
    setState(() => _unlockingCode = spot.code);
    final err = await PetRpcAdventure.unlockHiddenSpot(spot.code);
    if (!mounted) return;
    setState(() => _unlockingCode = null);
    showPetToast(context,
        err != null ? petRpcErrorText(err) : '秘境已解锁：「${spot.name}」');
    if (err == null) await _load();
  }

  /// 历险规则说明（问号弹窗）：结果类型权重、掉落概率、长途独占与保底、
  /// 危险惩罚（含珍稀保护的丢物边界）——具体数值按图各异，引导去概率公示页
  void _showRulesSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.explore_outlined, size: 20),
                SizedBox(width: 8),
                Text('游历规则说明',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              _ruleLine('归来结果', '每次归来可能遇到求助、游玩、回忆或危险事件，收获各不相同'),
              _ruleLine('收获', '归来可获得经验与金币，走得越远收获越丰厚；长途出行还有机会获得稀有宝贝'),
              _ruleLine('独占掉落与保底', '进化石/星辰罗盘/系收藏品等仅长途概率获得，80 次未中必得（保底后清零）'),
              _ruleLine('危险', '可能受伤、心情变差，深处还会掉落金币或一件普通道具'),
              _ruleLine('珍稀保护', '珍贵收藏和进化材料受特别保护，永远不会丢失'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const PetOddsScreen())),
                  child: const Text('查看完整概率公示 →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleLine(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text(body,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      );

  Widget _spotsView() {
    final cs = Theme.of(context).colorScheme;
    if (_error != null && _spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_spots.isEmpty) {
      return const EmptyWidget(message: '暂无开放的游历地，敬请期待新地点');
    }
    // 健康出发门槛提示（历险失败惩罚会扣健康；阈值 0 = 未配置不提示）
    final healthLow = widget.healthThreshold > 0 &&
        widget.petHealth < widget.healthThreshold;
    final matched = _matchedSpot;
    // 全量构建(历险地仅 30 张):惰性列表下未构建项的 ctx 为 null
    // ensureVisible 会静默跳过——全量构建后推荐卡定位才可靠
    // 推荐横幅/健康提示钉在弹窗上部固定展示,滚动体仅地图列表
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (healthLow)
          Card(
            color: cs.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('宠物健康状况不佳，恢复健康后再出发吧'),
            ),
          ),
        if (matched != null)
          Padding(
            // 底距与地图卡间距一致(Card margin 4×2):定位后推荐卡上方留白同卡间
            padding: const EdgeInsets.only(bottom: 8),
            child: PetMatchBanner(
                spotName: matched.name, onTap: () => _showTierSheet(matched)),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final spot in _spots)
                  spot.hidden && !_hiddenUnlocked.contains(spot.code)
                      ? _hiddenLockedCard(spot)
                      : petSpotCard(
                          context,
                          spot: spot,
                          petLevel: widget.petLevel,
                          petAttrs: widget.petAttrs,
                          // 推荐卡挂 key:列表就绪后自动滚动到推荐位置;高亮边框
                          key: spot.id == _matchedSpotId ? _matchedCardKey : null,
                          highlight: spot.id == _matchedSpotId,
                          onTap: () => _showTierSheet(spot),
                        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTierSheet(PetSpotModel spot) {
    if (widget.tiers.isEmpty) {
      showPetToast(context, '游历时长还在准备中，稍后再来');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择「${spot.name}」的游历时长',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final t in widget.tiers)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(t['label'] as String? ?? t['tier'] as String? ?? ''),
                subtitle: Text(petDurationText(Duration(minutes: (t['minutes'] as num?)?.toInt() ?? 0))),
                trailing: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                onTap: _busy ? null : () => _start(spot, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------- 进行中：倒计时 + 领取 ----------

  /// 宠物形象（c1_neutral 中性帧，平铺展示）；取图链失败回退 [fallback]
  Widget _petArtOr(double size, {required Widget fallback}) {
    final art = petBaseArt(widget.petSpeciesCode, widget.petStage);
    if (art == null) return fallback;
    return Image.asset(
      art,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _ongoingView(PetAdventureBriefModel adv) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final end = adv.endAt;
    final finished = end == null || !now.isBefore(end);
    final remaining = end?.difference(now);
    // 历险地图信息
    final spotName = _spotName(adv.spotId);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 宠物形象平铺：c1_neutral 中性帧，取图失败
            // 回退原罗盘图标
            _petArtOr(120, fallback: Icon(Icons.explore, size: 72, color: cs.primary)),
            const SizedBox(height: 16),
            Text('${widget.petName} 正在外出游历',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (spotName != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('游历地图：$spotName',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (!finished) ...[
              Text(
                remaining! > Duration.zero
                    ? '预计 ${petDurationText(remaining)}后归来'
                    : '即将归来',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              const Text('游历结束后回来查看结果', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _confirmRecall,
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('召回'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _claim,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.redeem_outlined),
                label: const Text('查看游历结果'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- 遇险：自救 ----------

  Widget _rescueView(PetAdventureBriefModel adv) {
    final cs = Theme.of(context).colorScheme;
    final deadline = adv.rescueDeadline;
    final expired = deadline != null && !DateTime.now().isBefore(deadline);
    // 遇险地图信息（与进行中视图同源）
    final spotName = _spotName(adv.spotId);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 宠物形象平铺 + 右上警示角标，取图失败回退原警示图标
            Stack(
              clipBehavior: Clip.none,
              children: [
                _petArtOr(88,
                    fallback: Icon(Icons.warning_amber_rounded,
                        size: 72, color: cs.error)),
                Positioned(
                  top: -6,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration:
                        BoxDecoration(color: cs.error, shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${widget.petName} 遇到险情！',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (spotName != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place_outlined,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('遇险地图：$spotName',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              expired
                  ? '救援时间已过，NPC 会安全护送它回家'
                  : '救援时间截止：${deadline == null ? '-' : DateTimeUtils.formatToMinute(deadline)}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (!expired)
              FilledButton.icon(
                onPressed: _busy ? null : () => _rescueWithItem(),
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('使用救援道具自救'),
              ),
            const SizedBox(height: 8),
            Text(
              expired ? '点击下方按钮完成 NPC 救助' : '没有救援道具也没关系，时间到了 NPC 会去接它',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (expired) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _rescue(),
                child: const Text('等待 NPC 救助'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _rescueWithItem() async {
    // 从背包找救援道具（effect.type=rescue）
    final (bag, err) = await PetRpc.fetchBag();
    if (err != null) {
      if (mounted) {
        showPetToast(context, petRpcErrorText(err));
      }
      return;
    }
    PetBagItemModel? rescueItem;
    for (final b in bag) {
      if (b.effectType == 'rescue') {
        rescueItem = b;
        break;
      }
    }
    if (rescueItem == null) {
      if (mounted) {
        showPetToast(context, '背包中没有救援道具，可去商城购买或等待 NPC 救助');
      }
      return;
    }
    await _rescue(itemId: rescueItem.itemId);
  }
}
