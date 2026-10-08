import 'package:flutter/material.dart';

import '../models/pet_event_models.dart';
import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';
import 'pet_item_icon.dart';

/// 随机事件弹层（需求 §3.6 轻量插叙事件）
///
/// 两段式：文案 + 选项 → 选择后换结算明细。奖惩包来自 roll 下发的公示数据
/// （§17#1 所见即所得），结算与服务端 choose 返回为准。
/// 返回 true = 完成了一次有效选择（调用方可据以刷新）。
Future<bool> showPetEventDialog(
  BuildContext context, {
  required PetEventModel event,
  required String petId,
}) async {
  final result = await showDialog<PetEventChooseResultModel>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PetEventDialog(event: event, petId: petId),
  );
  return result != null;
}

class _PetEventDialog extends StatefulWidget {
  const _PetEventDialog({required this.event, required this.petId});

  final PetEventModel event;
  final String petId;

  @override
  State<_PetEventDialog> createState() => _PetEventDialogState();
}

class _PetEventDialogState extends State<_PetEventDialog> {
  PetEventChooseResultModel? _result;
  String? _err;
  int _choosing = -1;

  Future<void> _choose(PetEventOptionModel opt) async {
    if (_choosing >= 0) return;
    setState(() => _choosing = opt.index);
    final (result, err) =
        await PetRpc.eventChoose(widget.event.id, opt.index, widget.petId);
    if (!mounted) return;
    if (err != null || result == null) {
      setState(() {
        _choosing = -1;
        _err = petRpcErrorText(err);
      });
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const PetItemIcon(
                    iconKey: 'ui_event',
                    fallback: Icons.auto_awesome_outlined,
                    size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.event.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _result == null ? widget.event.text : _resultText(),
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!,
                  style: TextStyle(fontSize: 12, color: cs.error)),
            ],
            const SizedBox(height: 16),
            if (_result == null)
              ...widget.event.options.map(_optionButton)
            else
              FilledButton(
                onPressed: () => Navigator.pop(context, _result),
                child: const Text('好的'),
              ),
          ],
        ),
      ),
    );
  }

  String _resultText() {
    final r = _result!;
    final lines = r.grantedLines;
    final head = lines.isEmpty ? '一切如常。' : lines.join('，');
    return '你选择了「${r.optionLabel}」。\n获得：$head';
  }

  Widget _optionButton(PetEventOptionModel opt) {
    final busy = _choosing == opt.index;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: _choosing >= 0 ? null : () => _choose(opt),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    Text(opt.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_rewardHint(opt.rewards),
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
      ),
    );
  }

  /// 公示奖惩的短文案（与结算字段同源；负数如实显示代价）
  String _rewardHint(Map<String, dynamic> rewards) {
    int? n(String k) => (rewards[k] as num?)?.toInt();
    final parts = <String>[];
    final gold = n('gold');
    if (gold != null && gold != 0) parts.add('金币${_sign(gold)}');
    final points = n('points');
    if (points != null && points != 0) parts.add('积分${_sign(points)}');
    final exp = n('exp');
    if (exp != null && exp != 0) parts.add('经验${_sign(exp)}');
    final mood = n('mood');
    if (mood != null && mood != 0) parts.add('心情${_sign(mood)}');
    final intimacy = n('intimacy');
    if (intimacy != null && intimacy != 0) parts.add('亲密${_sign(intimacy)}');
    final hunger = n('hunger');
    if (hunger != null && hunger != 0) parts.add('饱食${_sign(hunger)}');
    if (rewards['item_code'] != null) parts.add('道具');
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  String _sign(int v) => v > 0 ? '+$v' : '$v';
}
