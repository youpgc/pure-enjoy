part of 'g2048_game.dart';

// 本文件是 State 的 part + extension，其中的 setState 运行期完全合法（同库、
// 就是 State 子类的实例方法），但 @protected 规则不识别 extension 成员，
// 会误报 invalid_use_of_protected_member。搬回 State 类会顶破 500 行拆分，故整文件豁免。
// ignore_for_file: invalid_use_of_protected_member

/// 2048 道具栏与道具使用（part of g2048_game，共享 State 私有状态）。
///
/// 从 g2048_game.dart 抽离（审查 P1 单文件超 500 行）：加时卡/加步卡按钮构建、
/// 二次确认与扣券生效。纯代码搬迁，数值口径（+15 秒 / +5 步）零变更。
extension _G2048PropActions on _G2048GameState {
  /// 道具按钮构建（与消消乐同口径）：目录已载入即渲染（0 库存禁用态），
  /// 有额度才可点击。
  GameAction _buildPropAction(
    String itemType, {
    required IconData icon,
    required String label,
  }) {
    final s = _props.slot(itemType);
    return GameAction(
      icon: icon,
      iconAsset: (s?.item?.icon != null && s!.item!.icon!.isNotEmpty)
          ? s.item!.icon
          : null,
      label: label,
      badge: '${s?.total ?? 0}',
      extraTag: (s?.free ?? 0) > 0 ? '免${s!.free}' : null,
      onPressed: (s?.available ?? false) ? () => _confirmProp(itemType) : null,
    );
  }

  /// 使用道具前的确认弹窗（即时型：确认即执行并扣券）。
  Future<void> _confirmProp(String itemType) async {
    final s = _props.slot(itemType);
    if (s == null || !s.available || _finished) return;
    final isTime = itemType == 'add_time';
    final sure = await confirmG2048PropDialog(
      context,
      label: isTime ? '加时卡' : '加步卡',
      effectText: isTime ? '本局剩余时间 +15 秒' : '剩余步数 +5',
      free: s.free,
      owned: s.owned,
      icon: isTime ? Icons.timer_outlined : Icons.exposure_plus_1,
      iconAsset: s.item?.icon,
    );
    if (sure == true) await _useProp(itemType);
  }

  /// 使用道具：先免费用完再消耗库存，成功后应用效果。
  Future<void> _useProp(String itemType) async {
    final s = _props.slot(itemType);
    if (s == null || !s.available || _finished) return;
    final ok = await _props.consume(s);
    if (!ok) {
      if (mounted) setState(() {});
      return;
    }
    if (itemType == 'add_time') {
      _bonusSeconds += 15; // 与消消乐加时卡同口径
    } else {
      _movesBonus += 5; // 与消消乐加步卡同口径
    }
    GameAudio.instance.prop();
    if (mounted) setState(() {});
  }
}
