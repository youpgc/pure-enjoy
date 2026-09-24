part of 'pet_home_screen.dart';

// 本文件是 State 的 part + extension，其中的 setState 运行期完全合法（同库、
// 就是 _PetHomeScreenState 的实例方法），但 @protected 规则不识别 extension 成员，
// 会误报 invalid_use_of_protected_member。搬回 State 类会顶破 500 行拆分，故整文件豁免。
// ignore_for_file: invalid_use_of_protected_member

/// 宠物主页交互动作（part）：统一动作包装 `_run`、喂食/抚摸回调、孵化流程、
/// 子页跳转、属性面板、历险四态（分流/领取/召回）。浮层构建见 `_PetHomeLayout`。
extension _PetHomeActions on _PetHomeScreenState {
  Future<void> _run(Future<String?> Function() action,
      {String? successMsg, PetAction? anim}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnackBar(context, petRpcErrorText(err));
      return;
    }
    if (anim != null) _playAction(anim);
    if (successMsg != null) {
      showSnackBar(context, successMsg);
    }
    _load();
  }

  /// 播放一次性动作（动作机按优先级/防抖裁决，被拒时静默跳过不打断当前演出）
  void _playAction(PetAction action) {
    if (!_machine.request(action)) return;
    _emitFx(action);
    setState(() {});
  }

  /// 动作 → 舞台粒子（进化给光柱+光环双特效；idle/行走/委屈不放粒子）
  ///
  /// 粒子色是表现层固定色（爱心必须粉、星星必须金），不跟随 App 主题，
  /// 与"数值/阈值一律读 pet_config"的口径无关。
  void _emitFx(PetAction action) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (action) {
      case PetAction.petted:
        _fx.emit(PetFxKind.hearts, const Color(0xFFFF7D9F));
      case PetAction.eat:
        _fx.emit(PetFxKind.crumbs, const Color(0xFFC99A5B));
      case PetAction.happy:
        _fx.emit(PetFxKind.stars, const Color(0xFFFFC94D));
      case PetAction.sleep:
        _fx.emit(PetFxKind.zzz, Colors.white);
      case PetAction.evolve:
        _fx.emit(PetFxKind.beam, primary);
        _fx.emit(PetFxKind.ring, primary);
      case PetAction.idle:
      case PetAction.walk:
      case PetAction.sad:
        break;
    }
  }

  /// 动作播完回落环境态（由 [PetLivingArt] 计时回调）
  void _onActionEnd(PetAction action) {
    _machine.finish(action);
    if (mounted) setState(() {});
  }

  // ---------- 喂食（免费额度 与 背包口粮 分流） ----------

  /// 喂食钮统一入口（2026-09-24 定版：喂食不限次数）
  ///
  /// 免费额度可用（无冷却 + 当日次数未尽）→ 走免费档；否则弹口粮浮层改吃背包
  /// 道具（服务端 `rpc_pet_feed` 道具档：不占免费次数、不受冷却限制）。
  /// 只有"吃饱了"（`pet_config.feed_full_hunger`）才置灰，见 `_budget.isFull`。
  Future<void> _onFeedTap() async {
    final pet = _currentPet;
    if (pet == null || _busy) return;
    if (_budget.feedFreeAvailable) {
      await _run(() => PetRpc.feed(pet.id),
          successMsg: _feedMsg, anim: PetAction.eat);
      return;
    }
    if (await showPetFeedSheet(context, pet.id) && mounted) {
      _playAction(PetAction.eat);
      _load();
    }
  }

  // ---------- 孵化（诞生弹窗 + 刷新） ----------

  /// 即开首颗蛋 → 诞生弹窗（基础型形象大图）→ 确认后刷新宠物信息
  ///
  /// 全程持 `_busy`：本流程含两次 await（取蛋列表 + 孵化 RPC），无防重入会
  /// 在慢网下被连点成"对同一颗蛋发起两次孵化"。
  Future<void> _hatchFirstEgg() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _hatchFirstEggInner();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hatchFirstEggInner() async {
    final (eggs, err) = await PetRpc.fetchEggs();
    if (err != null) {
      if (mounted) {
        showSnackBar(context, petRpcErrorText(err));
      }
      return;
    }
    PetEggModel? target;
    for (final e in eggs) {
      if (e.isInstant) {
        target = e;
        break;
      }
    }
    if (target == null) {
      if (!mounted) return;
      // P2：只剩等待型蛋（传说蛋需计时）时不再死路一条，转孵蛋页处理
      if (eggs.isEmpty) {
        showSnackBar(context, '背包里还没有蛋');
        return;
      }
      _openEggs();
      return;
    }
    final (result, hatchErr) = await PetRpc.hatchEgg(target.id);
    if (!mounted) return;
    if (hatchErr != null || result == null) {
      showSnackBar(context, petRpcErrorText(hatchErr));
      return;
    }
    // 图片权重：展示基础型形象大图（帧序列首帧，未登记种属回退静态立绘）
    final frames = petIdleFrames(result.speciesCode);
    await showPetBirthDialog(
      context,
      img: frames.isNotEmpty
          ? frames.first
          : petStageArtAsset(result.speciesCode, 0),
      result: result,
    );
    if (!mounted) return;
    // 弹窗关闭后再演出"开心"，否则 1.1s 演出全被弹窗挡住
    _playAction(PetAction.happy);
    // 点击确认后刷新宠物信息
    _load();
  }

  // ---------- 页面跳转（统一 _push 返回后刷新总览） ----------

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _load());
  }

  void _openBag() => _push(PetBagScreen(petId: _currentPet?.id));

  void _openShop() => _push(PetShopScreen(
      goldBalance: _summary?.wallet.goldBalance ?? 0,
      petId: _currentPet?.id));

  void _openQuests() => _push(const PetQuestsScreen());

  void _openWallet() => _push(const PetWalletScreen());

  /// 寄养仓库（养育格 <-> 寄养格搬运；寄养格未开启时页内引导商城扩容）
  void _openFoster() => _push(const PetFosterScreen());

  /// 成就（P2）：进入即幂等对齐一次服务端进度
  void _openAchievements() => _push(const PetAchievementsScreen());

  /// 繁育（P2）：未开通时页内给商城直达，不在主页做二次判断
  void _openBreed() => _push(const PetBreedScreen());

  /// 孵蛋（P2：即开 + 等待孵化双通道；入口亦在背包的蛋行）
  void _openEggs() => _push(const PetEggScreen());

  /// 养成（P2：进化 + 特性洗练），带上当前展示的这只
  void _openGrowth() => _push(PetGrowthScreen(petId: _currentPet?.id));

  /// 属性面板（四维/健康/性格/加点；加点成功回调刷新总览，面板内另给养成直达）
  void _openAttributes() {
    final pet = _currentPet;
    if (pet == null) return;
    showPetAttributesSheet(context,
        pet: pet, onChanged: _load, onGrowth: _openGrowth);
  }

  void _openAdventure() {
    final pet = _currentPet;
    if (pet == null) {
      showSnackBar(context, '先孵化一只宠物才能历险');
      return;
    }
    _push(PetAdventureScreen(
      petId: pet.id,
      petName: pet.name,
      adventure: _currentAdventure,
      tiers: _tierList(),
      petLevel: pet.level,
      petAttrs: pet.attributes,
      petHealth: pet.health,
      healthThreshold: _budget.cfg('adventure_health_threshold'),
    ));
  }

  // ---------- 主页历险交互（helper 见 pet_home_adventure.dart） ----------

  // 横幅点击分流：待救助 → 历险页处理；归来待领取 → claim 弹窗结算
  VoidCallback _bannerTap() =>
      _summary?.ongoingAdventure?.status == PetAdventureStatus.awaitingRescue
          ? _openAdventure
          : () => _runAdventure(claimAdventureResult);

  /// 历险动作统一入口：归来领取（弹窗）/ 召回确认（无奖励中断），完成后刷新
  Future<void> _runAdventure(AdventureAction run) async {
    final adv = _summary?.ongoingAdventure;
    if (adv == null || _busy) return;
    if (!adv.usable) {
      showSnackBar(context, '历险信息异常，请下拉刷新或重进宠物页重试');
      return;
    }
    if (await run(context, adv.id) && mounted) _load();
  }

  /// 右列历险钮四态（历险/召回/领取/救助，分支逻辑见 petAdventureRailButton）；
  /// adv 按当前宠过滤——B 宠在场时不再显示 A 宠历险的召回/领取态
  Widget _adventureButton() => petAdventureRailButton(
      adv: _currentAdventure,
      openAdventure: _openAdventure,
      claimResult: () => _runAdventure(claimAdventureResult),
      recall: () => _runAdventure(recallAdventureConfirmed));

  List<Map<String, dynamic>> _tierList() {
    final raw = _summary?.config['adventure_tiers'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
