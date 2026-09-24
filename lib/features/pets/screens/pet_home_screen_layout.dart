part of 'pet_home_screen.dart';

/// 宠物主页浮层布局（part）：中央舞台 / 多宠切换箭头 / 顶部历险横幅 /
/// 底部状态区 / 左右两列按钮。交互动作在 `pet_home_screen_actions.dart`，
/// 同文件的扩展成员之间直接裸调用（`unnecessary_this` 会报冗余的 `this.`）。

/// 左右浮动列占位宽（52px 按钮 + 边距），舞台与切换箭头据此让位
const double _kEdgeInset = 64;

extension _PetHomeLayout on _PetHomeScreenState {
  // ---------- 中央舞台（宠物主角，垂直水平居中） ----------

  Widget _stage() {
    final pet = _currentPet!;
    return Positioned.fill(
      // 底部让位状态面板（名牌+四维沉底），其余方向居中
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_kEdgeInset + 40, 0, _kEdgeInset + 40, 128),
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _interact(pet.id),
            child: PetLivingArt(
              frames: petIdleFrames(pet.speciesCode),
              fallbackAsset: petStageArtAsset(pet.speciesCode, pet.stage),
              action: _machine.current,
              onActionEnd: _onActionEnd,
            ),
          ),
        ),
      ),
    );
  }

  /// 点触宠物 == 右列「抚摸」钮（同一条 interact RPC + 同一被抚摸演出）
  void _interact(String petId) => _run(() => PetRpc.interact(petId),
      successMsg: _interactMsg, anim: PetAction.petted);

  List<Widget> _switchArrows() => [
        Positioned(
          left: _kEdgeInset - 4, top: 0, bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_left, onTap: () => _switchPet(-1)),
          ),
        ),
        Positioned(
          right: _kEdgeInset - 4, top: 0, bottom: 0,
          child: Center(
            child: PetSwitchArrow(
                icon: Icons.chevron_right, onTap: () => _switchPet(1)),
          ),
        ),
      ];

  // ---------- 顶部通知横幅（历险状态） ----------

  Widget _topBanner(ColorScheme cs) {
    final adv = _summary?.ongoingAdventure;
    if (adv == null || !adv.usable) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 76, vertical: 4),
          child: Center(child: PetAdventureBanner(adv: adv, onTap: _bannerTap())),
        ),
      ),
    );
  }

  // ---------- 底部状态区（名牌 + 四维沉底） ----------

  Widget _bottomPanel(ColorScheme cs) {
    final pet = _currentPet!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pet.status == PetPetStatus.adventuring) ...[
                const PetAdventureNote(),
                const SizedBox(height: 6),
              ],
              PetBottomStatusCard(pet: pet, onTap: _openAttributes),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 左侧入口列（返回键 + 背包/商城 + 更多，贴顶） ----------

  /// 左列只留高频直达（2026-09-24 D1）：
  /// 原先 7 枚（返回键 + 6×64dp 按钮 + 5×14 间距）合计约 502dp，Stack 里左列又
  /// 画在底部状态卡之后，小屏必然压住「经验/健康」两行；钱包/寄养/成就/繁育
  /// 收进「更多」弹出菜单后左列约 216dp，不再与底部重叠。
  Widget _leftRail() {
    return Positioned(
      left: 8,
      top: 0,
      child: Padding(
        // 贴顶：安全区下方留些许间距；返回键内联列首（避免与独立浮层重叠）
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetBackButtonCore(onBack: () => Navigator.maybePop(context)),
            const SizedBox(height: 10),
            PetEdgeButton(
                icon: Icons.inventory_2_outlined,
                label: '背包',
                onTap: _openBag),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.storefront_outlined,
                label: '商城',
                onTap: _openShop),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.more_horiz,
                label: '更多',
                onTap: _showMoreMenu),
          ],
        ),
      ),
    );
  }

  /// 「更多」弹出菜单：钱包 / 寄养 / 成就 / 繁育
  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, open) in <(IconData, String, void Function())>
                [
              (Icons.account_balance_wallet_outlined, '金币钱包', _openWallet),
              (Icons.luggage_outlined, '寄养仓库', _openFoster),
              (Icons.workspace_premium_outlined, '成就', _openAchievements),
              (Icons.favorite_outline, '繁育', _openBreed),
            ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(sheetCtx);
                open();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 右侧操作列（金币 + 喂食/抚摸/历险/任务，贴顶） ----------

  /// 蒙层策略：正常态无蒙层；冷却中黑蒙层显示倒计时；当日次数耗尽提示上限
  String? _overlay(Duration? cool, int? remain) {
    if (cool != null) return _budget.coolText(cool);
    if (remain != null && remain <= 0) return '已达上限';
    return null;
  }

  /// 喂食钮文案（2026-09-24 修回归）：免费额度冷却中要显示「还剩多久恢复」——
  /// 旧版这条信息挂在黑色蒙层上，改成"冷却不置灰（可吃口粮）"时蒙层被一并去掉了，
  /// 倒计时就再也没出现过。按钮此时仍可点，所以不能挂蒙层（会被读成禁用），
  /// 直接用文案位；额度用尽但没冷却时文案为「口粮」，明示这一钮现在走背包口粮。
  String get _feedLabel {
    if (_budget.feedFreeAvailable) return '喂食';
    final cool = _budget.feedCooldown;
    return cool == null ? '口粮' : _budget.coolTextShort(cool);
  }

  /// 喂食结果文案：增量全部来自后台配置（与服务端 `_pet_add_progress` 同源），
  /// 不再写死「喂饱啦」（旧文案与饱食度无关，20→40 也说"喂饱"，误导用户）
  String get _feedMsg {
    final delta = _budget.feedDeltaText;
    return delta.isEmpty ? '已喂食' : '已喂食 · $delta';
  }

  /// 抚摸结果文案（服务端加 `interact_mood`，旧实现读不到配置恒显示 +0）
  String get _interactMsg {
    final delta = _budget.interactDeltaText;
    return delta.isEmpty ? '它很开心' : '它很开心 · $delta';
  }

  Widget _rightRail() {
    final pet = _currentPet;
    final interactCool = _budget.interactCooldown;
    // 喂食置灰只看「吃饱了没有」plus 在场状态（2026-09-24 定版 A2）：
    // 免费额度（次数/冷却）不再把按钮打死——额度用完改吃背包口粮，
    // 服务端 rpc_pet_feed 道具档不占免费次数、不受冷却限制。
    final feedOff = pet == null ||
        _busy ||
        pet.status == PetPetStatus.adventuring ||
        _budget.isFull;
    final interactOff = pet == null ||
        _busy ||
        pet.status == PetPetStatus.adventuring ||
        _budget.blocked(interactCool, _budget.interactRemain);
    return Positioned(
      right: 8,
      top: 0,
      child: Padding(
        // 贴顶：安全区下方留些许间距；金币胶囊内联列首（避免与独立浮层重叠）
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetGoldBadgeCore(gold: _summary?.wallet.goldBalance ?? 0),
            const SizedBox(height: 10),
            PetEdgeButton(
                icon: Icons.restaurant,
                label: _feedLabel,
                // 蒙层只在真正"吃饱了"时出现；历险中/请求中属静默禁用，不误导
                overlay: _budget.isFull ? '已饱' : null,
                onTap: feedOff ? null : () => _onFeedTap()),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.touch_app_outlined,
                label: '抚摸',
                overlay: _overlay(interactCool, _budget.interactRemain),
                onTap: interactOff
                    ? null
                    : () => _run(() => PetRpc.interact(pet.id),
                        successMsg: _interactMsg, anim: PetAction.petted)),
            const SizedBox(height: 14),
            _adventureButton(),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.task_alt_outlined,
                label: '任务',
                onTap: _openQuests),
          ],
        ),
      ),
    );
  }
}
