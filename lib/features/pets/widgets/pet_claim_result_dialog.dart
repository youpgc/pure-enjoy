import 'package:flutter/material.dart';

/// 历险结算弹窗（2026-09-17 历险闭环缺陷修复）
///
/// 展示 claim 四类结果演出 + 金币/经验 + 掉落明细（items 由
/// fix_pet_adventure_claim_items SQL 返回：[{code, name, qty}]），
/// 关闭后由调用方刷新总览。独立成文件以保证历险页行数在 500 以内。

class PetClaimResultDialog extends StatelessWidget {
  const PetClaimResultDialog({
    super.key,
    required this.result,
    required this.gold,
    required this.exp,
    required this.items,
  });

  final String result;
  final int gold;
  final int exp;
  final List<({String name, int qty})> items;

  (IconData, String, Color) get _scene => switch (result) {
        'play' => (Icons.toys_outlined, '玩得开心', const Color(0xFFE58BB4)),
        'help' => (Icons.volunteer_activism_outlined, '帮到了别人', const Color(0xFF7FB77E)),
        'memory' => (Icons.auto_stories_outlined, '收获满满回忆', const Color(0xFF8B9FD1)),
        _ => (Icons.emoji_events_outlined, '平安归来', const Color(0xFFE0A458)),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, text, color) = _scene;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 10),
            const Text('平安归来！',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('这一趟$text',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _rewardChip(
                    Icons.paid_outlined, '金币 +$gold', const Color(0xFFF0A020)),
                const SizedBox(width: 10),
                _rewardChip(
                    Icons.stars_outlined, '经验 +$exp', const Color(0xFF5B8DEF)),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('背包收获',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
              ),
              const SizedBox(height: 6),
              ...items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 15, color: Color(0xFFB08968)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(it.name,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text('×${it.qty}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('收下啦'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}
