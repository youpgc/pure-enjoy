/// 全图追猎（仅无尽妖潮，局外设置默认关闭）：
/// 本波怪铺完后，场上剩余普怪（妖王除外）降至阈值以内、且玩家血量高于
/// 门槛时，仅这批剩余普怪无视离屏冻结与脱战距离，持续自动追寻玩家，
/// 省去满图找残留怪物。妖王恒定不受影响（保留驻点/冲撞 AI）。
/// 条件逐帧重算，波次结束自动关闭，下一波重新判定；后台未配置键时回落
/// 内置阈值。
part of 'journey_flame_game.dart';

/// 每帧重算触发条件：不满足立即关闭，波次切换后自动等待下一波达成。
void tickAutoHunt(JourneyFlameGame game) {
  game._autoHuntActive = false;
  // 结算/升级选卡期引擎停摆，明确关闭追猎，避免标志停留在上一帧值
  if (game._ended || game._pendingLevelUps > 0) return;
  if (!game.autoHuntSetting || !_isEndless(game)) return;
  // 仅在本波怪已全部铺出后判定，防波初存活数尚少时误触发（休整期 planned=0 跳过）
  if (game._endlessWavePlanned <= 0 ||
      game._endlessSpawned < game._endlessWavePlanned) {
    return;
  }
  // 血量口径与 HUD 一致：hp/maxHp，maxHp<=0 视为未达成；阈值可后台配
  final maxHp = game.player.maxHp;
  final hpRatioGate = game.battleNum('endless', 'auto_hunt_hp_ratio', 0.5);
  if (maxHp <= 0 || game.player.hp / maxHp <= hpRatioGate) return;
  // 剩余普怪计数：与波次推进同口径（当前波 + 存活 + 妖王除外），
  // 超出阈值即早退，避免波中怪多时每帧遍历全场
  final countGate =
      game.battleNum('endless', 'auto_hunt_remain_count', 10).round();
  var alive = 0;
  for (final m in game.monsters) {
    if (m.isDead || m.model.isBoss || m.endlessWave != game._endlessWave) {
      continue;
    }
    if (++alive > countGate) return;
  }
  // 无活普怪可追（如妖王波普怪清光待补位）不触发，避免空转
  if (alive <= 0) return;
  game._autoHuntActive = true;
}

/// 某只怪物当前是否受全图追猎影响（妖王恒定返回 false）。
/// [game._autoHuntActive] 由 [tickAutoHunt] 每帧重算，仅剩余数达标时为真，
/// 故只影响最后剩余的普怪，波次结束随条件失效一并关闭。
bool autoHuntApplies(JourneyFlameGame game, JourneyMonsterComponent m) =>
    game._autoHuntActive && !m.model.isBoss;
