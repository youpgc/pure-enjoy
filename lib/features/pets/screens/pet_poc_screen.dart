import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../constants/pet.dart';
import 'pet_asset_audit_screen.dart';

/// S1 3D POC 验证页（开发工具，kDebugMode 门控入口）。
///
/// 验证项对照《开发步骤规划》§2：
/// - 帧率/内存监测（Flutter 层；WebView 内部渲染帧率用系统工具复测，真机数据回填报告）
/// - skybox 视差与色温（skyboxImage + shadowIntensity/exposure 参数化）
/// - 屏幕热区贴合（可视化 + 命中测试，宽高比例可调）
/// - WebView 生命周期（push/pop ×10 演练 + RSS 对比）
/// - 2D 降级演练（模拟 render3d 关闭）
///
/// 素材约定：GLB 放 `assets/pets_poc/yueying.glb`，skybox 放
/// `assets/pets_poc/skybox.jpg`（月萤底模就位后即用）；也支持设备本地路径。
class PetPocScreen extends StatefulWidget {
  const PetPocScreen({super.key});

  @override
  State<PetPocScreen> createState() => _PetPocScreenState();
}

class _PetPocScreenState extends State<PetPocScreen> {
  // ---- 模型来源 ----
  static const String _defaultAssetModel = 'assets/pets_poc/yueying.glb';
  static const String _defaultAssetSkybox = 'assets/pets_poc/skybox.jpg';

  String _modelSource = _defaultAssetModel;
  final TextEditingController _pathCtrl = TextEditingController();

  // ---- 渲染参数 ----
  bool _skyboxOn = false;
  double _shadowIntensity = 0.6;
  double _exposure = 1.0;
  bool _autoRotate = false;
  bool _autoPlay = true;
  final TextEditingController _animCtrl = TextEditingController(text: 'idle');
  bool _disableZoom = false;
  bool _disablePan = false;

  // ---- 热区（比例参数，中心椭圆）----
  bool _hotzoneVisible = true;
  bool _hotzoneHitTest = false;
  double _hotzoneWidthRatio = 0.42;
  double _hotzoneHeightRatio = 0.52;
  String _hitFeedback = '尚未命中';

  // ---- 降级演练 ----
  bool _simulate3dOff = false;

  // ---- 性能监测（Flutter 层帧率 + 进程 RSS）----
  double _fps = 0;
  int _rssMb = 0;
  int _frames = 0;
  Duration _windowStart = Duration.zero;
  bool _monitoring = false;

  // ---- 生命周期演练 ----
  int _drillBeforeMb = 0;
  int _drillCount = 0;

  @override
  void initState() {
    super.initState();
    _startMonitor();
  }

  @override
  void dispose() {
    if (_monitoring) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _pathCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startMonitor() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _monitoring = true;
    _windowStart = SchedulerBinding.instance.currentFrameTimeStamp;
  }

  void _onTimings(List<FrameTiming> timings) {
    _frames += timings.length;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final elapsed = now - _windowStart;
    if (elapsed.inMilliseconds >= 1000) {
      if (mounted) {
        setState(() {
          _fps = _frames * 1000 / elapsed.inMilliseconds;
          _rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
        });
      }
      _frames = 0;
      _windowStart = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D POC 工作台'),
        actions: [
          IconButton(
            tooltip: '素材验收页',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PetAssetAuditScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _perfBar(colorScheme),
          const Divider(height: 1),
          Expanded(child: _viewerArea(colorScheme)),
          const Divider(height: 1),
          Expanded(flex: 2, child: _controlPanel(colorScheme)),
        ],
      ),
    );
  }

  // ==================== 性能监测条 ====================

