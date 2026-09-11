import 'package:flutter/material.dart';

import '../../../../services/error_reporter.dart';
import '../../models/game_item_model.dart';
import '../../services/game_item_service.dart';
import '../../shared/game_shell.dart';

/// 2048 道具域（2026-09-10，参考消消乐 Match3Props 范式）：
/// - `add_time` 加时卡（限时模式）：剩余时间 +15 秒
/// - `add_steps` 加步卡（挑战模式）：剩余步数 +5
///
/// 数据驱动：game_items.enabled 控制存在（后台可测），item.mode 限定
/// 适用模式（timed/challenge，空 = 通用）；宿主再按本局模式过滤渲染。
/// 即时型道具（非两段式）：确认弹窗后执行并扣券。
class G2048PropSlot {
  final String itemType;
  GameItemModel? item;
  int free = 0;
  int owned = 0;

  G2048PropSlot(this.itemType);

  int get total => free + owned;

  bool get available => item != null && total > 0;
}

class G2048Props {
  final Map<String, G2048PropSlot> _slots;

  G2048Props() : _slots = <String, G2048PropSlot>{
    'add_time': G2048PropSlot('add_time'),
    'add_steps': G2048PropSlot('add_steps'),
  };

  G2048PropSlot? slot(String itemType) => _slots[itemType];

  /// 加载道具目录与库存。仅载入「item.mode 匹配 [modeCode] 或通用」且
  /// 引擎本局生效的道具：加时卡要求本局有限时、加步卡要求本局有限步。
  Future<void> load({
    required bool hasTimeLimit,
    required bool hasMovesLimit,
    required String modeCode,
  }) async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: 'g2048');
      final inv = await GameItemService.instance.fetchInventory();
      for (final it in items) {
        final s = _slots[it.itemType];
        if (s == null) continue;
        final modeOk = it.mode.isEmpty || it.mode == modeCode;
        final engineOk = it.itemType == 'add_time'
            ? hasTimeLimit
            : it.itemType == 'add_steps'
                ? hasMovesLimit
                : false;
        if (!modeOk || !engineOk) continue;
        final owned = inv[it.id] ?? 0;
        final free = it.freePerGame;
        final budget = (it.perGameLimit - free).clamp(0, it.perGameLimit);
        s.item = it;
        s.free = free;
        s.owned = owned < budget ? owned : budget;
      }
    } catch (e) {
      // 载入失败不影响对局，但上报后台可观测（2026-09-11 排查道具栏空问题）
      ErrorReporter.reportMessage(
        '2048 道具目录/库存加载异常：$e',
        module: 'games',
        level: 'warning',
      );
    }
  }

  /// 消耗一个（免费额度优先，超出扣购买库存）。
  /// 返回是否成功；失败时额度归零（库存异常兜底），调用方负责刷新。
  Future<bool> consume(G2048PropSlot s) async {
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

/// 使用道具前的确认弹窗（即时型：确认即执行并扣券）。
/// [effectText] 描述使用效果（如「剩余时间 +15 秒」）。
Future<bool?> confirmG2048PropDialog(
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
