part of 'journey_flame_game.dart';

/// 精英波复刷判定：replayed=本帧复刷并重置计数；
/// waiting=倒计时中（该波按已完成处理，允许兜底补怪避免空窗）；
/// disabled=非精英波或参数关闭（按普通完成波处理）。
enum _EliteRepeat { replayed, waiting, disabled }

/// 按怪种编码取本关池内模型；波次精英供给判定与普通刷怪共用。
JourneyMonsterModel? _modelOf(JourneyFlameGame game, String code) {
  for (final m in game.pool) {
    if (m.code == code) return m;
  }
  return null;
}

/// 时间轴波是否为精英波：怪种映射为精英且不是循环层。
bool _isRepeatableEliteWave(JourneyFlameGame game, JourneyWaveModel wave) {
  if (wave.loop) return false;
  return _modelOf(game, wave.monsterCode)?.isElite ?? false;
}

/// 精英波周期复刷：倒计时归零后重置该波计数，重新走正常刷怪节拍。
/// 计时中或关闭时不改变波次计数，由调用方按已完成波处理。
_EliteRepeat _eliteRepeatState(
  JourneyFlameGame game,
  JourneyWaveModel wave,
  List<double> repeatTimers,
  int index,
  List<double> prog,
  double dt,
) {
  if (index >= repeatTimers.length) return _EliteRepeat.disabled;
  if (!_isRepeatableEliteWave(game, wave)) return _EliteRepeat.disabled;
  final raw = game.battleNum(
    'spawn',
    'elite_wave_repeat_sec',
    kJourneyEliteWaveRepeatSec,
  );
  if (raw <= 0) return _EliteRepeat.disabled;
  final next = repeatTimers[index] + dt;
  if (next < raw.clamp(5.0, 600.0)) {
    repeatTimers[index] = next;
    return _EliteRepeat.waiting;
  }
  repeatTimers[index] = 0;
  prog[0] = 0;
  prog[1] = 0;
  return _EliteRepeat.replayed;
}

/// 循环层精英混入判定：保护期内不混入，
/// 比例从 journey_battle_params.spawn.loop_elite_ratio 读取。
bool _rollLoopElite(JourneyFlameGame game) {
  final protectSec =
      (game.config?.earlyGameProtectSec ?? kJourneyEarlyGameProtectSec)
          .toDouble();
  if (game._elapsed < protectSec) return false;
  final ratio = game
      .battleNum(
        'spawn',
        'loop_elite_ratio',
        kJourneySpawnLoopEliteRatio,
      )
      .clamp(0.0, 1.0);
  return ratio > 0 && game.rng.nextDouble() < ratio;
}
