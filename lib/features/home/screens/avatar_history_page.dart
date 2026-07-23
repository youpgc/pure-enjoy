import 'package:flutter/material.dart';
import '../avatar_presets.dart';
import '../avatar_render.dart';
import '../avatar_history_service.dart';
import '../../../core/widgets/widgets.dart';

/// 历史头像网格可视高度：最多展示 [_kHistoryRows] 行（行×列），超出由网格内部滚动。
const double _kHistoryCellSpacing = 18;
const int _kHistoryColumns = 4;
const int _kHistoryRows = 3;

double _avatarHistoryGridHeight(BuildContext context, int count) {
  if (count <= 0) return 0;
  final w = MediaQuery.of(context).size.width;
  final cellW = (w - 32 - (_kHistoryColumns - 1) * _kHistoryCellSpacing) / _kHistoryColumns;
  var rows = (count / _kHistoryColumns).ceil();
  if (rows > _kHistoryRows) rows = _kHistoryRows;
  return rows * cellW + (rows - 1) * _kHistoryCellSpacing + 16 + 24; // 纵向 padding 16+24
}

/// 预设头像历史（DiceBear，支持色调编辑）
/// 点「保存修改」即把当前预览（可能已改色调）恢复为当前头像，并回传给编辑页套用为
/// 当前头像且写入历史。
class AvatarHistoryPage extends StatelessWidget {
  final String? currentUrl;

  const AvatarHistoryPage({super.key, this.currentUrl});

  @override
  Widget build(BuildContext context) => _AvatarHistoryView(
        currentUrl: currentUrl,
        type: 'dicebear',
        toneEnabled: true,
        title: '历史头像',
        confirmLabel: '保存修改',
      );
}

/// 上传头像历史（完整图片 URL，无色调编辑）
/// 点「保存」把选中头像回传编辑页，由其套用为当前头像并写入历史。
class AvatarUploadHistoryPage extends StatelessWidget {
  final String? currentUrl;

  const AvatarUploadHistoryPage({super.key, this.currentUrl});

  @override
  Widget build(BuildContext context) => _AvatarHistoryView(
        currentUrl: currentUrl,
        type: 'upload',
        toneEnabled: false,
        title: '历史上传头像',
        confirmLabel: '保存',
      );
}

/// 头像历史通用页面（预设 / 上传共用）
///
/// 通过 [type] 决定拉取哪类记录（dicebear / upload）；[toneEnabled] 决定是否提供
/// 主色调编辑与「最终效果」预览（仅预设头像需要；上传头像为完整 URL，原样恢复）。
/// 历史网格渲染于标题与主色调（上传模式为预览）之间，最多 [_kHistoryRows] 行。
/// 进入「历史管理」：显示删除图标、禁用点选、隐藏选中高亮；进入时重置选中与色调。
class _AvatarHistoryView extends StatefulWidget {
  final String? currentUrl;
  final String type;
  final bool toneEnabled;
  final String title;
  final String confirmLabel;

  const _AvatarHistoryView({
    this.currentUrl,
    required this.type,
    required this.toneEnabled,
    required this.title,
    required this.confirmLabel,
  });

  @override
  State<_AvatarHistoryView> createState() => _AvatarHistoryViewState();
}

class _AvatarHistoryViewState extends State<_AvatarHistoryView> {
  List<AvatarHistoryItem> _items = const [];
  bool _loading = true;
  bool _manageMode = false; // 历史管理：显示删除图标、禁用点选、隐藏选中高亮

  String? _selectedId;
  String? _selectedUrl; // 当前预览（可能已改色调）的规范 URL
  // 以下仅 toneEnabled 时有效（上传头像无色调）
  String? _selStyle; // 选中记录的风格 key（改色调时重新拼接用）
  String? _selSeed; // 选中记录的种子
  late double _h = hsvFromHex(kDefaultBg).hue;
  String? _backgroundColor; // null = 透明
  bool _presetActive = true;
  String? _activePresetHex;

