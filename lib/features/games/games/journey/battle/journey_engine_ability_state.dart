part of 'journey_flame_game.dart';

/// 角色专属天赋·特殊能力状态（主系标志分支满级解锁，loadout 注入）。
mixin JourneyAbilityStateMixin {
  /// 已解锁特殊能力标记（'ability_tang' 等；引擎钩子按标记生效）。
  final Set<String> abilities = <String>{};

  /// 是否持有某角色特殊能力（'tang'→'ability_tang'）。
  bool hasAbility(String char) => abilities.contains('ability_$char');

  /// 金身佛光（tang）：周期回血计时 / 每局首次致命伤免死已用标记。
  double _jinshenTimer = 0;
  bool _jinshenFatalUsed = false;

  /// 身外身法（wukong）：击杀计数（每 30 清零）/ 临时增益剩余时间。
  int _shenfenKills = 0;
  double _shenfenTimer = 0;

  /// 铜皮铁骨（bajie）：受击后减伤窗口剩余时间（3s）。
  double _bajieGuard = 0;

  /// 伏魔重击（shaseng）：蓄力计时 / 充能就绪标记。
  /// 周期走 ability 组参数，缺省 20s。
  double _fumoTimer = 0;
  bool _fumoCharged = false;

  /// 西游扩展批·特殊能力（扩展角色加强点点亮后生效）：
  /// 三头六臂（nezha）触发计时与增益窗口 / 兜率炉火（laojun）触发
  /// 计时与加持窗口 / 芭蕉罡风（tieshan）触发计时 / 紫金宝葫
  /// （jinjiao）本局攻击叠层（击杀精英/妖王 +1）。
  /// 各周期、窗口、层数上限与叠层增幅走 ability 组参数。
  double _nezhaTimer = 0;
  double _nezhaWindow = 0;
  double _laojunTimer = 0;
  double _laojunWindow = 0;
  double _tieshanTimer = 0;
  int _jinjiaoStacks = 0;

  /// 西游扩展批（被动/特效法宝）：
  /// 三根毫毛免死状态（0=就绪 / >0=冷却剩余 / -1=冷却配 0 时本局用尽）/ 金刚琢与阴阳二气瓶计时。
  double _maoCd = 0;
  double _zhuoTimer = 0;
  double _pingTimer = 0;
}
