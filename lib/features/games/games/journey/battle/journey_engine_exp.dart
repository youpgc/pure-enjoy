part of 'journey_flame_game.dart';

/// 经验与升级（extension，同 library 访问宿主私有成员）：
/// - 角色等级上限 = journey_globals.char_level_cap（后台可调，缺省值仅作
///   兜底，不写死在逻辑里；槽位等级与角色等级独立，不受此上限影响）；
///   升到上限这一级时经验归零、分母改显 max（如 0/max），此后额外经验
///   继续入账并封顶数值上限（如 99999/max），经验条保持充满不显示进度；
///   上限提高时可直接退出累计态恢复常规曲线（预留等级上限突破）；
/// - 两段式经验条动画：升级瞬间先充满（旧值→expNeed 动画到满），
///   归零后（HUD 按 expReset 重建进度条，直接落位无反向 tween）再增长；
/// - 连升时逐级排队「充满→归零」，全部播完一次同步真实等级/需求/经验；
/// - 动画用 dart Timer 驱动（时长与 HUD TweenAnimationBuilder 300ms 对齐），
///   三选一暂停弹窗期间照常播放，不随引擎暂停冻结。
extension JourneyExp on JourneyFlameGame {
  /// 角色等级上限（配置快照优先，兜底 99）。
  int get _charLevelCap => config?.charLevelCap ?? kJourneyCharLevelCap;

  /// 境界档位（0 起，钳 9 档）：(等级−1)~/步长。步长可后台调（realm_step）。
  int get _realmIndex =>
      ((_charLv - 1) ~/ (config?.realmStep ?? kJourneyRealmStep)).clamp(0, 8);

  /// 当前境界名号（西游化 9 档，属性面板「境界」行展示）。取号链：
  /// 远端 realm_titles 专属 → 内置按角色名号表 → 通用名号池。
  String get realmTitle {
    final i = _realmIndex;
    return character.realmTitleAt(i) ??
        kJourneyRealmTitlesByChar[character.code]?[i] ??
        kJourneyRealmTitles[i.clamp(0, kJourneyRealmTitles.length - 1)];
  }

  /// 境界突破结算：档位边界（每 realm_step 级）触发一次——
  /// 增伤走Σ%加法合流（伤害定序口径），生命上限复利并同步 HUD。
  /// （_realmReached 宿主字段，见 journey_flame_game.dart）
  void _checkRealmBreakthrough() {
    final realm = _realmIndex;
    if (realm <= _realmReached) return;
    _realmReached = realm;
    damageAmp += config?.realmAmpPer ?? kJourneyRealmAmpPer;
    final hpUp = player.maxHp * (config?.realmHpPer ?? kJourneyRealmHpPer);
    player.maxHp += hpUp;
    player.hp += hpUp;
    controller.hud.maxHp.value = player.maxHp;
    controller.hud.hp.value = player.hp;
  }

  /// 经验需求曲线（journey_globals.exp_base/exp_per_lv/exp_curve_pow 可调）：
  /// exp_base + exp_per_lv × lv^pow。幂次 1.5 拉开高级段需求撑起 99 级
  /// 长线成长；pow=1 还原旧线性口径。
  double _expNeedFor(int lv) {
    // 无尽妖潮专属需求曲线：need = endless_exp_base + per_lv × lv^pow
    // （默认 12+28×lv^1.75）。产出侧普通/精英/妖王三类怪的经验共享
    // 波次成长乘区（exp_wave_gain）、妖王另走独立基准，整池随波扩张；
    // 需求取同阶幂次：波 17 约 17 级、第 81 波满级，末段波次预留纯挑战
    // （满级后经验转为 0/max 累计展示，不再升级）。
    if (level.kind == 'endless') {
      return ((config?.endlessExpBase ?? kJourneyEndlessExpBase) +
              (config?.endlessExpPerLv ?? kJourneyEndlessExpPerLv) *
                  math.pow(
                      lv, config?.endlessExpPow ?? kJourneyEndlessExpPow))
          .round()
          .toDouble();
    }
    // 主线/每日：exp_base + exp_per_lv × lv^pow（缺省 12+7×lv^1.5）。
    final pow = config?.expCurvePow ?? kJourneyExpCurvePow;
    return (config?.expBase ?? 12) + (config?.expPerLv ?? 7) * math.pow(lv, pow);
  }

  /// 进入满级累计态：满级瞬间经验归零、分母切 max（如 0/max），
  /// 此后经验从 0 起累计额外收益。_expNeed 保留为本级需求不覆写，
  /// 便于上限突破时无损退出。
  void _enterPostMaxAccumulation() {
    if (_postMaxExpAccumulating) return;
    _postMaxExpAccumulating = true;
    _exp = 0;
  }

