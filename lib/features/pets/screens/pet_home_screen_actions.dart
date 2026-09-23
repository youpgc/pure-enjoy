part of 'pet_home_screen.dart';

/// 宠物主页交互动作（part）：统一动作包装 `_run`、喂食/抚摸回调、孵化流程、
/// 子页跳转、属性面板、历险四态（分流/领取/召回）。浮层构建见 `_PetHomeLayout`。
extension _PetHomeActions on _PetHomeScreenState {
  Future<void> _run(Future<String?> Function() action,
      {String? successMsg, bool celebrate = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnackBar(context, petRpcErrorText(err));
      return;
    }
    if (celebrate) _celebrate();
    if (successMsg != null) {
      showSnackBar(context, successMsg);
    }
    _load();
  }

  void _celebrate() {
    setState(() => _excited = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _excited = false);
    });
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
      if (mounted) {
        showSnackBar(context, '没有可即开孵化的蛋');
      }
      return;
    }
    final (result, hatchErr) = await PetRpc.hatchEgg(target.id);
    if (!mounted) return;
    if (hatchErr != null || result == null) {
      showSnackBar(context, petRpcErrorText(hatchErr));
      return;
    }
    _celebrate();
    // 图片权重：展示基础型形象大图（帧序列首帧，未登记种属回退静态立绘）
    final frames = petIdleFrames(result.speciesCode);
    await showPetBirthDialog(
      context,
      img: frames.isNotEmpty
          ? frames.first
          : petStageArtAsset(result.speciesCode, 0),
      result: result,
    );
    // 点击确认后刷新宠物信息
    _load();
  }

  // ---------- 页面跳转（统一 _push 返回后刷新总览） ----------

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _load());
  }

  void _openBag() => _push(PetBagScreen(petId: _currentPet?.id));

  void _openShop() =>
      _push(PetShopScreen(goldBalance: _summary?.wallet.goldBalance ?? 0));

  void _openQuests() => _push(const PetQuestsScreen());

  void _openWallet() => _push(const PetWalletScreen());

  /// 寄养仓库（养育格 <-> 寄养格搬运；寄养格未开启时页内引导商城扩容）
  void _openFoster() => _push(const PetFosterScreen());

  /// 属性面板（四维/健康/性格/加点；加点成功回调刷新总览）
  void _openAttributes() {
    final pet = _currentPet;
    if (pet == null) return;
    showPetAttributesSheet(context, pet: pet, onChanged: _load);
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
