part of './avatar_history_page.dart';

/// [AvatarHistoryView] 的主体逻辑。纯展示型 builder 已抽到
/// [avatar_history_grid] / [avatar_history_tone] 两个 part 文件（均为显式传参的
/// StatelessWidget，行为完全不变）；本文件只保留状态字段与状态变更方法。
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

  /// 选中一条记录（仅 toneEnabled 时回显色调）
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
          _AvatarHistoryTitle(title: widget.title, colorScheme: colorScheme),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            _AvatarHistoryEmpty(type: widget.type, colorScheme: colorScheme)
          else
            _AvatarHistoryGrid(
              items: _items,
              manageMode: _manageMode,
              selectedId: _selectedId,
              colorScheme: colorScheme,
              onSelect: _onSelectItem,
              onDelete: _deleteItem,
            ),
          const SizedBox(height: 8),
          if (widget.toneEnabled)
            _buildToneSection(colorScheme)
          else
            _AvatarHistoryUploadPreview(
              selectedUrl: _selectedUrl,
              manageMode: _manageMode,
              colorScheme: colorScheme,
              onConfirm: _selectedUrl == null ? null : _confirm,
              confirmLabel: widget.confirmLabel,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
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

  /// 预设头像：主色调编辑 + 背景色预览 + 最终效果预览（组合子模块）
  Widget _buildToneSection(ColorScheme colorScheme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarHistoryToneSwatches(
            presetActive: _presetActive,
            activePresetHex: _activePresetHex,
            colorScheme: colorScheme,
            onSelectTone: _selectTone,
          ),
          const SizedBox(height: 20),
          _AvatarHistoryToneSlider(
            h: _h,
            colorScheme: colorScheme,
            onHueChanged: (v) {
              _h = v;
              _onRgbChanged();
            },
            onRgbEnd: _onRgbEnd,
          ),
          _AvatarHistoryTonePreviewRow(
            backgroundColor: _backgroundColor,
            currentColor: _currentColor,
            currentHex: _currentHex,
            manageMode: _manageMode,
            selectedUrl: _selectedUrl,
            colorScheme: colorScheme,
            onConfirm: _selectedUrl == null ? null : _confirm,
            confirmLabel: widget.confirmLabel,
          ),
          const SizedBox(height: 16),
          _AvatarHistoryFinalPreview(
            backgroundColor: _backgroundColor,
            currentColor: _currentColor,
            selectedUrl: _selectedUrl,
            colorScheme: colorScheme,
          ),
        ],
      );
}
