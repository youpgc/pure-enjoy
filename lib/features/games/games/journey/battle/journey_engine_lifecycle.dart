part of 'journey_flame_game.dart';

/// 对局生命周期（extension，同 library 访问宿主私有成员）：
/// 击杀结算、通关条件达成、主动结算、三选一应用、死亡与还魂、浮动文字。
extension JourneyLifecycle on JourneyFlameGame {
  // ---- 伤害/击杀（damage part 调用）----
  void onMonsterKilled(JourneyMonsterComponent m) {
    _kills++;
    controller.hud.kills.value = _kills;

    // 妖王固定功德入账（merit_drop 配置列，计入铜钱明细）
    if (m.model.meritDrop > 0) {
      addMeritCoins(m.model.meritDrop);
    }

    // 悟空「大圣威压」：击杀 20% 概率触发 3 秒攻速增益
    if (character.code == 'wukong' && rng.nextDouble() < 0.20) {
      _wukongBuffTimer = 3.0;
    }

    // 身外身法（wukong 特殊能力）：每击杀 30 只触发 10s 临时分身+转速
    if (hasAbility('wukong')) {
      _shenfenKills++;
      if (_shenfenKills >= 30) {
        _shenfenKills = 0;
        _shenfenTimer = 10;
        spawnFloatText(
          player.position + Vector2(0, -36),
          '身外身法',
          const Color(0xFFE8C470),
        );
      }
    }

    spawnLoot(this, m);

    // 多场妖王战（如「三打白骨精」）：打完一场增强再战，末场进伏诛抉择
    if (m == boss && !_ended) {
      // 妖王大血条：死亡清零并熄灭领地显隐（多场战重进侦测圈再亮）
      controller.hud.bossHpRatio.value = 0;
      controller.hud.bossEngaged.value = false;
      final totalFights = level.bossFights > 1 ? level.bossFights : 1;
      if (_bossStage < totalFights - 1) {
        _bossStage++;
        respawnBoss(this);
      } else {
        _onBossFinalKill();
      }
    }
  }

  /// 满足通关条件（末场妖王伏诛/坚持功成/无尽末波）：**不主动结算**——
  /// 置标记亮出「结算」按钮，游玩照常；是否结算由玩家决定。
  void _markClearedAvailable(String bannerText) {
    _bossDefeated = true;
    controller.hud.bossDefeated.value = true;
    controller.hud.banner.value = '$bannerText · 可随时结算';
  }

  /// 末场妖王伏诛：按 journey_globals.talent_drop_rate 概率掉落天赋点
  /// （全部角色点池各 +1，入账异步不阻塞横幅）；横幅按实际入账结果
  /// 定稿（点池全满未入账时不虚报掉落）。
  void _onBossFinalKill() {
    final rate = config?.talentDropRate ?? kJourneyTalentDropRate;
    if (rng.nextDouble() >= rate) {
      _markClearedAvailable('妖王已伏诛');
      return;
    }
    dart_async.unawaited(
        JourneyProgressService.instance.grantTalentDrop().then((granted) {
      _markClearedAvailable(
          granted ? '妖王已伏诛 · 天赋点掉落 +1' : '妖王已伏诛');
    }));
    _markClearedAvailable('妖王已伏诛');
  }

  /// 主动结算（「结算」按钮/暂停面板「提前结算」）：走通关结算路径。
  void settleNow() => _finish(cleared: true);

  /// 三选一选定：应用加成；仍有余级则继续弹卡，否则恢复运行。
  /// （候选池构建见 choices part 的 drawChoices，本方法只结算。）
  void applyUpgrade(JourneyUpgradeChoice choice) {
    switch (choice.kind) {
      case JourneyUpgradeKind.slotLearn:
        learnSlot(choice.code);
        break;
      case JourneyUpgradeKind.slotUpgrade:
        upgradeSlot(choice.code);
        break;
      case JourneyUpgradeKind.passiveGrant:
        _grantPassiveWeapon(choice.code);
        break;
      case JourneyUpgradeKind.effectGrant:
        // 触发型法宝激活（§6）：入 effectWeapons，命中/受击/暴击时结算
        effectWeapons.add(choice.code);
        spawnFloatText(
          player.position + Vector2(0, -36),
          choice.title,
          const Color(0xFFE8C470),
        );
        break;
      case JourneyUpgradeKind.moveSpeed:
        moveSpeedAmp += config?.upgradeMove ?? 0.09;
        break;
      case JourneyUpgradeKind.maxHp:
        final hpUp = config?.upgradeHp ?? 20;
        player.maxHp += hpUp;
        player.hp += hpUp;
        controller.hud.maxHp.value = player.maxHp;
        controller.hud.hp.value = player.hp;
        break;
      case JourneyUpgradeKind.regen:
        player.regen += config?.upgradeRegen ?? 1.0;
        break;
      case JourneyUpgradeKind.pickupRange:
        player.pickupRange += config?.upgradePickup ?? 18;
        break;
    }
    _pendingLevelUps--;
    if (_pendingLevelUps > 0) {
      controller.onLevelUp(_charLv, paused: true);
    } else {
      _pausedByLevelUp = false;
      resumeEngine();
    }
  }

