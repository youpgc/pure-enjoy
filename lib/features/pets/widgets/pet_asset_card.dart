import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../constants/pet.dart';
import '../services/pet_asset_service.dart';
import '../services/pet_service.dart';

/// 3D 资源包状态卡（宠物主页）
///
/// 展示三层判定要素与资源包状态机，用户可感知下载（体积/流量提示/进度/重试）：
/// - 系统开关关闭 → 卡片置灰提示「暂未开放」（管理员降级场景）；
/// - 用户开关 → Switch 持久化（设备级偏好，切号不清除）；
/// - 资源包 → 按系展示 missing/downloading/verifying/ready/corrupt/error，
///   未下载提供「下载资源包」入口（确认弹窗含体积与 Wi-Fi 建议）。
class PetAssetCard extends StatefulWidget {
  const PetAssetCard({super.key, required this.family});

  /// 当前宠物所属系（资源包按系懒加载的最小粒度）
  final String family;

  @override
  State<PetAssetCard> createState() => _PetAssetCardState();
}

class _PetAssetCardState extends State<PetAssetCard> {
  bool _loading = true;
  bool _systemEnabled = false;
  bool _userEnabled = true;
  PetAssetPackState? _state;

  @override
  void initState() {
    super.initState();
    PetAssetService.instance.states.addListener(_onStatesChanged);
    _reload();
  }

  @override
  void dispose() {
    PetAssetService.instance.states.removeListener(_onStatesChanged);
    super.dispose();
  }

  void _onStatesChanged() {
    final s = PetAssetService.instance.states.value[widget.family];
    if (s != null && mounted) setState(() => _state = s);
  }

  Future<void> _reload() async {
    final system = await PetService.instance.isRender3dSystemEnabled();
    final user = await PetAssetService.instance.isUser3dEnabled();
    final state = await PetAssetService.instance.lightCheck(widget.family);
    if (mounted) {
      setState(() {
        _systemEnabled = system;
        _userEnabled = user;
        _state = state;
        _loading = false;
      });
    }
  }

  Future<void> _toggleUserSwitch(bool value) async {
    await PetAssetService.instance.setUser3dEnabled(value);
    if (mounted) setState(() => _userEnabled = value);
  }

  /// 下载确认：体积 + 流量建议（非 Wi-Fi 明确提示），确认后触发下载
  Future<void> _confirmDownload(int sizeBytes) async {
    final sizeText = sizeBytes > 0 ? '约 ${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB' : '较大体积';
    var onWifi = true;
    try {
      final result = await Connectivity().checkConnectivity();
      onWifi = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    } catch (_) {
      // 检测失败按 Wi-Fi 处理（不额外打扰）
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载 3D 资源包'),
        content: Text(
          '宠物 3D 模型资源包 $sizeText，下载一次本地缓存，后续进入零流量。\n'
          '${onWifi ? '当前处于 Wi-Fi 网络，可直接下载。' : '当前为移动网络，建议连接 Wi-Fi 后再下载。'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('先用 2D'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即下载'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await PetAssetService.instance.downloadPack(widget.family);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资源包下载失败，可稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3D 系统开关关闭 → 整卡隐藏（2D 为默认渲染层，不向普通用户暴露
    // 「暂未开放」占位噪音；POC 工作台走 debug 入口不受影响）
    if (!_loading && !_systemEnabled) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_in_ar_outlined,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('3D 渲染', style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      _statusChip(colorScheme),
                    ],
                  ),
                  if (!_systemEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      '3D 功能暂未开放，当前以 2D 渲染',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _userEnabled,
                      onChanged: _toggleUserSwitch,
                      title: const Text('启用 3D 渲染'),
                      subtitle: Text(
                        _effective3d
                            ? '进入宠物主页将以 3D 渲染'
                            : '关闭后仅以 2D 渲染（更省流量与电量）',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _packRow(colorScheme),
                  ],
                ],
              ),
      ),
    );
  }

  bool get _effective3d =>
      _systemEnabled &&
      _userEnabled &&
      _state?.status == PetAssetPackStatus.ready;

  Widget _statusChip(ColorScheme colorScheme) {
    final state = _state;
    String text;
    Color color;
    if (!_systemEnabled) {
      text = '未开放';
      color = colorScheme.outline;
    } else {
      switch (state?.status ?? PetAssetPackStatus.missing) {
        case PetAssetPackStatus.ready:
          text = state!.updateAvailable ? '有新版本' : '已就绪';
          color = colorScheme.primary;
        case PetAssetPackStatus.downloading:
          text = '下载中';
          color = colorScheme.tertiary;
        case PetAssetPackStatus.verifying:
          text = '校验中';
          color = colorScheme.tertiary;
        case PetAssetPackStatus.corrupt:
          text = '已损坏';
          color = colorScheme.error;
        case PetAssetPackStatus.error:
          text = '下载失败';
          color = colorScheme.error;
        case PetAssetPackStatus.missing:
          text = '未下载';
          color = colorScheme.outline;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _packRow(ColorScheme colorScheme) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    switch (state.status) {
      case PetAssetPackStatus.downloading:
        final progress = state.progress;
        final downloaded = (state.downloadedBytes / 1024 / 1024).toStringAsFixed(1);
        final total = state.remoteSizeBytes > 0
            ? ' / ${(state.remoteSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
            : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 4),
            Text('已下载 $downloaded MB$total',
                style: const TextStyle(fontSize: 11)),
          ],
        );
      case PetAssetPackStatus.verifying:
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('正在校验资源完整性…', style: TextStyle(fontSize: 12)),
        );
      case PetAssetPackStatus.missing:
      case PetAssetPackStatus.corrupt:
      case PetAssetPackStatus.error:
        final isRetry =
            state.status != PetAssetPackStatus.missing;
        final label = isRetry ? '重新下载' : '下载资源包';
        final hint = isRetry
            ? '资源包${state.status == PetAssetPackStatus.corrupt ? '校验未通过' : '下载失败'}，可重试'
            : '按系打包 · 下载一次本地缓存';
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(hint,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              TextButton(
                onPressed: () => _confirmDownload(state.remoteSizeBytes),
                child: Text(label),
              ),
            ],
          ),
        );
      case PetAssetPackStatus.ready:
        final versionText = state.version > 0 ? ' · v${state.version}' : '';
        final update = state.updateAvailable
            ? TextButton(
                onPressed: () => _confirmDownload(state.remoteSizeBytes),
                child: const Text('更新'),
              )
            : const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '资源包已就绪$versionText，进入主页零流量加载',
                  style:
                      TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
              update,
            ],
          ),
        );
    }
  }
}
