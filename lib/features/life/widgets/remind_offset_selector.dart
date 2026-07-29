import 'package:flutter/material.dart';

import '../models/remind_offset.dart';

/// 提醒设置选择器：提醒总开关 + 多选提前时间（每项标注真实 hh:mm）+ 自定义提前天数。
///
/// [baseTime] 目标触发基准时刻（纪念日=日期@当天时刻，待办=remindAt），用于计算各档真实时间并展示。
/// 通过 [onChanged] 输出 [RemindSettings]，由调用方写入数据模型。
class RemindOffsetSelector extends StatefulWidget {
  final DateTime baseTime;
  final bool initialEnabled;
  final List<RemindOffset> initialOffsets;
  final ValueChanged<RemindSettings> onChanged;

  const RemindOffsetSelector({
    super.key,
    required this.baseTime,
    required this.initialEnabled,
    required this.initialOffsets,
    required this.onChanged,
  });

  @override
  State<RemindOffsetSelector> createState() => _RemindOffsetSelectorState();
}

class _RemindOffsetSelectorState extends State<RemindOffsetSelector> {
  late bool _enabled;
  late List<RemindOffset> _selected;
  final List<RemindOffset> _customOffsets = [];
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _selected = List.from(widget.initialOffsets);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      RemindSettings(enabled: _enabled, offsets: List.from(_selected)),
    );
  }

  String _format(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$m-$d $hh:$mm';
  }

  void _toggle(RemindOffset offset, bool selected) {
    setState(() {
      if (selected) {
        if (!_selected.contains(offset)) _selected.add(offset);
      } else {
        _selected.remove(offset);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final all = {...RemindOffset.presets, ..._customOffsets}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('提醒开关'),
          subtitle:
              Text(_enabled ? '开启后将在设定时间弹出横幅' : '关闭后不会触发横幅提醒'),
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            _emit();
          },
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          const Text('提前提醒时间（可多选）', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: all.map((offset) {
              final resolved = offset.resolve(widget.baseTime);
              final label = '${offset.unitLabel} · ${_format(resolved)}';
              return FilterChip(
                label: Text(label),
                selected: _selected.contains(offset),
                onSelected: (s) => _toggle(offset, s),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '自定义提前天数',
                    hintText: '如 2',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  final n = int.tryParse(_customController.text);
                  if (n == null || n <= 0) return;
                  final offset = RemindOffset('day', n);
                  if (!_customOffsets.contains(offset)) {
                    setState(() => _customOffsets.add(offset));
                  }
                  if (!_selected.contains(offset)) {
                    _selected.add(offset);
                  }
                  _customController.clear();
                  _emit();
                },
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