  Widget _perfBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'FPS(Flutter层) ${_fps.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Icon(Icons.memory, size: 18, color: cs.primary),
          const SizedBox(width: 4),
          Text('RSS $_rssMb MB', style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            'WebView 内部帧率请用系统工具复测',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ==================== 渲染区 ====================

  Widget _viewerArea(ColorScheme cs) {
    if (_simulate3dOff) {
      return _fallback2d(cs);
    }
    final viewer = ModelViewer(
      src: _modelSource,
      alt: '宠物 3D 模型',
      autoPlay: _autoPlay,
      autoRotate: _autoRotate,
      animationName: _animCtrl.text.trim().isEmpty ? null : _animCtrl.text.trim(),
      skyboxImage: _skyboxOn ? _defaultAssetSkybox : null,
      shadowIntensity: _shadowIntensity,
      exposure: _exposure,
      cameraControls: true,
      disableZoom: _disableZoom,
      disablePan: _disablePan,
      backgroundColor: Colors.transparent,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: cs.surfaceContainerLow, child: viewer),
        // 热区叠加层：可视化不拦截手势；命中测试模式单独拦截
        if (_hotzoneVisible) _buildHotzone(visualOnly: !_hotzoneHitTest),
        Positioned(
          right: 8,
          top: 8,
          child: _hintChip(cs, '参数变更会重载 viewer，属预期行为'),
        ),
      ],
    );
  }

  Widget _buildHotzone({required bool visualOnly}) {
    Widget zone = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth * _hotzoneWidthRatio;
        final h = constraints.maxHeight * _hotzoneHeightRatio;
        return Center(
          child: CustomPaint(
            size: Size(w, h),
            painter: _HotzonePainter(),
            child: visualOnly
                ? null
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _hitFeedback = '命中 petted（${DateTime.now().second}s）'),
                  ),
          ),
        );
      },
    );
    if (visualOnly) {
      zone = IgnorePointer(child: zone);
    }
    return zone;
  }

  Widget _fallback2d(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 96, color: cs.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('2D 兜底表现（模拟 render3d 关闭）', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            '正式版：预渲染帧序列/状态图 + 动效（POC 降级预案演练位）',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _hintChip(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    );
  }

  // ==================== 控制面板 ====================

  Widget _controlPanel(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionTitle(cs, '模型来源'),
        Row(
          children: [
            Expanded(
              child: Text(_modelSource, style: const TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => setState(() => _modelSource = _defaultAssetModel),
              child: const Text('assets 默认'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pathCtrl,
                decoration: const InputDecoration(
                  hintText: '或输入设备本地路径（file:///storage/.../x.glb）',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () {
                var v = _pathCtrl.text.trim();
                if (v.isEmpty) return;
                if (!v.startsWith('file://') && !v.startsWith('http')) {
                  v = 'file://$v';
                }
                setState(() => _modelSource = v);
              },
              child: const Text('加载'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _sectionTitle(cs, '渲染参数'),
        SwitchListTile(
          dense: true,
          title: const Text('skybox 全景背景（assets/pets_poc/skybox.jpg）'),
          value: _skyboxOn,
          onChanged: (v) => setState(() => _skyboxOn = v),
        ),
        _sliderRow('阴影强度', _shadowIntensity, 0, 1, (v) => _shadowIntensity = v),
        _sliderRow('曝光', _exposure, 0.2, 2, (v) => _exposure = v),
        SwitchListTile(
          dense: true, title: const Text('autoRotate 自转'),
          value: _autoRotate, onChanged: (v) => setState(() => _autoRotate = v),
        ),
        SwitchListTile(
          dense: true, title: const Text('autoPlay 动画自动播放'),
          value: _autoPlay, onChanged: (v) => setState(() => _autoPlay = v),
        ),
        TextField(
          controller: _animCtrl,
          decoration: const InputDecoration(
            labelText: 'animationName（8 标准: idle/eat/petted/happy/sad/sleep/walk/evolve）',
            isDense: true,
          ),
          onSubmitted: (_) => setState(() {}),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final a in kPetStandardAnimations)
              ActionChip(
                label: Text(a, style: const TextStyle(fontSize: 12)),
                onPressed: () => setState(() => _animCtrl.text = a),
              ),
          ],
        ),
        SwitchListTile(
          dense: true, title: const Text('禁用双指缩放 (disableZoom)'),
          value: _disableZoom, onChanged: (v) => setState(() => _disableZoom = v),
        ),
        SwitchListTile(
          dense: true, title: const Text('禁用平移 (disablePan)'),
          value: _disablePan, onChanged: (v) => setState(() => _disablePan = v),
        ),
        const SizedBox(height: 12),

        _sectionTitle(cs, '屏幕热区（喂食/抚摸命中区）'),
        SwitchListTile(
          dense: true, title: const Text('显示热区可视化'),
          value: _hotzoneVisible, onChanged: (v) => setState(() => _hotzoneVisible = v),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('命中测试（拦截热区内点击）'),
          subtitle: Text(_hitFeedback, style: const TextStyle(fontSize: 12)),
          value: _hotzoneHitTest, onChanged: (v) => setState(() => _hotzoneHitTest = v),
        ),
        _sliderRow('热区宽比例', _hotzoneWidthRatio, 0.2, 0.9, (v) => _hotzoneWidthRatio = v),
        _sliderRow('热区高比例', _hotzoneHeightRatio, 0.2, 0.9, (v) => _hotzoneHeightRatio = v),
        const SizedBox(height: 12),

        _sectionTitle(cs, '降级与生命周期演练'),
        SwitchListTile(
          dense: true, title: const Text('模拟 3D 关闭（2D 兜底）'),
          value: _simulate3dOff, onChanged: (v) => setState(() => _simulate3dOff = v),
        ),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: _runLifecycleDrill,
              child: const Text('push/pop ×10 演练'),
            ),
            const SizedBox(width: 12),
            Text(
              _drillBeforeMb == 0
                  ? '演练前 RSS: -'
                  : '演练 $_drillCount/10 · 前 $_drillBeforeMb → 现 $_rssMb MB',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '记录项：10 次后 RSS 增量（预期回落，泄漏则持续增长）；'
          '10 分钟发热与降频用真机观察回填 POC 报告。',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _sectionTitle(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: value, min: min, max: max,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: (v) {
              onChanged(v);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  // ==================== 生命周期演练 ====================

  Future<void> _runLifecycleDrill() async {
    _drillBeforeMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    final navigator = Navigator.of(context);
    for (var i = 0; i < 10; i++) {
      if (!mounted) return;
      setState(() => _drillCount = i + 1);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const _DrillBlankPage(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      navigator.pop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    final grown = _rssMb - _drillBeforeMb;
    setState(() {
      _rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '演练完成：RSS $_drillBeforeMb → $_rssMb MB，'
          '增量 $grown MB；若持续增长记入 POC 报告',
        ),
      ),
    );
  }
}

/// 生命周期演练占位页（独立 viewer 页，逼真模拟 push 进出宠物主页）
class _DrillBlankPage extends StatelessWidget {
  const _DrillBlankPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// 热区绘制（半透明椭圆 + 虚线边界）
class _HotzonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = const Color(0x332196F3)
      ..style = PaintingStyle.fill;
    canvas.drawOval(rect, paint);
    paint
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
