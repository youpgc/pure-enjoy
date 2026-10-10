import 'package:flutter/material.dart';

import '../../../../services/error_reporter.dart';
import '../../models/game_item_model.dart';
import '../../services/game_item_service.dart';
import '../../shared/game_shell.dart';
import 'tetris_mode.dart';

/// 俄罗斯方块道具域（二期 T2-04，参考消消乐 Match3Props / 2048 G2048Props 范式）：
/// - `slow`   时缓卡：30 秒内下落间隔 ×2（全模式）
/// - `laser`  激光卡：清除底部 3 行（含垃圾行；竞速模式不适用）
/// - `quake`  地震卡：震落实块、各列坍缩填平空洞（竞速模式不适用）
/// - `magnet` 磁铁卡：吸附到当前最优（消行最多）落点并锁定（闪电模式不适用）
/// - `swap`   换块卡：当前方块重掷为随机方块（全模式）
/// - `nuke`   清屏卡：清空整块棋盘终局翻盘（单局限 1；竞速模式不适用）
///
/// 数据驱动：game_items.enabled 控制存在（默认 false 由后台开启）；
/// 模式适用排除矩阵见 [TetrisProps._allowed]；即时型确认 → 引擎执行 →
/// 成功回调才扣券（两段式延迟扣券，match3 同款防「确认后未执行券已扣」）。
class TetrisPropSlot {
  final String itemType;
  GameItemModel? item;
  int free = 0;
  int owned = 0;

  TetrisPropSlot(this.itemType);

  int get total => free + owned;

  bool get available => item != null && total > 0;
}

class TetrisProps {
  final Map<String, TetrisPropSlot> _slots;

  TetrisProps()
      : _slots = <String, TetrisPropSlot>{
          for (final t in const <String>[
            'slow',
            'laser',
            'quake',
            'magnet',
            'swap',
            'nuke',
          ])
            t: TetrisPropSlot(t),
        };

  TetrisPropSlot? slot(String itemType) => _slots[itemType];

  Iterable<TetrisPropSlot> get slots => _slots.values;

  /// 模式适用矩阵：返回该 item_type 在 [mode] 下是否可用。
  static bool _allowed(String itemType, TetrisMode mode) {
    switch (itemType) {
      case 'slow':
      case 'swap':
        return true;
      case 'laser':
      case 'quake':
      case 'nuke':
        return mode != TetrisMode.sprint; // 污染竞速语义
      case 'magnet':
        return mode != TetrisMode.blitz; // 与 Frenzy 冲突
    }
    return false;
  }

  /// 加载道具目录与库存（仅 enabled 且通过适用矩阵的道具）。
  Future<void> load(TetrisMode mode) async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: 'tetris');
      final inv = await GameItemService.instance.fetchInventory();
      for (final it in items) {
        final s = _slots[it.itemType];
        if (s == null) continue;
        if (!_allowed(it.itemType, mode)) continue;
        final owned = inv[it.id] ?? 0;
        final free = it.freePerGame;
        final budget = (it.perGameLimit - free).clamp(0, it.perGameLimit);
        s.item = it;
        s.free = free;
        s.owned = owned < budget ? owned : budget;
      }
    } catch (e) {
      // 载入失败不影响对局，上报后台可观测（g2048 同款口径）
      ErrorReporter.reportMessage(
        '俄罗斯方块道具目录/库存加载异常：$e',
        module: 'games',
        level: 'warning',
      );
    }
  }

  /// 消耗一个（免费额度优先，超出扣购买库存）。
  /// 返回是否成功；失败时库存归零（异常兜底），调用方负责刷新。
  Future<bool> consume(TetrisPropSlot s) async {
    if (s.item == null) return false;
    if (s.free > 0) {
      s.free -= 1;
      return true;
    }
    final ok = await GameItemService.instance.consumeItem(s.item!.id);
    if (!ok) {
      s.owned = 0;
      return false;
    }
    s.owned -= 1;
    return true;
  }
}

/// 使用道具前的确认弹窗（即时型：确认 → 引擎执行 → onPropExecuted 成功才扣券）。
Future<bool?> confirmTetrisPropDialog(
  BuildContext context, {
  required String label,
  required String effectText,
  required int free,
  required int owned,
  required IconData icon,
  String? iconAsset,
}) {
  final useFree = free > 0;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: PropIcon(icon: icon, iconAsset: iconAsset),
      title: Text('使用$label？'),
      content: Text(
        useFree
            ? '确定要使用「$label」吗？将消耗 1 次免费次数（剩余 $free 次），使用后$effectText，不可撤销。'
            : '确定要使用「$label」吗？将消耗 1 张道具卡（库存剩余 $owned 张），使用后$effectText，不可撤销。',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确定使用'),
        ),
      ],
    ),
  );
}
