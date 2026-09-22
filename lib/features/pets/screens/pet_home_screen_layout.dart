part of 'pet_home_screen.dart';

/// 宠物主页浮层布局（part）：中央舞台 / 多宠切换箭头 / 顶部历险横幅 /
/// 底部状态区 / 左右两列按钮。交互动作在 `pet_home_screen_actions.dart`，
/// 跨 part 调用动作成员统一写 `this._xxx()`（扩展成员需显式接收者才稳）。

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
          child: PetLivingArt(
            frames: petIdleFrames(pet.speciesCode),
            fallbackAsset: petStageArtAsset(pet.speciesCode, pet.stage),
            excited: _excited,
            onTap: () => this._run(() => PetRpc.interact(pet.id),
                successMsg: '开心 +${_budget.cfg('interact_mood')}'),
          ),
        ),
      ),
    );
  }

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
    if (adv == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 76, vertical: 4),
          child: Center(child: PetAdventureBanner(adv: adv, onTap: this._bannerTap())),
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
              PetBottomStatusCard(pet: pet, onTap: this._openAttributes),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 左侧入口列（返回键 + 背包/商城/钱包/寄养，贴顶） ----------

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
                onTap: this._openBag),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.storefront_outlined,
                label: '商城',
                onTap: this._openShop),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.account_balance_wallet_outlined,
                label: '钱包',
                onTap: this._openWallet),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.luggage_outlined,
                label: '寄养',
                onTap: this._openFoster),
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

  Widget _rightRail() {
    final pet = _currentPet;
    final feedCool = _budget.feedCooldown;
    final interactCool = _budget.interactCooldown;
    // 历险中的宠物不在场，喂食/抚摸禁用（服务端同样拦截 PET_NOT_REARING）
    final feedOff = pet == null ||
        _busy ||
        pet.status == PetPetStatus.adventuring ||
        _budget.blocked(feedCool, _budget.feedRemain);
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
                label: '喂食',
                overlay: _overlay(feedCool, _budget.feedRemain),
                onTap: feedOff
                    ? null
                    : () => this._run(() => PetRpc.feed(pet.id),
                        successMsg: '喂饱啦', celebrate: true)),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.touch_app_outlined,
                label: '抚摸',
                overlay: _overlay(interactCool, _budget.interactRemain),
                onTap: interactOff
                    ? null
                    : () => this._run(() => PetRpc.interact(pet.id),
                        celebrate: true)),
            const SizedBox(height: 14),
            this._adventureButton(),
            const SizedBox(height: 14),
            PetEdgeButton(
                icon: Icons.task_alt_outlined,
                label: '任务',
                onTap: this._openQuests),
          ],
        ),
      ),
    );
  }
}
