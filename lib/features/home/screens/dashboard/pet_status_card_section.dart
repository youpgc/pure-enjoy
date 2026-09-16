import 'package:flutter/material.dart';

import '../../../pets/models/pet_models.dart';
import '../../../pets/screens/pet_home_screen.dart';
import '../../../pets/services/pet_service.dart';

/// 首页「宠物状态卡」常驻区块（宠物系统主入口）
///
/// 门控策略（pet_enabled 关闭时入口隐藏）：
/// - 未登录 / 总开关关闭 / 总览拉取失败 → 不渲染任何内容（零占位）；
/// - 有宠物 → 头像 + 名字/等级 + 饱食/心情 + 金币余额，点击进入宠物主页；
/// - 无宠物 → 领养引导（初始蛋按 pet_config 配置在首次进入时幂等发放）。
///
/// 数据走 PetService SWR：缓存秒开 + 静默刷新；从宠物主页返回后 force 刷新。
class PetStatusCardSection extends StatefulWidget {
  const PetStatusCardSection({super.key});

  @override
  State<PetStatusCardSection> createState() => _PetStatusCardSectionState();
}

class _PetStatusCardSectionState extends State<PetStatusCardSection> {
  bool _loading = true;
  PetSummaryModel? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 拉取总览并刷新状态卡（force=跳过缓存）
  Future<void> _load({bool force = false}) async {
    final summary = await PetService.instance.fetchSummary(forceRefresh: force);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  void _openPetHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetHomeScreen()),
    ).then((_) => _load(force: true));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 加载中 / 功能关闭 / 拉取失败：不渲染（门控隐藏，不留占位）
    if (_loading || _summary == null) return const SizedBox.shrink();

    final summary = _summary!;
    final pet = summary.primaryPet;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: _openPetHome,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    pet == null ? Icons.pets_outlined : Icons.pets,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pet != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pet.name} · Lv.${pet.level}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '饱食 ${pet.hunger} · 心情 ${pet.mood}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '还没有宠物',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '点击领取你的第一只萌宠',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                // 金币余额徽标（pet_wallets.gold_balance）
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.paid_outlined,
                          size: 14, color: colorScheme.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.wallet.goldBalance}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
