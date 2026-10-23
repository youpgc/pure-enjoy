import 'package:flutter/material.dart';

import '../models/pet_rpc_models.dart';
import '../services/pet_rpc.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';
import 'pet_toast.dart';

/// 初始蛋种属选择卡（initial_ssr 自选种属，20261022 用户拍板）
///
/// 可选种属 = 池配置 initial_choices 的键集（后台配置哪些 SSR 可选，
/// 系别由其推导——后台只配了月萤则只有猫系可选）；同系多候选时由
/// 服务端随机取一只，客户端只负责选系。
///
/// 返回选中的系别 code（cat/dog/rabbit/mouse）；点遮罩/取消返回 null。
Future<String?> showPetInitialFamilyPicker(
  BuildContext context, {
  required Iterable<String> families,
}) {
  const labels = {
    'cat': '猫系',
    'dog': '犬系',
    'rabbit': '兔系',
    'mouse': '鼠系',
  };
  final cs = Theme.of(context).colorScheme;
  // 展示序固定 猫→犬→兔→鼠，未登记系别排末尾
  final order = ['cat', 'dog', 'rabbit', 'mouse'];
  final sorted = families.toList()
    ..sort((a, b) {
      final ia = order.indexOf(a), ib = order.indexOf(b);
      return (ia < 0 ? order.length : ia).compareTo(ib < 0 ? order.length : ib);
    });

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择初始伙伴种属',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                sorted.length > 1
                    ? '同一种属有多只初始 SSR 时，将随机获得其中一只'
                    : '获得所选种属的一只初始 SSR',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in sorted)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(ctx).pop(f),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                cs.primary,
                                cs.tertiary,
                              ]),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (labels[f] ?? f).characters.first,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(labels[f] ?? f,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 初始蛋孵化公共链路（三入口共用：背包/主页首蛋/孵蛋页）
///
/// 拉池公示配置 → 弹种属选择卡 → 带参孵化。返回孵化结果：
/// - 成功：result（调用方弹诞生弹窗与各自后置刷新）；
/// - 用户取消或孵化失败：null（失败已 toast）；
/// - 未开启自选（池无 initial_choices 配置）：按原路固定产出直接孵化，
///   成功返回结果、失败返回 null（已 toast）。
///
/// 仅在 egg 的 poolCode == 'initial_ssr' 时调用；其他蛋由调用方直孵。
Future<PetHatchResultModel?> hatchInitialEggWithChoice(
  BuildContext context, {
  required String eggId,
}) async {
  Map<String, List<String>> choices = {};
  final (pools, cfgErr) = await PetRpcP2.fetchPublishedEggOdds();
  if (cfgErr == null) {
    for (final p in pools) {
      if (p.poolCode == 'initial_ssr') {
        choices = p.initialChoices;
        break;
      }
    }
  }
  // 配置拉取失败按未开启自选处理：服务端 fixed_species 兜底,不打扰用户
  String? family;
  if (choices.isNotEmpty) {
    family = await showPetInitialFamilyPicker(context, families: choices.keys);
    if (family == null) return null; // 用户取消,不孵化
  }
  final (result, err) = await PetRpc.hatchEgg(eggId, family: family);
  if (err != null || result == null) {
    if (context.mounted) showPetToast(context, petRpcErrorText(err));
    return null;
  }
  return result;
}
