// 场景主题面板：背景主题购买/切换（§11.1，自 rpc_pet_scenes 取数）。

import 'package:flutter/material.dart';
import '../services/pet_rpc_scene.dart';
import '../utils/pet_errors.dart';
import '../../../core/widgets/widgets.dart';
import 'pet_home_scene.dart';
import 'pet_loading.dart';
import 'pet_toast.dart';

/// 场景主题面板（§11.1 背景主题购买替换）
///
/// 自取数（rpc_pet_scenes）；购买=扣金+解锁+自动激活；使用=切换激活。
/// 关闭时经 Navigator.pop 返回最新激活码，宿主按需刷新背景。
class PetThemeSheet extends StatefulWidget {
  const PetThemeSheet({super.key, required this.active});

  /// 打开面板时的当前激活场景码
  final String active;

  @override
  State<PetThemeSheet> createState() => _PetThemeSheetState();
}

class _PetThemeSheetState extends State<PetThemeSheet> {
  // 主题缺兜底时直落场景码；
  // 兜底名与 DB 种子 name 对齐
  static const _sceneLabels = {
    'scene_dream': '梦幻夜空',
    'scene_meadow': '晨曦草甸',
    'scene_sakura': '樱花庭院',
    'scene_snow': '雪原暖屋',
    'scene_beach': '椰风海滩',
    'scene_starry': '星海之栏',
    'scene_glow': '秘境萤光',
    'scene_isle': '云上浮岛',
  };

  /// 行名以服务端下发的 name 为准（新增主题零改码）
  /// 空/缺失时回退本地映射，再回退场景码
  static String _labelOf(Map<String, dynamic> sc) {
    final code = sc['scene_code']?.toString() ?? '';
    final name = sc['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return _sceneLabels[code] ?? code;
  }

  List<Map<String, dynamic>>? _scenes;
  String _active = 'scene_dream';
  String? _err;
  String? _pending; // 正在结算的场景码

  @override
  void initState() {
    super.initState();
    _active = widget.active;
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    final (data, err) = await PetRpcScene.fetchScenes();
    if (!mounted) return;
    if (err != null || data == null) {
      setState(() => _err = err);
      return;
    }
    final raw = data['scenes'];
    setState(() {
      _scenes = raw is List
          ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      _active = data['active']?.toString() ?? 'scene_dream';
    });
  }

  Future<void> _purchase(Map<String, dynamic> sc) async {
    if (_pending != null) return;
    final code = sc['scene_code']?.toString() ?? '';
    // 价格缺失时拒绝并提示（放行会显示「消耗 0 金币」后被服务端拒绝，两段体验错位
    final price = (sc['price_coin'] as num?)?.toInt();
    final label = _labelOf(sc);
    if (price == null) {
      showPetToast(context, '「$label」暂未定价，无法购买');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '购买「$label」',
      content: '将消耗 $price 金币，购买后自动启用。',
      confirmText: '购买',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pending = code);
    final (data, err) = await PetRpcScene.purchaseScene(code);
    if (!mounted) return;
    setState(() => _pending = null);
    if (err != null || data == null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    setState(() => _active = code);
    showPetToast(context, '主题已启用');
    // 购买即启用即生效：带最新场景码关面板，主页背景立即切换
    if (mounted) Navigator.of(context).pop(code);
  }

  Future<void> _activate(Map<String, dynamic> sc) async {
    if (_pending != null) return;
    final code = sc['scene_code']?.toString() ?? '';
    setState(() => _pending = code);
    final (data, err) = await PetRpcScene.activateScene(code);
    if (!mounted) return;
    setState(() => _pending = null);
    if (err != null || data == null) {
      showPetToast(context, petRpcErrorText(err));
      return;
    }
    setState(() => _active = code);
    // 切换即生效：带最新场景码关面板，主页背景立即切换
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('场景主题',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_err != null)
              Column(
                children: [
                  Text(petRpcErrorText(_err),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: _load, child: const Text('重试')),
                ],
              )
            else if (_scenes == null)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: PetPawLoading(),
              ))
            else
              for (final sc in _scenes!) ...[
                _sceneTile(cs, sc),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _sceneTile(ColorScheme cs, Map<String, dynamic> sc) {
    final code = sc['scene_code']?.toString() ?? '';
    final owned = sc['owned'] == true;
    final using = _active == code;
    final price = (sc['price_coin'] as num?)?.toInt();
    final label = _labelOf(sc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: using ? Border.all(color: cs.primary, width: 1.4) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    if (using) _miniTag(cs, '使用中', cs.primary),
                  ],
                ),
                if (!owned && price != null)
                  Text('售价 $price 金币',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (using)
            Icon(Icons.check_circle, size: 20, color: cs.primary)
          else ...[
            // 买前预览：整屏实景背景（万级买断价必须先看效果）
            IconButton(
              tooltip: '预览效果',
              visualDensity: VisualDensity.compact,
              onPressed: () => _previewScene(sc),
              icon: Icon(Icons.visibility_outlined,
                  size: 20, color: cs.onSurfaceVariant),
            ),
            if (owned)
              OutlinedButton(
                onPressed: _pending == null ? () => _activate(sc) : null,
                child: _pending == code
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('使用'),
              )
            else
              FilledButton(
                onPressed: _pending == null ? () => _purchase(sc) : null,
                child: _pending == code
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('$price 金币'),
              ),
          ],
        ],
      ),
    );
  }

  /// 整屏预览：真实场景背景 + 主题名/操作提示，点任意处关闭
  Future<void> _previewScene(Map<String, dynamic> sc) async {
    final code = sc['scene_code']?.toString() ?? 'scene_dream';
    final label = _labelOf(sc);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PetSceneBackground(sceneCode: code),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('预览效果 · 点击任意处返回',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(ColorScheme cs, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
