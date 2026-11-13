part of 'journey_flame_game.dart';

/// 恢复门禁：点继续/选卡只解除界面，世界保持时停，玩家按下摇杆才恢复，
/// 消除两次操作之间世界自行推进的时间差。
mixin JourneyResumeGateMixin on FlameGame {
  JourneyBattleController get controller;

  bool _resumeOnJoystick = false;

  /// 引擎是否正等待摇杆接管（HUD 提示与恢复判定依据）。
  bool get resumeOnJoystick => _resumeOnJoystick;

  /// 进入等待接管态：保持暂停，只亮提示。
  void armJoystickResume() {
    _resumeOnJoystick = true;
    controller.hud.awaitingJoystick.value = true;
  }

  /// 玩家按下摇杆：正式恢复对局，同一手势同时开始驱动移动。
  void resumeFromJoystick() {
    if (!_resumeOnJoystick) return;
    _resumeOnJoystick = false;
    controller.hud.awaitingJoystick.value = false;
    resumeEngine();
  }
}

/// 对局生命周期（extension，同 library 访问宿主私有成员）：
/// 击杀结算、通关条件达成、主动结算、三选一应用、死亡与还魂、浮动文字。
extension JourneyLifecycle on JourneyFlameGame {
  // ---- 伤害/击杀（damage part 调用）----
  void onMonsterKilled(JourneyMonsterComponent m) {
    // 结算快照取走后不再改写局内计数与掉落
    if (_ended) return;
    _kills++;
    controller.hud.kills.value = _kills;
    // 分类型击杀累计（击杀图鉴数据源；妖怪/妖王共用 model.code）
    killsByCode.update(m.model.code, (v) => v + 1, ifAbsent: () => 1);

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

    // 紫金宝葫（jinjiao 特殊能力）：精英/妖王被杀收入宝葫炼化，
    // 回复 15% 最大生命且本局攻击 +3%/层（钳 20 层即上限 +60%）
    if (hasAbility('jinjiao') && (m.model.isElite || m.model.isBoss)) {
      final lit = _jinjiaoStacks < JourneyFlameGame._jinjiaoMaxStacks;
      if (lit) _jinjiaoStacks++;
      player.heal(player.maxHp * 0.15);
      spawnFloatText(
        player.position + Vector2(0, -36),
        lit
            ? '紫金宝葫 · 攻击 +${_jinjiaoStacks * 3}%'
            : '紫金宝葫 · 已满层',
        const Color(0xFFE8C470),
      );
    }

    spawnLoot(this, m);

    // 多场妖王战（如「三打白骨精」）：打完一场增强再战，末场进伏诛抉择
    if (m == boss && !_ended) {
      // 妖王大血条：死亡清零并熄灭领地显隐（多场战重进侦测圈再亮）
      controller.hud.bossHpRatio.value = 0;
      controller.hud.bossEngaged.value = false;
      controller.hud.bossHp.value = 0;
      // 末场伏诛后罗盘与妖王点一并熄灭；多场战重生时再置回 true
      controller.hud.bossPresent.value = false;
      final totalFights = level.bossFights > 1 ? level.bossFights : 1;
      if (_bossStage < totalFights - 1) {
        _bossStage++;
        // 妖王阵亡→复活/新妖王降临冷却：罗盘位展示倒计时常显，归零由
        // tickBossRespawnCountdown 触发据点重生（如「三打白骨精」击败一场
        // 后冷却再刷新，避免瞬间满血重现打断节奏）
        _bossRespawnCountdown =
            (config?.bossRespawnCdSec ?? kJourneyBossRespawnCdSec).toDouble();
        final secs = _bossRespawnCountdown.round();
        controller.hud.bossSpawnIn.value = secs;
        controller.hud.banner.value = '妖王兵解 · $secs 秒后重现';
      } else {
        _onBossFinalKill();
      }
    }
    // 无尽妖潮妖王波：击杀妖王也按 talent_drop_rate 概率掉落天赋点。
    // 无尽模式无据点妖王、game.boss 恒 null，故不触发上面末场伏诛钩子；
    // 此处独立判定（避免与主线妖王伏诛重复发放），命中仅飘字、不改结算态。
    if (_isEndless(this) && m.model.isBoss && !_ended) {
      final rate = config?.talentDropRate ?? kJourneyTalentDropRate;
      if (rng.nextDouble() < rate) {
        dart_async.unawaited(
          JourneyProgressService.instance.grantTalentDrop().then((granted) {
            if (granted) {
              spawnFloatText(
                m.position, '天赋点掉落 +1', const Color(0xFFE8C470));
            }
          }),
        );
      }
    }
  }

