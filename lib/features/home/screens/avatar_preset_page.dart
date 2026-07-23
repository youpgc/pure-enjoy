import 'package:flutter/material.dart';
import '../avatar_presets.dart';
import '../avatar_render.dart';

/// 编辑资料 - 预设头像选择页面
/// 支持：风格自选（[kAvatarStyles]）、7 个主色调 + 单条「色调」滑动条自定义背景色、
/// 「换一批」（重新生成一批网络头像）；点选头像仅暂存，需点右上角「确认」才写入 avatar_url；
/// 重新打开时根据 [currentUrl] 回显风格 / 色调 / 头像。头像一律走网络 DiceBear URL
/// （背景色由服务端渲染），[cached_network_image] 负责磁盘缓存。
class AvatarPresetPage extends StatefulWidget {
  final String? currentUrl;

  const AvatarPresetPage({super.key, this.currentUrl});

  @override
  State<AvatarPresetPage> createState() => _AvatarPresetPageState();
}

class _AvatarPresetPageState extends State<AvatarPresetPage> {
  // 单条色相(H)滑动条：饱和/明度固定为柔和常量，避免多条滑块；
  // late 字段必须带初始化器，否则热重载(hot reload)时旧 State 实例不会重跑
  // initState，late 字段将保持未初始化而抛出 LateInitializationError。
  late AvatarStyleOption _style = kDefaultStyle;
  late double _h = hsvFromHex(kDefaultStyle.defaultBg ?? kDefaultBg).hue;
  String? _backgroundColor; // 当前背景色（hex 不含 #，null = 透明）
  String? _selectedSeed; // 当前选中头像的种子（点选后置入；切风格/换一批清空；调色调不清空）
  bool _presetActive = true; // 当前背景色是否来自预设色板（自定义色调时为 false）
  String? _activePresetHex; // 当前选中的预设色 hex（null = 无背景）；仅 _presetActive 时有效
  late int _batchSeed = randomBatchSeed(); // 「换一批」控制当前批次
  static const int _kGridCount = 24; // 网格头像数量（4 列 × 6 行）
  static const int _kPresetColumns = 4; // 网格列数

  @override
  void initState() {
    super.initState();
    final saved = widget.currentUrl;
    final parsed = _parseSaved(saved);
    if (parsed != null) {
      _style = parsed.style;
      _backgroundColor = parsed.bg;
      _h = hsvFromHex(parsed.bg ?? _style.defaultBg ?? kDefaultBg).hue;
      if (parsed.batchSeed != null && parsed.index != null) {
        // 当前头像由本面板生成（seed 遵守 ${style}_${batchSeed}_${index}）：
        // 复用其 batchSeed，使其天然落入 24 批次内（总数恒为 24，无需额外前置）。
        _batchSeed = parsed.batchSeed!;
        _selectedSeed = parsed.seed;
      } else {
        // 历史遗留 / 外部种子：重新生成批次，并把当前头像替换第 0 格（总数仍 24）。
        _batchSeed = randomBatchSeed();
        _selectedSeed = parsed.seed;
      }
      // 回显选中色板：无背景 / 命中预设色板 / 自定义
      if (parsed.bg == null) {
        _activePresetHex = null;
        _presetActive = true;
      } else {
        final match = _matchPresetHue();
        if (match != null) {
          _activePresetHex = match;
          _presetActive = true;
        } else {
          _activePresetHex = null;
          _presetActive = false;
        }
      }
    } else {
      _style = kDefaultStyle;
      _backgroundColor = _currentHex;
      _h = hsvFromHex(_style.defaultBg ?? kDefaultBg).hue;
      _batchSeed = randomBatchSeed();
      _selectedSeed = null;
      _activePresetHex = _matchPresetHue();
      _presetActive = _activePresetHex != null;
    }
  }

