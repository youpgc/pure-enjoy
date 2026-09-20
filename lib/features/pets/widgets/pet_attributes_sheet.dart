import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../models/pet_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';

/// 属性面板（2026-09-17 属性系统 Phase 2）
///
/// - 展示：四维成长属性（智力/体力/力量/敏捷）+ 健康状态值 + 性格；
///   潜力为隐藏属性（服务端不下发），永不展示；
/// - 加点：升级获得的可分配点 [PetBriefModel.pendingAttrPoints] 以步进器
///   累积，确认后逐维度调用 rpc_pet_allocate_attr（服务端校验余额/白名单）；
/// - 洗练：背包 tool_refine 道具入口触发 rpc_pet_refine_reassign，
///   结果经 [showPetRefineResultDialog] 做前后对比演出。
///   孵化基础属性不可洗练（仅重掷升级加点，总值守恒）。

/// 打开属性面板；[onChanged] 在加点成功后回调（调用方刷新总览）
Future<void> showPetAttributesSheet(
  BuildContext context, {
  required PetBriefModel pet,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PetAttributesSheet(pet: pet, onChanged: onChanged),
  );
}

class _PetAttributesSheet extends StatefulWidget {
  const _PetAttributesSheet({required this.pet, this.onChanged});

  final PetBriefModel pet;
  final VoidCallback? onChanged;

  @override
  State<_PetAttributesSheet> createState() => _PetAttributesSheetState();
}

class _PetAttributesSheetState extends State<_PetAttributesSheet> {
  /// 本次分配累积（维度 → 点数；确认前只在本地累积）
  final Map<String, int> _alloc = {};
  bool _busy = false;

  int get _total => _alloc.values.fold(0, (a, b) => a + b);

  int get _remain =>
      (widget.pet.pendingAttrPoints - _total).clamp(0, widget.pet.pendingAttrPoints);

  void _bump(PetAttrKey key, int delta) {
    final cur = _alloc[key.code] ?? 0;
    final next = (cur + delta).clamp(0, _remain + cur);
    setState(() =>
        next == 0 ? _alloc.remove(key.code) : _alloc[key.code] = next);
  }

  Future<void> _confirm() async {
    if (_total <= 0 || _busy) return;
    setState(() => _busy = true);
    String? firstErr;
    for (final e in _alloc.entries) {
      if (e.value <= 0) continue;
      // 服务端按维度逐次扣减 pending_attr_points；出错即中断（余额强一致）
      final err = await PetRpc.allocateAttr(
        widget.pet.id,
        attrKey: e.key,
        points: e.value,
      );
      if (err != null) {
        firstErr = err;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (firstErr != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(petRpcErrorText(firstErr))));
      return;
    }
    Navigator.pop(context);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pet = widget.pet;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题行：名字 + 性格
            Row(
              children: [
                Expanded(
                  child: Text('${pet.name} · Lv.${pet.level}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pet.personalityName ?? '性格待观察',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onTertiaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 可分配点提示
            Text(
              pet.pendingAttrPoints > 0
                  ? '升级获得了属性点，快为它加点吧（剩余 $_remain/${pet.pendingAttrPoints}）'
                  : '宠物升级时会获得属性点',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            // 四维属性行（加点时每行右侧出现步进器）
            for (final k in PetAttrKey.values) ...[
              _attrRow(k, cs),
              const SizedBox(height: 8),
            ],
            _healthRow(cs),
            const SizedBox(height: 10),
            Text(
              pet.refinePoints > 0
                  ? '洗练点 ${pet.refinePoints} · 使用洗练剂可重新分配升级获得的加点'
                  : '使用洗练剂可重新分配升级获得的加点（基础属性不受影响）',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _total > 0 && !_busy ? _confirm : null,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_total > 0 ? '分配 $_total 点' : '暂无可分配点数'),
            ),
          ],
        ),
      ),
    );
  }

  /// 单维属性行：标签 + 当前值（含本次分配预览）+ 步进器
  Widget _attrRow(PetAttrKey key, ColorScheme cs) {
    final pet = widget.pet;
    final base = pet.attr(key.code);
    final plus = _alloc[key.code] ?? 0;
    final canAlloc = pet.pendingAttrPoints > 0;
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
              value: ((base + plus) / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          plus > 0 ? '$base +$plus' : '$base',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: plus > 0 ? cs.primary : null,
          ),
        ),
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

  /// 健康行（状态值只读：历险失败惩罚扣减，恢复途径后续配置）
  Widget _healthRow(ColorScheme cs) {
    final health = widget.pet.health;
    final color = health > 60
        ? const Color(0xFF7FB77E)
        : health > 30
            ? const Color(0xFFE0A458)
            : Theme.of(context).colorScheme.error;
    return Row(
      children: [
        const SizedBox(
            width: 56,
            child: Text('健康',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (health / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$health',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 66), // 与四维步进器区域等宽对齐
      ],
    );
  }
}

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
