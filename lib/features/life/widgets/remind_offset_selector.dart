import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/remind_offset.dart';

/// 提醒设置选择器：提醒总开关 + 提前时间列表勾选（每项标注真实触发时间）+ 自定义提前天数。
///
/// 交互规则：
/// - 预设档位以列表勾选（Checkbox）形式展示，可多选；
/// - 「自定义提前天数」与预设列表互斥：启用自定义会清空预设勾选，勾选预设会关闭自定义。
///
/// [baseTime] 目标触发基准时刻（纪念日=日期@当天时刻，待办=remindAt），用于计算各档真实时间并展示。
/// 注意：标签时间按墙钟原样展示，调用方须传入**北京墙钟**口径
/// （待办用 DateTimeUtils.toBeijingWallClock(remindAt)；纪念日的日期+时刻本身即北京墙钟意图）。
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
  final List<RemindOffset> _selectedPresets = [];
  bool _customEnabled = false;
  int? _customDays;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    // 拆分初始值：预设档位进入勾选列表；非预设的「提前N天」视为自定义（互斥，仅取第一个）
    for (final offset in widget.initialOffsets) {
      if (RemindOffset.presets.contains(offset)) {
        _selectedPresets.add(offset);
      } else if (offset.unit == 'day' && _customDays == null) {
        _customDays = offset.value;
      }
    }
    if (_customDays != null) {
      // 互斥：存在自定义值时以自定义为准，清空预设勾选
      _customEnabled = true;
      _selectedPresets.clear();
      _customController.text = '$_customDays';
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  /// 汇总当前设置并回调（自定义与预设互斥，只输出其一）
  void _emit() {
    final List<RemindOffset> offsets;
    if (_customEnabled) {
      offsets = (_customDays != null && _customDays! > 0)
          ? [RemindOffset('day', _customDays!)]
          : <RemindOffset>[];
    } else {
      offsets = List<RemindOffset>.from(_selectedPresets);
    }
    widget.onChanged(RemindSettings(enabled: _enabled, offsets: offsets));
  }

  /// 标签时间按墙钟原样展示（调用方需传入北京墙钟口径的 baseTime）
  String _format(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$m-$d $hh:$mm';
  }

  void _togglePreset(RemindOffset offset, bool selected) {
    setState(() {
      if (selected) {
        // 互斥：勾选预设档时关闭自定义
        _customEnabled = false;
        if (!_selectedPresets.contains(offset)) _selectedPresets.add(offset);
      } else {
        _selectedPresets.remove(offset);
      }
    });
    _emit();
  }

  void _toggleCustom(bool selected) {
    setState(() {
      _customEnabled = selected;
      // 互斥：启用自定义时清空预设勾选
      if (selected) _selectedPresets.clear();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final hintStyle = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.outline,
    );
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
          const SizedBox(height: 4),
          const Text('提前提醒时间（可多选，与自定义互斥）',
              style: TextStyle(fontSize: 12)),
          // 预设档位列表勾选
          ...RemindOffset.presets.map((offset) {
            final resolved = offset.resolve(widget.baseTime);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(offset.unitLabel),
              secondary: Text(_format(resolved), style: hintStyle),
              value: _selectedPresets.contains(offset),
              onChanged: (v) => _togglePreset(offset, v ?? false),
            );
          }),
          // 自定义提前天数（与预设互斥）
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('自定义提前天数'),
            secondary: (_customEnabled && _customDays != null && _customDays! > 0)
                ? Text(
                    _format(
                      RemindOffset('day', _customDays!)
                          .resolve(widget.baseTime),
                    ),
                    style: hintStyle,
                  )
                : null,
            value: _customEnabled,
            onChanged: (v) => _toggleCustom(v ?? false),
          ),
          if (_customEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 8),
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '提前天数',
                  hintText: '如 2',
                  suffixText: '天',
                  isDense: true,
                ),
                onChanged: (text) {
                  setState(() => _customDays = int.tryParse(text));
                  _emit();
                },
              ),
            ),
        ],
      ],
    );
  }
}