  /// 解析保存值（DiceBear URL 或早期 avt: 令牌），回显风格 / 背景色 / 批次 / 下标 / 种子。
  ({AvatarStyleOption style, String? bg, int? batchSeed, int? index, String seed})?
      _parseSaved(String? saved) {
    if (saved == null || saved.isEmpty) return null;
    // 早期本地令牌：先还原为真实 URL 再解析
    String url = saved;
    if (saved.startsWith('avt:')) {
      final t = tokenToUrl(saved);
      if (t == null) return null;
      url = t;
    }
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.length < 3) return null;
      final style = kAvatarStyles.firstWhere(
        (s) => s.key == segments[1],
        orElse: () => kDefaultStyle,
      );
      final bgParam = uri.queryParameters['backgroundColor'];
      final bg = (bgParam == null || bgParam.isEmpty) ? null : bgParam;
      final seed = uri.queryParameters['seed'] ?? '';
      // 匹配 ${style}_${batchSeed}_${index}（本面板生成的 seed 约定）
      final m = RegExp(r'^(\w+)_(\d+)_(\d+)$').firstMatch(seed);
      int? batchSeed;
      int? index;
      if (m != null) {
        batchSeed = int.tryParse(m.group(2)!);
        index = int.tryParse(m.group(3)!);
      }
      return (style: style, bg: bg, batchSeed: batchSeed, index: index, seed: seed);
    } catch (_) {
      return null;
    }
  }

  List<String> get _presets {
    // 网络为主：按当前风格 / 批次 / 背景色生成规范 DiceBear URL 列表（恒为 _kGridCount 个）
    final list = generateAvatarBatch(
      style: _style.key,
      backgroundColor: _backgroundColor,
      batchSeed: _batchSeed,
      count: _kGridCount,
    );
    // 当前头像的种子不在本批次内（历史遗留 / 外部种子）时，用其替换第 0 格，
    // 保证网格总数恒为 24，且当前头像作为可选内容之一回显选中。
    if (_selectedSeed != null && !_listHasSeed(list, _selectedSeed!)) {
      list[0] = diceBearUrl(
        style: _style.key,
        seed: _selectedSeed!,
        backgroundColor: _backgroundColor,
      );
    }
    return list;
  }

  /// [list] 中是否包含种子为 [seed] 的头像 URL
  bool _listHasSeed(List<String> list, String seed) =>
      list.any((u) => _seedOf(u) == seed);

  /// 从 DiceBear URL 取出 seed（用于按种子而非完整 URL 跟踪选中，使切色调不丢失选择）
  String _seedOf(String url) {
    try {
      return Uri.parse(url).queryParameters['seed'] ?? '';
    } catch (_) {
      return '';
    }
  }

  void _shuffle() => setState(() {
        _batchSeed = randomBatchSeed();
        _selectedSeed = null; // 换一批：网格已变，旧选中不再匹配
      });

  void _onPickStyle(AvatarStyleOption option) {
    setState(() {
      _style = option;
      _h = hsvFromHex(option.defaultBg ?? kDefaultBg).hue;
      _backgroundColor = _currentHex;
      _batchSeed = randomBatchSeed();
      _selectedSeed = null; // 切换风格：网格已变，旧选中不再匹配
    });
  }

  /// 当前选中的规范 DiceBear URL（按当前风格/种子/背景色即时拼接，写入 avatar_url；
  /// 后台/网页任意客户端可直接加载）。
  String? _selectedAvatarUrl() {
    if (_selectedSeed == null) return null;
    return diceBearUrl(
      style: _style.key,
      seed: _selectedSeed!,
      backgroundColor: _backgroundColor,
    );
  }

  /// 当前色相是否命中某个预设主色调（用于色板选中回显）
  String? _matchPresetHue() {
    for (final p in kAvatarBgPresets) {
      if ((hsvFromHex(p).hue - _h).abs() < 0.5) return p;
    }
    return null;
  }

  /// 主色调色板点击：把色相滑块设到该色并即时提交背景色（固定 S/V 保持柔和）。
  /// 注意：仅改变背景色，不清空已选头像——用户可「只改色调、不改头像」。
  void _selectTone(String? hex) {
    setState(() {
      if (hex == null) {
        _backgroundColor = null;
        _activePresetHex = null;
      } else {
        _h = hsvFromHex(hex).hue;
        _backgroundColor = _currentHex;
        _activePresetHex = hex;
      }
      _presetActive = true; // 来自预设色板：启用选中交互
    });
  }

  /// 颜色滑动条拖动中：仅刷新滑块与预览，避免频繁刷新头像网格；
  /// 用户进入自定义色调，移除预设色板的选中交互
  void _onRgbChanged() => setState(() {
        _presetActive = false;
      });

  /// 颜色滑动条松手：提交背景色，驱动头像网格刷新。
  /// 注意：仅改变背景色，不清空已选头像——用户可「只改色调、不改头像」。
  void _onRgbEnd() => setState(() {
        _backgroundColor = _currentHex;
        _presetActive = false; // 自定义色调：移除预设色板选中交互
      });

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _h, kAvatarToneSaturation, kAvatarToneValue).toColor();

  String get _currentHex {
    final c = _currentColor;
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择预设头像'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: '关闭',
        ),
        actions: [
          TextButton(
            onPressed: _selectedSeed == null
                ? null
                : () => Navigator.pop(context, _selectedAvatarUrl()),
            child: const Text('确认'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStyleSection(colorScheme),
          const SizedBox(height: 20),
          _buildToneSection(colorScheme),
          const SizedBox(height: 12),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Expanded(child: _buildGrid(colorScheme)),
        ],
      ),
    );
  }

  /// 风格选择（ChoiceChip 列表）
  Widget _buildStyleSection(ColorScheme colorScheme) => Padding(
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
                    selected: opt == _style,
                    showCheckmark: false,
                    onSelected: (_) => _onPickStyle(opt),
                  ),
              ],
            ),
          ],
        ),
      );

  /// 主色调色板 + 自定义色调滑动条 + 实时预览（作用于选中头像的背景色）
  Widget _buildToneSection(ColorScheme colorScheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主色调（RGB 滑动条锚点）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '主色调',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _toneSwatch(null, '无', colorScheme),
                for (final hex in kAvatarBgPresets) _toneSwatch(hex, null, colorScheme),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 单条色相滑动条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _colorSlider(
              label: '色调',
              activeColor: HSVColor.fromAHSV(1.0, _h, 1, 1).toColor(),
              value: _h,
              min: 0,
              max: 360,
              unit: '°',
              onChanged: (v) {
                _h = v;
                _onRgbChanged();
              },
              onEnd: _onRgbEnd,
            ),
          ),
          // 实时预览
          _buildPreviewRow(colorScheme),
        ],
      );

  /// 实时预览色块（当前背景色调）+ 换一批按钮
  Widget _buildPreviewRow(ColorScheme colorScheme) {
    final hasBg = _backgroundColor != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasBg ? _currentColor : colorScheme.surface,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: hasBg
                ? null
                : Icon(Icons.block, size: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Text(
            hasBg ? '#$_currentHex' : '无背景',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _shuffle,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('换一批'),
          ),
        ],
      ),
    );
  }

  /// 头像网格（恒为 [_kGridCount] 个，4 列；点选暂存，确认后写入）
  Widget _buildGrid(ColorScheme colorScheme) {
    final hasBg = _backgroundColor != null;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kPresetColumns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 1,
      ),
      itemCount: _presets.length,
      itemBuilder: (_, index) {
        final item = _presets[index];
        final selected =
            _selectedSeed != null && _seedOf(item) == _selectedSeed;
        final tintColor = hasBg ? _currentColor : colorScheme.primaryContainer;
        return GestureDetector(
          key: ValueKey<String>(item),
          onTap: () => setState(() {
            _selectedSeed = _seedOf(item);
          }),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.18)
                      : null,
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : Colors.transparent,
                    width: selected ? 3 : 0,
                  ),
                ),
                child: cachedAvatarCircle(
                  url: item,
                  radius: 31,
                  tint: tintColor,
                  colorScheme: colorScheme,
                ),
              ),
              if (selected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 单条 HSV 滑动条（色相/饱和度/明度）：拖动实时预览，松手提交
  Widget _colorSlider({
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

  /// 主色调色板小圆点（[hex] 为 null 表示透明「无」）
  Widget _toneSwatch(String? hex, String? label, ColorScheme colorScheme) {
    // 选中判定基于「是否来自预设色板」而非重算后的 _backgroundColor
    // （点选色板时 hex 经 HSV 固定 S/V 重算，直接比对 hex 会失效）
    final selected = _presetActive && (hex == _activePresetHex);
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
      onTap: () => _selectTone(hex),
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
