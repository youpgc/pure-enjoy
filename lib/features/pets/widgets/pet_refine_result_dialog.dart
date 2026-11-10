part of 'pet_attributes_sheet.dart';

/// 洗练结果演出 + 属性行渲染段。

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 下分析器对跨文件隐式调用的私有成员引用计数有漏计
// （unused_element 误报）；extension 语境调 setState 属运行时安全，均为工具链误报。

/// 洗练结果演出：升级加点重掷前后逐维对比（总值守恒；基础属性不变）
Future<void> showPetRefineResultDialog(
  BuildContext context, {
  required Map<String, dynamic> before,
  required Map<String, dynamic> after,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.tertiary.withValues(alpha: 0.16)),
                child: Icon(Icons.auto_fix_high, size: 32, color: cs.tertiary),
              ),
              const SizedBox(height: 10),
              const Text('洗练完成！',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('加点属性已重新分配，总值不变',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              for (final k in PetAttrKey.values)
                _refineRow(ctx, k, before, after),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('收下啦'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _refineRow(BuildContext ctx, PetAttrKey key,
    Map<String, dynamic> before, Map<String, dynamic> after) {
  final oldV = (before[key.code] as num?)?.toInt() ?? 0;
  final newV = (after[key.code] as num?)?.toInt() ?? 0;
  final diff = newV - oldV;
  final color = diff > 0
      ? const Color(0xFF7FB77E)
      : diff < 0
          ? const Color(0xFFE58B6B)
          : Colors.grey;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
            width: 52,
            child: Text(key.label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Text('$oldV → $newV',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text(
          diff > 0 ? '+$diff' : '$diff',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

extension _PetAttrRowViews on _PetAttributesSheetState {
  Widget _attrRow(PetAttrKey key, ColorScheme cs) {
    final pet = widget.pet;
    final base = pet.attr(key.code);
    final plus = _alloc[key.code] ?? 0;
    // 仅养育中可加点（服务端 allocate 拦 PET_NOT_REARING，四态中三态全拒；
    // breeding/fostered 状态可点必收拒）
    final canAlloc =
        pet.pendingAttrPoints > 0 && pet.status == PetPetStatus.rearing;
    return Row(
      children: [
        SizedBox(
            width: 56,
            child: Text(key.label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // 四维属性为 0~100 结构值，100=结构满值（非业务配置）
              value: ((base + plus) / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 52,
            child: Text(
              plus > 0 ? '$base +$plus' : '$base',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: plus > 0 ? cs.primary : null,
              ),
            )),
        // 步进器（仅有点数时出现）
        if (canAlloc) ...[
          const SizedBox(width: 10),
          _stepBtn(Icons.remove, plus > 0 ? () => _bump(key, -1) : null, cs),
          const SizedBox(width: 6),
          _stepBtn(Icons.add, _remain > 0 ? () => _bump(key, 1) : null, cs),
        ],
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? cs.onPrimaryContainer : cs.outline),
      ),
    );
  }

  /// 亲密度行（等级制）
  /// 进度条结构与四维属性行同构（同宽/同高/同底色）;数值格=累计亲密度
  /// 副行=「亲密等级 Lv.X · 级内进度」。
  /// 等级曲线 base/growth 读 config（缺键/非法回退累计值平铺，不造默认值）。
  /// 进度条 = 级内进度百分比（intoLevel/need
  ///  100 满——累计值超 100 后旧口径恒满格，看不出级内成长）。
  Widget _intimacyRow(ColorScheme cs) {
    final lv = petIntimacyLevel(widget.pet.intimacy, widget.config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
                width: 56,
                child: Text('亲密',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: lv == null
                      ? 0.0
                      : lv.need <= 0
                          ? 0.0
                          : (lv.intoLevel / lv.need).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 数值格 = 已获取亲密度总数;宽度 52 与四维数值格一致(槽位对齐)
            SizedBox(
                width: 52,
                child: Text('${widget.pet.intimacy}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            lv == null
                ? '亲密等级 —'
                : '亲密等级 Lv.${lv.level} · ${lv.intoLevel}/${lv.need}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