  /// 退出满级累计态（预留等级上限突破）：累计经验按当前等级需求折算为
  /// 本级进度，避免下一笔经验因累计值远大于本级需求而一次性连升多级、
  /// 属性与境界瞬间跳变；整级部分不计入，等级提升交由突破逻辑另行结算。
  void _exitPostMaxAccumulation() {
    _postMaxExpAccumulating = false;
    controller.hud.expMaxed.value = false;
    if (_expNeed > 0) _exp %= _expNeed;
  }

  /// 经验入账与升级结算（loot part 拾取香火调用）。
  /// 满级后不再升级，经验继续入账并封顶数值上限，HUD 分母显示 max，
  /// 展示「当前经验/max」，经验条保持充满。
  void gainExp(double amount) {
    // 上限提高时先退出累计态（预留突破逻辑）：必须在入账与升级循环之前，
    // 否则累计大值会被 while 一次连升多级。折算为本级进度后再走常规结算。
    if (_postMaxExpAccumulating && _charLv < _charLevelCap) {
      _exitPostMaxAccumulation();
    }
    _exp += amount * expAmp;
    while (_exp >= _expNeed && _charLv < _charLevelCap) {
      _exp -= _expNeed;
      _charLv++;
      levelAttackTotal +=
          config?.levelAttackPerLv ?? kJourneyLevelAttackPerLv;
      // 固定额成长按蟠桃+生机比例同步放大，保持加成随生命成长持续提升；
      // 境界突破的百分比成长天然含这些比例部分，不做重复放大。
      final hpUp = (config?.levelHpPerLv ?? kJourneyLevelHpPerLv) *
          (1 + player.pantaoHpRatio + player.hpBonusRatio);
      player.maxHp += hpUp;
      player.hp += hpUp;
      controller.hud.maxHp.value = player.maxHp;
      controller.hud.hp.value = player.hp;
      _checkRealmBreakthrough(); // 境界突破：档位边界增伤/生命增幅
      _expNeed = _expNeedFor(_charLv);
      _pendingLevelUps++;
      // 满级那级也排「充满→归零」：先把本级经验充满（如 6907/6907），
      // 再在归零步切到 0/max 累计展示，衔接满级瞬间的经验清零。
      _expFillPending++;
      _refreshWeaponGrade(); // 法宝分级：品阶随角色等级提升
    }
    // 刚满级：本级满格走完充满段后归零，再切 0/max 累计展示；
    // 上限可后台调，逻辑只比对 _charLv 与 _charLevelCap，不写死具体等级。
    if (_charLv >= _charLevelCap) {
      _enterPostMaxAccumulation();
    }
    if (_postMaxExpAccumulating) {
      // 满级后经验继续入账并封顶数值上限（不再触发升级或选卡）。
      _exp = math.min(_exp, kJourneyPostMaxLevelExpCap);
    }
    if (_expFillPending > 0) {
      // 两段式动画进行中：真实值只在引擎侧累积，HUD 由定时器驱动
      // （防中途写入打断「充满」段，出现从满倒退的观感）。
      if (_expFillTimer == null) {
        controller.hud.exp.value = controller.hud.expNeed.value; // 充满段
        _scheduleExpFillReset();
      }
    } else {
      controller.hud.level.value = _charLv;
      controller.hud.realmTitle.value = realmTitle;
      controller.hud.expNeed.value = _expNeed;
      controller.hud.exp.value = _exp;
      controller.hud.expMaxed.value = _postMaxExpAccumulating;
    }
    if (_pendingLevelUps > 0 && !_pausedByLevelUp) {
      // 真暂停：选卡期间世界完全静止（怪物不逼近、节拍不走）
      _pausedByLevelUp = true;
      pauseEngine();
      controller.onLevelUp(_charLv);
    }
  }

  /// 充满段播完后的归零步：条按 expReset 新值重建（无反向 tween）；
  /// 连升则短暂归零后续排下一段充满，全部播完一次同步真实数值。
  void _advanceExpFill() {
    _expFillTimer = null;
    _expFillPending--;
    controller.hud.expReset.value++; // 归零：进度条按新 key 重建直接落位
    if (_expFillPending > 0) {
      controller.hud.exp.value = 0;
      _expFillTimer = dart_async.Timer(const Duration(milliseconds: 80), () {
        controller.hud.exp.value = controller.hud.expNeed.value; // 下段充满
        _scheduleExpFillReset();
      });
      return;
    }
    // 归零完成：此时才把分母切 max，开始「当前累计/max」展示。
    controller.hud.level.value = _charLv;
    controller.hud.realmTitle.value = realmTitle;
    controller.hud.expNeed.value = _expNeed;
    controller.hud.exp.value = _exp;
    controller.hud.expMaxed.value = _postMaxExpAccumulating;
  }

  void _scheduleExpFillReset() {
    // Dart 定时器（Duration 口径，与 HUD TweenAnimationBuilder 300ms 对齐）；
    // 三选一暂停弹窗期间照常走，动画不随引擎暂停冻结。
    _expFillTimer = dart_async.Timer(const Duration(milliseconds: 320),
        _advanceExpFill);
  }
}