  /// 满足通关条件（末场妖王伏诛/西行功成/无尽末波）：**不主动结算**——
  /// 置标记亮出「结算」按钮，游玩照常；是否结算由玩家决定。
  void _markClearedAvailable(String bannerText) {
    _bossDefeated = true;
    controller.hud.bossDefeated.value = true;
    controller.hud.banner.value = '$bannerText · 可随时结算';
  }

  /// 末场妖王伏诛：按 journey_globals.talent_drop_rate 概率掉落天赋点
  /// （全账号共享天赋点池 +1，入账异步不阻塞横幅）；横幅按实际入账结果
  /// 定稿（未入账时不虚报掉落）。
  void _onBossFinalKill() {
    final rate = config?.talentDropRate ?? kJourneyTalentDropRate;
    if (rng.nextDouble() >= rate) {
      _markClearedAvailable('妖王已伏诛');
      return;
    }
    dart_async.unawaited(
        JourneyProgressService.instance.grantTalentDrop().then((granted) {
      _markClearedAvailable(granted ? '妖王已伏诛 · 天赋点掉落 +1' : '妖王已伏诛');
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
      case JourneyUpgradeKind.attack:
        final step = config?.upgradeAttack ?? kJourneyUpgradeAttack;
        final cap = config?.attackUpgradeCap ?? kJourneyAttackUpgradeCap;
        cardAttackTotal = math.min(cardAttackTotal + step, cap);
        _refreshWeaponGrade();
        break;
    }
    _pendingLevelUps--;
    if (_pendingLevelUps > 0) {
      controller.onLevelUp(_charLv, paused: true);
    } else {
      _pausedByLevelUp = false;
      armJoystickResume();
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
      // 已达成通关条件（妖王伏诛/西行功成/无尽末波）后死亡 → 按通关结算
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

  /// 还魂功德价（§3）：与进度服务同源（基准价×关卡号并封顶），
  /// 配置快照未就绪时回落内置基准与封顶。
  int get reviveCost => config?.reviveCostFor(level.levelNo) ??
      (kJourneyReviveMeritBase * level.levelNo)
          .clamp(0, kJourneyReviveMeritCap);

  /// 浮动文字（暴击会心/功德/还魂/炼化等关键事件），渲染见 fx part。
  void spawnFloatText(Vector2 pos, String text, Color color) {
    fxLayer.spawnFloatText(pos, text, color);
  }

  void addMeritCoins(int coins) {
    // 每日游历局内功德上限：达 meritCap 后停止增长（仍可继续割草），
    // 与局内角色等级 99 满级停涨同源；其余模式按实际获取累计。
    if (level.kind == 'daily') {
      final cap = config?.meritCap ?? 9999;
      final next = _meritCoins + coins;
      _meritCoins = next > cap ? cap : next;
    } else {
      _meritCoins += coins;
    }
    controller.hud.meritCoins.value = _meritCoins;
  }

  /// 吸血入账：按最近 1s 滑动窗口把合计回复钳到最大生命 10%，
  /// 禁疗/满血时不占用窗口额度，避免额度被无效回复消耗。
  void addLifestealHeal(double amount) {
    if (amount <= 0) return;
    if (player.healBlockTimer > 0 || player.hp >= player.maxHp) return;
    final cutoff = _elapsed - 1.0;
    while (_lifestealHeals.isNotEmpty &&
        _lifestealHeals.first.$1 <= cutoff) {
      _lifestealHeals.removeAt(0);
    }
    var used = 0.0;
    for (final entry in _lifestealHeals) {
      used += entry.$2;
    }
    final cap = player.maxHp * kJourneyLifestealSecCapRatio;
    final room = math.max(player.maxHp - player.hp, 0.0);
    final granted = math.min(
      amount,
      math.min(math.max(cap - used, 0.0), room),
    );
    if (granted <= 0) return;
    _lifestealHeals.add((_elapsed, granted));
    player.heal(granted);
  }

  void _finish({required bool cleared}) {
    if (_ended) return;
    _ended = true;
    _resumeOnJoystick = false;
    controller.hud.awaitingJoystick.value = false;
    pauseEngine();
    // 首通判定基准=进关时最远记录
    final firstClear = level.levelNo > controller.farthestAtStart;
    // 通关奖励：首通发 firstClearMerit；重复通关也发——
    // boss 关(firstClearMerit>0)给首通 30%，普通关(firstClearMerit=0)给固定 10；
    // 无尽/游历(levelNo<=0)不重复发（首通本就不计）。
    final clearBonus = !cleared
        ? 0
        : firstClear
            ? level.firstClearMerit
            : (level.levelNo <= 0
                ? 0
                : (level.firstClearMerit > 0
                    ? (level.firstClearMerit * 0.3).round()
                    : 10));
    controller.onFinished(
      cleared: cleared,
      kills: _kills,
      meritFromCoins: _meritCoins,
      meritClearBonus: clearBonus,
      durationSec: _elapsed.round(),
    );
  }
}
