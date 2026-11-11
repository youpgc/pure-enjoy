import 'package:flutter/material.dart';

import 'journey_battle_controller.dart';
import 'journey_battle_overlays.dart';
import 'journey_flame_game.dart';

/// 西行对局退出拦截：混入对局页 State，统一「确认退出 → 退回主页」链路。
///
/// 系统返回键由对局页的 PopScope 拦截后转交 [requestQuit]；确认退出的
/// [popToHub] 走命令式 popUntil——ModalRoute.didPop 只处理 local history、
/// 不咨询 popDisposition，命令式 pop 可绕过 PopScope 强制出栈，故对局页
/// PopScope 恒为 canPop:false 也不会把退出自拦截成死循环。
mixin JourneyBattleExitMixin<T extends StatefulWidget> on State<T> {
  /// 当前引擎实例（弹窗期冻结世界用）。
  JourneyFlameGame? get exitGame;

  /// 当前控制器（退出前清空摇杆输入）。
  JourneyBattleController? get exitController;

  /// 是否处于暂停态（暂停面板发起的退出无需再冻结引擎）。
  bool get exitPaused;

  /// 退回西行主页：沿途弹掉结算/暂停浮层与对局、关卡选择页。
  /// isFirst 保底：路由名缺失时至少停在栈根，避免把整栈弹空。
  void popToHub() {
    Navigator.of(context).popUntil(
      (r) => r.settings.name == 'journey_hub' || r.isFirst,
    );
  }

  /// 退出确认：系统返回键或暂停「放弃本难」触发时先弹确认弹窗，确认后才
  /// 真正退出；取消则留在对局（游戏恢复运行）。
  ///
  /// 弹窗期间冻结引擎世界（不弹暂停面板），避免用户在决策那 1~2 秒内被妖魔
  /// 击杀而触发异常浮层栈；取消时按原运行态恢复（运行态走摇杆接管恢复）。
  Future<void> requestQuit() async {
    final game = exitGame;
    final pauseForDialog = game != null && !exitPaused && !game.isEnded;
    if (pauseForDialog) {
      game.pauseEngine();
      exitController?.input.reset();
    }
    final confirmed = await JourneyPromptSheets.showQuitConfirm(context);
    if (!mounted) return;
    if (confirmed) {
      popToHub();
    } else if (pauseForDialog && !game.isEnded) {
      if (!game.isPausedForLevelUp) game.armJoystickResume();
    }
  }
}
