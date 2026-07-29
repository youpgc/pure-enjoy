part of 'avatar_preset_page.dart';

/// 单条 HSV 滑动条（色相/饱和度/明度）：拖动实时预览，松手提交（原 [_AvatarPresetPageState._colorSlider]）
Widget _presetColorSlider({
  required String label,
  required Color activeColor,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
  required VoidCallback onEnd,
  String? unit,
}) {
  return Row(
    children: [
      SizedBox(
        width: 40,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          activeColor: activeColor,
          label: unit != null ? '${value.round()}$unit' : '${value.round()}',
          onChanged: onChanged,
          onChangeEnd: (_) => onEnd(),
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          unit != null ? '${value.round()}$unit' : '${value.round()}',
          textAlign: TextAlign.end,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    ],
  );
}

/// 风格选择（ChoiceChip 列表）（原 [_AvatarPresetPageState._buildStyleSection]）
class _AvatarPresetStyleSection extends StatelessWidget {
  final AvatarStyleOption style;
  final ColorScheme colorScheme;
  final ValueChanged<AvatarStyleOption> onPickStyle;
  const _AvatarPresetStyleSection({
    required this.style,
    required this.colorScheme,
    required this.onPickStyle,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '风格',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in kAvatarStyles)
                  ChoiceChip(
                    label: Text(opt.label),
                    selected: opt == style,
                    showCheckmark: false,
                    onSelected: (_) => onPickStyle(opt),
                  ),
              ],
            ),
          ],
        ),
      );
}

/// 主色调色板（原 [_AvatarPresetPageState._buildToneSection] 内的色板部分 + [_toneSwatch]）
class _AvatarPresetToneSwatches extends StatelessWidget {
  final bool presetActive;
  final String? activePresetHex;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onSelectTone;
  const _AvatarPresetToneSwatches({
    required this.presetActive,
    required this.activePresetHex,
    required this.colorScheme,
    required this.onSelectTone,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主色调',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _toneSwatch(null, '无'),
                for (final hex in kAvatarBgPresets) _toneSwatch(hex, null),
              ],
            ),
          ],
        ),
      );

  /// 主色调色板小圆点（[hex] 为 null 表示透明「无」）
  Widget _toneSwatch(String? hex, String? label) {
    // 选中判定基于「是否来自预设色板」而非重算后的 _backgroundColor
    // （点选色板时 hex 经 HSV 固定 S/V 重算，直接比对 hex 会失效）
    final selected = presetActive && (hex == activePresetHex);
    final Widget child;
    if (hex == null) {
      child = Icon(
        Icons.block,
        size: 16,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      );
    } else {
      child = const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => onSelectTone(hex),
      child: Tooltip(
        message: label ?? '#$hex',
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hex != null ? avatarHexToColor(hex) : colorScheme.surface,
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.grey.shade300,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 自定义色调滑动条（原 [_AvatarPresetPageState._buildToneSection] 内的滑块部分）
/// 拖动时通过 [onHueChanged] 上抛并触发实时预览（松手生效由父 State 处理）。
class _AvatarPresetToneSlider extends StatelessWidget {
  final double h;
  final ColorScheme colorScheme;
  final ValueChanged<double> onHueChanged;
  final VoidCallback onRgbEnd;
  const _AvatarPresetToneSlider({
    required this.h,
    required this.colorScheme,
    required this.onHueChanged,
    required this.onRgbEnd,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '自定义色调',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                Text(
                  '拖动实时预览，松手生效',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _presetColorSlider(
                label: '色调',
                activeColor: HSVColor.fromAHSV(1.0, h, 1, 1).toColor(),
                value: h,
                min: 0,
                max: 360,
                unit: '°',
                onChanged: onHueChanged,
                onEnd: onRgbEnd,
              ),
            ),
          ],
        ),
      );
}

/// 实时预览色块（当前背景色调）+ 换一批按钮（原 [_AvatarPresetPageState._buildPreviewRow]）
class _AvatarPresetPreviewRow extends StatelessWidget {
  final String? backgroundColor;
  final Color currentColor;
  final String currentHex;
  final ColorScheme colorScheme;
  final VoidCallback onShuffle;
  const _AvatarPresetPreviewRow({
    required this.backgroundColor,
    required this.currentColor,
    required this.currentHex,
    required this.colorScheme,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = backgroundColor != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasBg ? currentColor : colorScheme.surface,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: hasBg
                ? null
                : Icon(Icons.block, size: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Text(
            hasBg ? '#$currentHex' : '无背景',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onShuffle,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('换一批'),
          ),
        ],
      ),
    );
  }
}

/// 主色调色板 + 自定义色调滑动条 + 实时预览（组合子模块）（原 [_AvatarPresetPageState._buildToneSection]）
class _AvatarPresetToneSection extends StatelessWidget {
  final bool presetActive;
  final String? activePresetHex;
  final double h;
  final String? backgroundColor;
  final Color currentColor;
  final String currentHex;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onSelectTone;
  final ValueChanged<double> onHueChanged;
  final VoidCallback onRgbEnd;
  final VoidCallback onShuffle;
  const _AvatarPresetToneSection({
    required this.presetActive,
    required this.activePresetHex,
    required this.h,
    required this.backgroundColor,
    required this.currentColor,
    required this.currentHex,
    required this.colorScheme,
    required this.onSelectTone,
    required this.onHueChanged,
    required this.onRgbEnd,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarPresetToneSwatches(
            presetActive: presetActive,
            activePresetHex: activePresetHex,
            colorScheme: colorScheme,
            onSelectTone: onSelectTone,
          ),
          const SizedBox(height: 20),
          _AvatarPresetToneSlider(
            h: h,
            colorScheme: colorScheme,
            onHueChanged: onHueChanged,
            onRgbEnd: onRgbEnd,
          ),
          _AvatarPresetPreviewRow(
            backgroundColor: backgroundColor,
            currentColor: currentColor,
            currentHex: currentHex,
            colorScheme: colorScheme,
            onShuffle: onShuffle,
          ),
        ],
      );
}
