import '../../models/game_item_model.dart';
import '../../services/game_item_service.dart';

/// 消消乐道具域管理（宿主页专用，消除 N 套重复的加载/消耗逻辑）。
///
/// 道具清单（game_items.item_type，均为 match3 通用 mode=''）：
/// - `shuffle` 洗牌卡 / `hammer` 破坏锤 / `hint` 提示卡
/// - `force_swap` 强制交换 / `magic_wand` 魔法棒 / `add_steps` 加步卡
///
/// 渲染双条件（宿主负责）：game_items.enabled（数据开关，后台可测）+
/// level.config.propUnlock（{item_type: 解锁关号}，未配置 = 允许）。
class Match3PropSlot {
  final String itemType;
  GameItemModel? item;
  int free = 0;
  int owned = 0;

  Match3PropSlot(this.itemType);

  int get total => free + owned;

  /// 是否可用（目录启用 + 本局剩余额度 > 0）
  bool get available => item != null && total > 0;
}

class Match3Props {
  final Map<String, Match3PropSlot> _slots;

  Match3Props(List<String> itemTypes)
      : _slots = {for (final t in itemTypes) t: Match3PropSlot(t)};

  Match3PropSlot? slot(String itemType) => _slots[itemType];

  /// 加载道具目录与库存（enabled 过滤在服务端 select 条件内）。
  ///
  /// [propUnlock] 为 level.config['propUnlock']（可 null）：键为 item_type、
  /// 值为解锁关号，level_no 达标才载入；未配置该键 = 允许。
  Future<void> load({
    required String gameCode,
    required int levelNo,
    Object? propUnlock,
  }) async {
    try {
      final items =
          await GameItemService.instance.fetchItems(gameCode: gameCode);
      final inv = await GameItemService.instance.fetchInventory();
      bool allowed(String itemType) {
        if (propUnlock is Map) {
          final v = propUnlock[itemType];
          if (v is num) return levelNo >= v.toInt();
        }
        return true; // 未配置 = 允许
      }

      for (final it in items) {
        final s = _slots[it.itemType];
        if (s == null || !allowed(it.itemType)) continue;
        final owned = inv[it.id] ?? 0;
        final free = it.freePerGame;
        final budget = (it.perGameLimit - free).clamp(0, it.perGameLimit);
        s.item = it;
        s.free = free;
        s.owned = owned < budget ? owned : budget;
      }
    } catch (e) {
      // 载入失败不影响对局
    }
  }

  /// 消耗一个（免费额度优先，超出扣购买库存）。
  ///
  /// 返回是否成功；失败时槽位额度归零（库存异常兜底），调用方负责 UI 刷新。
  /// **两段式道具（hammer/force_swap/magic_wand）应在引擎执行成功后才调用**
  /// ——确认弹窗只做可用性预检，执行成功才真正扣减，杜绝「确认后未执行
  /// 券已扣」的闭环漏洞。
  Future<bool> consume(Match3PropSlot s) async {
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
