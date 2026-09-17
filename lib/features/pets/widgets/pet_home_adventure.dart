import 'package:flutter/material.dart';

import '../models/pet_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';
import 'pet_claim_result_dialog.dart';
import 'pet_home_overlays.dart';

/// 主页历险动作集（2026-09-17 历险闭环修复）
///
/// 主页横幅 / 右列按钮的历险交互统一入口：
/// - 归来领取：rpc_pet_adventure_claim → 结果弹窗（成功奖励三色演出 /
///   遇险惩罚提示），不跳历险页（claim 只可调用一次，roll 中 danger 后
///   转 awaiting_rescue，后续走救助链路）；
/// - 召回确认：进行中历险无奖励中断（rpc_pet_adventure_recall）；
/// - 右列历险钮四态分支（历险入口 / 召回 / 领取 / 救助）。
/// 独立成文件以保证 pet_home_screen 行数在 500 以内；
/// 动作返回 true 表示状态已变化（调用方刷新总览）。

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// 主页历险动作签名（归来领取 / 召回确认；返回 true = 状态已变化）
typedef AdventureAction = Future<bool> Function(
    BuildContext context, String adventureId);

/// 归来领取：claim → 成功奖励弹窗 / 遇险惩罚提示
Future<bool> claimAdventureResult(
  BuildContext context,
  String adventureId,
) async {
  final (data, err) = await PetRpc.adventureClaim(adventureId);
  if (!context.mounted) return false;
  if (err != null) {
    _toast(context, petRpcErrorText(err));
    return false;
  }
  if (data?['status'] == 'awaiting_rescue') {
    await showPetDangerDialog(
        context, deadline: data?['rescue_deadline'] as String?);
    return true;
  }
  if (data?['status'] == 'claimed') {
    // 掉落明细（fix_pet_adventure_claim_items：claim 返回 items: [{code,name,qty}]）
    final items = <({String name, int qty})>[];
    final rawItems = data?['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          items.add((
            name: (it['name'] as String?) ?? (it['code'] as String? ?? '道具'),
            qty: (it['qty'] as num?)?.toInt() ?? 1,
          ));
        }
      }
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => PetClaimResultDialog(
        result: data?['result_type'] as String? ?? 'play',
        gold: (data?['gold'] as num?)?.toInt() ?? 0,
        exp: (data?['exp'] as num?)?.toInt() ?? 0,
        items: items,
      ),
    );
    return true;
  }
  return false;
}

/// 召回确认：AlertDialog 二次确认 → 无奖励中断（与历险页 _confirmRecall 同口径）
Future<bool> recallAdventureConfirmed(
  BuildContext context,
  String adventureId,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('召回宠物'),
      content: const Text(
          '宠物将立即结束本次历险返回家中，本次历险不会获得任何奖励。确定召回吗？'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再等等')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定召回')),
      ],
    ),
  );
  if (ok != true) return false;
  final err = await PetRpc.adventureRecall(adventureId);
  if (!context.mounted) return false;
  if (err != null) {
    _toast(context, petRpcErrorText(err));
    return false;
  }
  _toast(context, '已召回，宠物平安回家（本次历险无奖励）');
  return true;
}

/// 遇险惩罚提示弹窗（claim roll 中 danger：宠物转入待救援，奖励不发）
Future<void> showPetDangerDialog(BuildContext context, {String? deadline}) {
  final at = DateTime.tryParse(deadline ?? '')?.toLocal();
  final mins = at?.difference(DateTime.now()).inMinutes ?? 0;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFE05B4C)),
        SizedBox(width: 8),
        Text('糟糕，遇险了！'),
      ]),
      content: Text(mins > 0
          ? '宠物在历险中遇到危险，需在 $mins 分钟内完成救助，否则将受到惩罚。'
          : '宠物在历险中遇到危险，请尽快完成救助。'),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
      ],
    ),
  );
}

/// 主页右列历险钮四态：无历险→历险入口；归来待领取→领取；待救助→救助；进行中→召回
Widget petAdventureRailButton({
  required PetAdventureBriefModel? adv,
  required VoidCallback openAdventure,
  required VoidCallback claimResult,
  required VoidCallback recall,
}) {
  final finished = adv?.endAt != null && !DateTime.now().isBefore(adv!.endAt!);
  final (icon, label, action) = adv == null
      ? (Icons.explore_outlined, '历险', openAdventure)
      : finished
          ? (Icons.redeem_outlined, '领取', claimResult)
          : adv.status == 'awaiting_rescue'
              ? (Icons.healing_outlined, '救助', openAdventure)
              : (Icons.u_turn_left, '召回', recall);
  return PetEdgeButton(icon: icon, label: label, onTap: action);
}
