import '../../models/game_model.dart';

/// 西行·游戏入口准入（独立判断，不依赖其他游戏的开放/解锁逻辑）。
///
/// 口径：游戏行启用 + code 为 journey（test_only 未发布游戏由大厅统一过滤）。
/// 配置不在此预拉：进入主界面后由页面按需加载并展示加载态，避免点击后
/// 同步等待全量配置表造成无响应。
class JourneyAccess {
  JourneyAccess._();

  /// 入口条件是否满足（同步本地判断，不发起网络请求）。
  static bool canEnter(GameModel game) =>
      game.enabled && game.code == 'journey';
}
