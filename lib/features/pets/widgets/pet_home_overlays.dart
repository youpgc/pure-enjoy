import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_models.dart';
import '../models/pet_rpc_models.dart';

/// 宠物主页浮层展示组件（2026-09-17 满屏舞台版拆分）
///
/// 纯展示层：数据与回调由 pet_home_screen 传入，本文件不持有业务状态。
/// 包含顶部提示信息（名牌/四维状态/历险横幅/孵化引导）、左右边缘浮动按钮、
/// 左上角返回键（金币胶囊已移至场景层 PetGoldBadge 右上角）、
/// 多宠切换箭头、加载失败视图与诞生弹窗。

/// 宠物名牌胶囊（名字 / 等级 / 编号 / 形态）
class PetNamePill extends StatelessWidget {
  const PetNamePill({super.key, required this.pet});

  final PetBriefModel pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${pet.name} · Lv.${pet.level} · ${pet.showNo} · 形态${pet.stage}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 四维状态卡（饱食/心情/亲密/经验，2×2 紧凑排布）
class PetStatusCard extends StatelessWidget {
  const PetStatusCard({super.key, required this.pet});

  final PetBriefModel pet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: _miniStat('饱食', pet.hunger, cs)),
              const SizedBox(width: 14),
              Expanded(child: _miniStat('心情', pet.mood, cs)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _miniStat('亲密', pet.intimacy, cs)),
              const SizedBox(width: 14),
              Expanded(child: _miniStat('经验', pet.exp, cs)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, ColorScheme cs) => Row(
        children: [
          SizedBox(
              width: 30, child: Text(label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.end, style: const TextStyle(fontSize: 11)),
          ),
        ],
      );
}

/// 历险横幅（进行中 / 待救助 / 已结束待领取）
class PetAdventureBanner extends StatelessWidget {
  const PetAdventureBanner({super.key, required this.adv, this.onTap});

  final PetAdventureBriefModel adv;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final finished = adv.endAt == null || !DateTime.now().isBefore(adv.endAt!);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: finished ? cs.primaryContainer : cs.surfaceContainerHighest,
        child: ListTile(
          dense: true,
          leading: Icon(finished ? Icons.redeem_outlined : Icons.explore_outlined,
              color: cs.primary),
          title: Text(
            finished
                ? '历险已结束，点击查看结果'
                : '历险进行中 · ${adv.status == PetAdventureStatus.awaitingRescue ? '待救助' : '归来倒计时'}',
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: adv.status == PetAdventureStatus.awaitingRescue
              ? const Text('需要你的救援！', style: TextStyle(fontSize: 11))
              : null,
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// 边缘浮动操作钮（2026-09-17 改版：文案内置——图标在上、文案在下方按钮内；
/// [overlay] 非空时整钮覆盖黑色透明蒙层，白色字体居中显示冷却倒计时/已达上限）
///
/// [onTap] 传 null 时整钮置灰（无交互）。
class PetEdgeButton extends StatelessWidget {
  const PetEdgeButton({
    super.key,
    required this.icon,
    required this.label,
    this.overlay,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// 蒙层文案：冷却倒计时（如「2分30秒」）/「已达上限」；null 表示正常态
  final String? overlay;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final contentColor = enabled ? cs.onPrimaryContainer : cs.outline;
    return Material(
      color: enabled ? cs.primaryContainer : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: contentColor),
                    const SizedBox(height: 3),
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: contentColor)),
                  ],
                ),
              ),
              if (overlay != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      overlay!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 无宠物孵化引导卡（首蛋就绪时展示立即孵化）
class PetHatchGuide extends StatelessWidget {
  const PetHatchGuide({
    super.key,
    required this.hasEgg,
    this.busy = false,
    this.onHatch,
  });

  final bool hasEgg;
  final bool busy;
  final VoidCallback? onHatch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.egg_outlined, size: 40, color: cs.primary),
            const SizedBox(height: 6),
            Text(hasEgg ? '你的第一颗蛋已经就绪' : '还没有宠物'),
            const SizedBox(height: 4),
            Text(
              hasEgg ? '点击下方按钮，立即见证新伙伴的诞生' : '初始蛋将在背包中发放，稍后回来试试',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (hasEgg) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onHatch,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('立即孵化'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 总览拉取失败视图（错误详情 + 重试）
class PetLoadErrorView extends StatelessWidget {
  const PetLoadErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('宠物数据加载失败，请稍后重试'),
          if (message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: cs.error)),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 左上角浮动返回键（金币已独立为 PetGoldBadge，置于右上角场景层）
///
/// 2026-09-17：有宠物时按钮列贴顶，返回键核心 [PetBackButtonCore] 内联至左列
/// 首位避免重叠；本外壳仅无宠物分支使用。
class PetBackButton extends StatelessWidget {
  const PetBackButton({super.key, required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: Padding(
        padding:
            EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 2, left: 4),
        child: PetBackButtonCore(onBack: onBack),
      ),
    );
  }
}

/// 返回键核心（白底圆形 38px，可内联进按钮列）
class PetBackButtonCore extends StatelessWidget {
  const PetBackButtonCore({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onBack,
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
    );
  }
}

/// 多宠切换箭头（filledTonal 圆钮，置于舞台两侧）
class PetSwitchArrow extends StatelessWidget {
  const PetSwitchArrow({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon),
      tooltip: '切换宠物',
      style: IconButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      ),
    );
  }
}

/// 新宠物诞生弹窗：基础型形象大图 + 名字/编号/稀有度/性别
///
/// 图片权重——优先展示帧序列首帧，未登记帧序列的种属由调用方回退静态立绘。
Future<void> showPetBirthDialog(
  BuildContext context, {
  required String? img,
  required PetHatchResultModel result,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(img, height: 210, fit: BoxFit.contain),
              ),
            const SizedBox(height: 12),
            Text('🎉 新伙伴诞生！', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${result.name} · ${result.showNo}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
                '稀有度 ${result.rarity} · ${_genderGlyph(result.gender?.code)}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('太好了'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _genderGlyph(String? code) => switch (code) {
      'male' => '♂',
      'female' => '♀',
      _ => '·',
    };

/// 历险中提示行（宠物保留舞台原位时展示去向文案，白底 pill 适配场景草地）
class PetAdventureNote extends StatelessWidget {
  const PetAdventureNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
          '🐾 外出历险中，归来后记得查看结果领取奖励',
          style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade700,
              fontWeight: FontWeight.w500)));
}
