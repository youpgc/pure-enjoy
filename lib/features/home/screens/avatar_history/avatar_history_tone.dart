part of './avatar_history_page.dart';

/// 单条 HSV 滑动条（与预设页一致），纯展示、所有参数显式传入。
Widget _avatarHistoryColorSlider({
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

/// 主色调色板（原 [_AvatarHistoryViewState._buildToneSwatches] + [_toneSwatch]）
class _AvatarHistoryToneSwatches extends StatelessWidget {
  final bool presetActive;
  final String? activePresetHex;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onSelectTone;
  const _AvatarHistoryToneSwatches({
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

  Widget _toneSwatch(String? hex, String? label) {
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

/// 自定义色调滑动条（原 [_AvatarHistoryViewState._buildToneSliderRow]）
/// 拖动时通过 [onHueChanged] 上抛并触发实时预览（松手生效由父 State 处理）。
class _AvatarHistoryToneSlider extends StatelessWidget {
  final double h;
  final ColorScheme colorScheme;
  final ValueChanged<double> onHueChanged;
  final VoidCallback onRgbEnd;
  const _AvatarHistoryToneSlider({
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
            _avatarHistoryColorSlider(
              label: '色调',
              activeColor: HSVColor.fromAHSV(1.0, h, 1, 1).toColor(),
              value: h,
              min: 0,
              max: 360,
              unit: '°',
              onChanged: onHueChanged,
              onEnd: onRgbEnd,
            ),
          ],
        ),
      );
}

/// 最终效果预览（原 [_AvatarHistoryViewState._buildFinalPreview]）
class _AvatarHistoryFinalPreview extends StatelessWidget {
  final String? backgroundColor;
  final Color currentColor;
  final String? selectedUrl;
  final ColorScheme colorScheme;
  const _AvatarHistoryFinalPreview({
    required this.backgroundColor,
    required this.currentColor,
    required this.selectedUrl,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = backgroundColor != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          selectedUrl == null
              ? Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : cachedAvatarCircle(
                  url: selectedUrl!,
                  radius: 48,
                  tint: hasBg ? currentColor : colorScheme.primaryContainer,
                  colorScheme: colorScheme,
                ),
          const SizedBox(height: 8),
          Text(
            '最终效果',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// 预览色块（当前背景色调）+ 保存按钮（原 [_AvatarHistoryViewState._buildTonePreviewRow]）
class _AvatarHistoryTonePreviewRow extends StatelessWidget {
  final String? backgroundColor;
  final Color currentColor;
  final String currentHex;
  final bool manageMode;
  final String? selectedUrl;
  final ColorScheme colorScheme;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  const _AvatarHistoryTonePreviewRow({
    required this.backgroundColor,
    required this.currentColor,
    required this.currentHex,
    required this.manageMode,
    required this.selectedUrl,
    required this.colorScheme,
    required this.onConfirm,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = backgroundColor != null;
    final bgSwatch = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBg ? currentColor : colorScheme.surface,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: hasBg
          ? null
          : Center(
              child: Icon(
                Icons.block,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          bgSwatch,
          const SizedBox(width: 12),
          Text(
            hasBg ? '#$currentHex' : '无背景',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (!manageMode)
            TextButton(
              // 合并「确认 + 保存修改」：回传当前预览（含色调）由编辑页套用为当前头像并写入历史
              onPressed: onConfirm,
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
  }
}

/// 上传头像：仅预览当前选中头像（无色调编辑）（原 [_AvatarHistoryViewState._buildUploadPreviewRow]）
class _AvatarHistoryUploadPreview extends StatelessWidget {
  final String? selectedUrl;
  final bool manageMode;
  final ColorScheme colorScheme;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  const _AvatarHistoryUploadPreview({
    required this.selectedUrl,
    required this.manageMode,
    required this.colorScheme,
    required this.onConfirm,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final preview = selectedUrl == null
        ? Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(
              Icons.person,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        : SizedBox(
            width: 40,
            height: 40,
            child: cachedAvatarCircle(
              url: selectedUrl!,
              radius: 20,
              tint: colorScheme.primaryContainer,
              colorScheme: colorScheme,
            ),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          preview,
          const SizedBox(width: 12),
          Text(
            '当前预览',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (!manageMode)
            TextButton(
              // 回传当前选中的上传头像，由编辑页套用为当前头像并写入历史
              onPressed: onConfirm,
              child: Text(confirmLabel),
            ),
        ],
      ),
    );
  }
}
