part of 'journey_flame_game.dart';

/// 经验与升级（extension，同 library 访问宿主私有成员）：
/// - 角色等级上限 = journey_globals.char_level_cap（后台可调，缺省 99；
///   槽位等级与角色等级独立，不受此上限影响）；
/// - 两段式经验条动画：升级瞬间先充满（旧值→expNeed 动画到满），
///   归零后（HUD 按 expReset 重建进度条，直接落位无反向 tween）再增长；
/// - 连升时逐级排队「充满→归零」，全部播完一次同步真实等级/需求/经验；
/// - 动画用 dart Timer 驱动（时长与 HUD TweenAnimationBuilder 300ms 对齐），
///   三选一暂停弹窗期间照常播放，不随引擎暂停冻结。
extension JourneyExp on JourneyFlameGame {
  /// 角色等级上限（配置快照优先，兜底 99）。
  int get _charLevelCap => config?.charLevelCap ?? kJourneyCharLevelCap;

  /// 经验入账与升级结算（loot part 拾取香火调用）。
  void gainExp(double amount) {
    if (_charLv >= _charLevelCap) return; // 满级：经验停止累计
    _exp += amount * expAmp;
    while (_exp >= _expNeed && _charLv < _charLevelCap) {
      _exp -= _expNeed;
      _charLv++;
      levelAttackTotal +=
          config?.levelAttackPerLv ?? kJourneyLevelAttackPerLv;
      final hpUp = config?.levelHpPerLv ?? kJourneyLevelHpPerLv;
      player.maxHp += hpUp;
      player.hp += hpUp;
      controller.hud.maxHp.value = player.maxHp;
      controller.hud.hp.value = player.hp;
      // 经验曲线（journey_globals.exp_base/exp_per_lv 后台可调，缺省 12/7）
      _expNeed =
          (config?.expBase ?? 12) + _charLv * (config?.expPerLv ?? 7);
      _pendingLevelUps++;
      // 升到上限的一级不排「充满→归零」段：满级后经验条直接落满格恒满
      if (_charLv < _charLevelCap) _expFillPending++;
      _refreshWeaponGrade(); // 法宝分级：品阶随角色等级提升
    }
    if (_charLv >= _charLevelCap) {
      _exp = _expNeed; // 顶格封条：满级后经验条冲满恒满，不再升级
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
      controller.hud.expNeed.value = _expNeed;
      controller.hud.exp.value = _exp;
    }
    if (_pendingLevelUps > 0 && !_pausedByLevelUp) {
      // 真暂停：选卡期间世界完全静止（怪物不逼近、节拍不走）
      _pausedByLevelUp = true;
      pauseEngine();
      controller.onLevelUp(_charLv, paused: true);
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
    controller.hud.level.value = _charLv;
    controller.hud.expNeed.value = _expNeed;
    controller.hud.exp.value = _exp;
  }

  void _scheduleExpFillReset() {
    // Dart 定时器（Duration 口径，与 HUD TweenAnimationBuilder 300ms 对齐）；
    // 三选一暂停弹窗期间照常走，动画不随引擎暂停冻结。
    _expFillTimer = dart_async.Timer(const Duration(milliseconds: 320),
        _advanceExpFill);
  }
}
