import '../../models/game_model.dart';
import 'services/journey_config_service.dart';

/// 西行·游戏入口准入（独立判断，不依赖其他游戏的开放/解锁逻辑）。
///
/// 口径：游戏行启用 + 环境可见（test_only 未发布游戏由大厅统一过滤，
/// 仅 debug 包展示）+ 配置可获取（远端或兜底）。判定逻辑收敛于此文件，
/// 大厅与其他模块只调用，不自行复制条件。
class JourneyAccess {
  JourneyAccess._();

  /// 入口条件是否满足（满足才允许进入主界面）。
  static Future<bool> canEnter(GameModel game) async {
    if (!game.enabled || game.code != 'journey') return false;
    try {
      await JourneyConfigService.instance.fetch();
      return true;
    } catch (_) {
      return false;
    }
  }
}