  @override
  void initState() {
    super.initState();
    _h = hsvFromHex(kDefaultBg).hue;
    _backgroundColor = null;
    _activePresetHex = null;
    _presetActive = true;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final items = await AvatarHistoryService.fetch(type: widget.type);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      // 进入时不默认选中任何记录，由用户手动点选
    });
  }

  /// 选中一条记录：拆出风格/种子/背景色，回显色调（仅 toneEnabled）
  void _applySelection(AvatarHistoryItem item) {
    final p = parseDiceBearUrl(item.avatarUrl);
    _selectedId = item.id;
    _selStyle = p?.style ?? item.styleKey;
    _selSeed = p?.seed ?? item.seed;
    _backgroundColor = item.backgroundColor;
    _h = hsvFromHex(item.backgroundColor ?? kDefaultBg).hue;
    _selectedUrl = item.avatarUrl;
    if (item.backgroundColor == null) {
      _activePresetHex = null;
      _presetActive = true;
    } else {
      final m = _matchPresetHue();
      if (m != null) {
        _activePresetHex = m;
        _presetActive = true;
      } else {
        _activePresetHex = null;
        _presetActive = false;
      }
    }
  }

  void _onSelectItem(AvatarHistoryItem item) => setState(() {
        _selectedId = item.id;
        _selectedUrl = item.avatarUrl;
        if (widget.toneEnabled) _applySelection(item);
      });

  /// 进入/退出「历史管理」：管理模式显示删除图标、禁用点选、隐藏选中高亮；
  /// 进入时重置选中与色调、清空预览，避免删除已选中头像引发异常。
  void _toggleManage() => setState(() {
        _manageMode = !_manageMode;
        if (_manageMode) {
          _selectedId = null;
          _selectedUrl = null;
          _selStyle = null;
          _selSeed = null;
          if (widget.toneEnabled) {
            _backgroundColor = null;
            _h = hsvFromHex(kDefaultBg).hue;
            _activePresetHex = null;
            _presetActive = true;
          }
        }
      });

  /// 以选中记录的风格/种子 + 当前背景色重新拼接预览 URL（仅 toneEnabled）
  void _regenerateSelected() {
    if (_selStyle != null && _selSeed != null) {
      _selectedUrl = diceBearUrl(
        style: _selStyle!,
        seed: _selSeed!,
        backgroundColor: _backgroundColor,
      );
    }
  }

  String? _matchPresetHue() {
    for (final p in kAvatarBgPresets) {
      if ((hsvFromHex(p).hue - _h).abs() < 0.5) return p;
    }
    return null;
  }

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
      _presetActive = true;
      _regenerateSelected();
    });
  }

  void _onRgbChanged() => setState(() => _presetActive = false);

  void _onRgbEnd() => setState(() {
        _backgroundColor = _currentHex;
        _presetActive = false;
        _regenerateSelected();
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

  /// 点保存：把当前预览（可能已改色调）恢复为当前头像，回传编辑页
  void _confirm() {
    if (_selectedUrl == null) return;
    Navigator.pop(context, _selectedUrl);
  }

  /// 删除一条历史记录
  Future<void> _deleteItem(AvatarHistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该头像记录？'),
        content: const Text('删除后无法恢复，确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await AvatarHistoryService.delete(item.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
        if (_selectedId == item.id) {
          _selectedId = null;
          _selectedUrl = null;
          _selStyle = null;
          _selSeed = null;
        }
      });
      if (mounted) showSnackBar(context, '已删除');
    } else {
      if (mounted) showSnackBar(context, '删除失败，请稍后重试', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: '关闭',
        ),
        actions: [
          TextButton(
            onPressed: _toggleManage,
            child: Text(_manageMode ? '完成' : '历史管理'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(colorScheme),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            _buildEmpty(colorScheme)
          else
            _buildGridSection(colorScheme),
          const SizedBox(height: 8),
          if (widget.toneEnabled)
            _buildToneSection(colorScheme)
          else
            _buildUploadPreviewRow(colorScheme),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTitle(ColorScheme colorScheme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          widget.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Widget _buildEmpty(ColorScheme colorScheme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          widget.type == 'upload'
              ? '还没有上传头像历史，上传过的头像会自动出现在这里。'
              : '还没有历史头像，去「选择预设头像」用过的头像会自动出现在这里。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );

  /// 历史头像网格（最多 [_kHistoryRows]×[_kHistoryColumns]，超出滚动）；位于标题与下方之间
  Widget _buildGridSection(ColorScheme colorScheme) => SizedBox(
        height: _avatarHistoryGridHeight(context, _items.length),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kHistoryColumns,
            mainAxisSpacing: _kHistoryCellSpacing,
            crossAxisSpacing: _kHistoryCellSpacing,
            childAspectRatio: 1,
          ),
          itemCount: _items.length,
          itemBuilder: (_, index) {
            final item = _items[index];
            final selected = !_manageMode && item.id == _selectedId;
            // 按记录自身背景色渲染（透明风格也能正确显示底色），无背景则回退主题色
            final itemBg =
                item.backgroundColor ?? parseDiceBearUrl(item.avatarUrl)?.bg;
            final tintColor = itemBg != null
                ? avatarHexToColor(itemBg)
                : colorScheme.primaryContainer;
            return GestureDetector(
              key: ValueKey<String>(item.id),
              onTap: _manageMode ? null : () => _onSelectItem(item),
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
                      url: item.avatarUrl,
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
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_manageMode)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _deleteItem(item),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  /// 预设头像：主色调编辑 + 背景色预览 + 最终效果预览（组合子模块）
  Widget _buildToneSection(ColorScheme colorScheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToneSwatches(colorScheme),
          const SizedBox(height: 20),
          _buildToneSliderRow(colorScheme),
          _buildTonePreviewRow(colorScheme),
          const SizedBox(height: 16),
          _buildFinalPreview(colorScheme),
        ],
      );

  /// 主色调色板（复用预设页逻辑，作用于选中的历史头像）
  Widget _buildToneSwatches(ColorScheme colorScheme) => Padding(
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
                _toneSwatch(null, '无', colorScheme),
                for (final hex in kAvatarBgPresets) _toneSwatch(hex, null, colorScheme),
              ],
            ),
          ],
        ),
      );

  /// 自定义色调滑动条（拖动实时预览，松手生效）
  Widget _buildToneSliderRow(ColorScheme colorScheme) => Padding(
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
            _colorSlider(
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
          ],
        ),
      );

  /// 预览色块（当前背景色调）+ 保存按钮
  Widget _buildTonePreviewRow(ColorScheme colorScheme) {
    final hasBg = _backgroundColor != null;
    final bgSwatch = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBg ? _currentColor : colorScheme.surface,
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
            hasBg ? '#$_currentHex' : '无背景',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (!_manageMode)
            TextButton(
              // 合并「确认 + 保存修改」：回传当前预览（含色调）由编辑页套用为当前头像并写入历史
              onPressed: _selectedUrl == null ? null : _confirm,
              child: Text(widget.confirmLabel),
            ),
        ],
      ),
    );
  }

  /// 最终效果预览（水平居中展示应用当前色调后的头像）
  Widget _buildFinalPreview(ColorScheme colorScheme) {
    final hasBg = _backgroundColor != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _selectedUrl == null
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
                  url: _selectedUrl!,
                  radius: 48,
                  tint: hasBg ? _currentColor : colorScheme.primaryContainer,
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

  /// 上传头像：仅预览当前选中头像（无色调编辑）
  Widget _buildUploadPreviewRow(ColorScheme colorScheme) {
    final preview = _selectedUrl == null
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
              url: _selectedUrl!,
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
          if (!_manageMode)
            TextButton(
              // 回传当前选中的上传头像，由编辑页套用为当前头像并写入历史
              onPressed: _selectedUrl == null ? null : _confirm,
              child: Text(widget.confirmLabel),
            ),
        ],
      ),
    );
  }

  /// 单条 HSV 滑动条（与预设页一致）
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