  /// 玩家血量变化上报：归零先判金身佛光免死（tang 特殊能力，每局仅一次，
  /// 优先于还魂流程），未拦截再走还魂（§3，剩余次数>0 弹确认，否则结算）。
  /// 调用方（takeDamage/heal/regen）不 await（fire-and-forget），
  /// 重入由 [_revivePending] 挡（确认弹窗期间归零不再触发）。
  Future<void> onPlayerHpChanged() async {
    controller.hud.hp.value = player.hp;
    if (player.hp > 0 || _ended || _revivePending) return;
    // 金身佛光·免死：回 30% 生命并跳过还魂/结算（仅一次，与还魂互斥）
    if (hasAbility('tang') && !_jinshenFatalUsed) {
      _jinshenFatalUsed = true;
      player.hp = player.maxHp * 0.3;
      controller.hud.hp.value = player.hp;
      spawnFloatText(
        player.position + Vector2(0, -36),
        '金身佛光·免死',
        const Color(0xFFF6E3B4),
      );
      return;
    }
    // 三根毫毛（扩展被动）：致命伤免死一次，回 heal 比例生命 + invuln 秒
    // 无敌帧（params.heal/params.invuln，单局一次）
    if (passiveSlotCodes.contains('sanheng_mao') && !_maoUsed) {
      _maoUsed = true;
      player.hp = player.maxHp * weaponParam('sanheng_mao', 'heal', 0.3);
      player.invulnTimer = weaponParam('sanheng_mao', 'invuln', 1.5);
      controller.hud.hp.value = player.hp;
      spawnFloatText(
        player.position + Vector2(0, -36),
        '毫毛护身！',
        const Color(0xFFF6E3B4),
      );
      return;
    }
    if (revivesLeft <= 0) {
      // 已达成通关条件（妖王伏诛/坚持功成/无尽末波）后死亡 → 按通关结算
      _finish(cleared: _bossDefeated);
      return;
    }
    _revivePending = true;
    pauseEngine();
    var confirmed = false;
    try {
      confirmed = await controller.onRevivePrompt(reviveCost);
    } catch (_) {
      confirmed = false;
    }
    if (confirmed) {
      doRevive();
    } else {
      _revivePending = false;
      // 已达成通关条件后拒绝还魂 → 同样按通关结算
      _finish(cleared: _bossDefeated);
    }
  }

  /// 还魂功德价（§3）：口径=进度服务（基准价×关卡号，缺省 20×关卡号）。
  int get reviveCost =>
      config?.reviveCostFor(level.levelNo) ?? 20 * level.levelNo;

  /// 浮动文字（暴击会心/功德/还魂/炼化等关键事件），渲染见 fx part。
  void spawnFloatText(Vector2 pos, String text, Color color) {
    fxLayer.spawnFloatText(pos, text, color);
  }

  void addMeritCoins(int coins) {
    _meritCoins += coins;
    controller.hud.meritCoins.value = _meritCoins;
  }

  void _finish({required bool cleared}) {
    if (_ended) return;
    _ended = true;
    pauseEngine();
    // 首通奖励仅首次通关该难发放（首通判定基准=进关时最远记录）。
    final firstClear = level.levelNo > controller.farthestAtStart;
    final clearBonus = cleared && firstClear ? level.firstClearMerit : 0;
    controller.onFinished(
      cleared: cleared,
      kills: _kills,
      meritFromCoins: _meritCoins,
      meritClearBonus: clearBonus,
      durationSec: _elapsed.round(),
    );
  }
}
