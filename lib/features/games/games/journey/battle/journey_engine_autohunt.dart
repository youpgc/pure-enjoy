/// 全图追猎（仅无尽妖潮，局外设置默认关闭）：
/// 达成「场上剩余普怪（妖王除外）≤阈值 且 玩家血量高于阈值」后本局锁定开启，
/// 剩余普怪无视离屏冻结与脱战距离，持续自动追寻玩家，省去满图找残留怪物。
/// 妖王恒定不受影响（保留驻点/冲撞 AI）。
part of 'journey_flame_game.dart';

/// 每帧判定触发条件；一旦锁定不再回退（本局有效）。
void tickAutoHunt(JourneyFlameGame game) {
  if (game._autoHuntActive || !game.autoHuntSetting) return;
  if (!_isEndless(game)) return;
  // 仅在本波怪已全部铺出后判定，防波初存活数尚少时误触发（休整期 planned=0 跳过）
  if (game._endlessWavePlanned <= 0 ||
      game._endlessSpawned < game._endlessWavePlanned) {
    return;
  }
  // 血量口径与 HUD 一致：hp/maxHp，maxHp<=0 视为未达成；阈值可后台配
  final maxHp = game.player.maxHp;
  final hpRatioGate = game.battleNum('endless', 'auto_hunt_hp_ratio', 0.5);
  if (maxHp <= 0 || game.player.hp / maxHp <= hpRatioGate) return;
  // 剩余普怪（妖王除外）计数：与离屏冻结共用 !isDead 口径
  final countGate =
      game.battleNum('endless', 'auto_hunt_remain_count', 10).round();
  var alive = 0;
  for (final m in game.monsters) {
    if (!m.isDead && !m.model.isBoss) alive++;
  }
  // 无活普怪可追（如妖王波普怪清光待补位）不触发，避免锁定后波及后续波次
  if (alive <= 0 || alive > countGate) return;
  game._autoHuntActive = true;
}

/// 某只怪物当前是否受全图追猎影响（妖王恒定返回 false）。
bool autoHuntApplies(JourneyFlameGame game, JourneyMonsterComponent m) =>
    game._autoHuntActive && !m.model.isBoss;
