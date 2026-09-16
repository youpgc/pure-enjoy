import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_models.dart';
import '../services/pet_service.dart';
import '../widgets/pet_asset_card.dart';
import '../utils/pet_art.dart';
import 'pet_poc_screen.dart';

/// 宠物主页（B2 骨架占位版）
///
/// B3 批次将替换为 3D 主页（model-viewer + skybox + 手势 + 2D 覆盖层），
/// 本页当前仅承接三处入口的落点与总览数据验证：
/// - `pet_enabled` 关闭 → 展示未开放兜底态（入口门控的最后一道防线）；
/// - [initialTab] 为通知深链预留（`?tab=`，无参进入时清信号——沿用既有约定）。
class PetHomeScreen extends StatefulWidget {
  const PetHomeScreen({super.key, this.initialTab});

  /// 深链页签（bag / shop / wallet / quests ...），null 表示正常进入
  final String? initialTab;

  @override
  State<PetHomeScreen> createState() => _PetHomeScreenState();
}

class _PetHomeScreenState extends State<PetHomeScreen> {
  bool _loading = true;
  bool _enabled = false;
  PetSummaryModel? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final enabled = await PetService.instance.isPetEnabled(forceRefresh: force);
    if (!enabled) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
      return;
    }
    final summary = await PetService.instance.fetchSummary(forceRefresh: force);
    if (mounted) {
      setState(() {
        _enabled = true;
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTab == null ? '宠物' : '宠物 · ${widget.initialTab}'),
        // S1 3D POC 工作台入口：仅 debug 包显示（release 无此图标）
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '3D POC 工作台',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetPocScreen()),
              ),
            ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: LoadingWidget());
    }
    if (!_enabled || _summary == null) {
      return const EmptyWidget(message: '宠物功能暂未开放，敬请期待');
    }
    final summary = _summary!;
    final pet = summary.primaryPet;
    // 2D 立绘按 speciesCode+stage 解析（未登记种属返回 null → 回退占位图标）
    final artAsset =
        pet == null ? null : petStageArtAsset(pet.speciesCode, pet.stage);
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initialTab != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '深链页签：${widget.initialTab}（对应页签将在后续批次实装）',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (pet != null) ...[
            // 2D 立绘卡（随包资产；3D 底模未达正式工程标准前，2D 为默认渲染层）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: artAsset != null
                          ? Image.asset(
                              artAsset,
                              height: 200,
                              fit: BoxFit.contain,
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Icon(Icons.pets,
                                  size: 64, color: colorScheme.primary),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text('${pet.name} · Lv.${pet.level}'),
                    Text(
                      '${pet.speciesCode} · ${pet.rarity} · 形态阶位 ${pet.stage}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow('饱食度', pet.hunger, colorScheme),
                    _statRow('心情', pet.mood, colorScheme),
                    _statRow('亲密度', pet.intimacy, colorScheme),
                  ],
                ),
              ),
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.pets_outlined,
                        size: 48, color: colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text('还没有宠物'),
                    const SizedBox(height: 4),
                    Text(
                      '初始蛋已在背包中，孵化引导将在后续批次实装',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          // 3D 资源包状态卡（B3 前置：按系懒加载 + 三层开关 + 用户可感知下载）
          if (pet != null) PetAssetCard(family: pet.family),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('背包', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '已用 ${summary.bagUsed}/${summary.capacities?.backpack ?? '-'} 格'
                    ' · 可即开蛋 ${summary.eggsReadyInstant} 枚',
                  ),
                  const SizedBox(height: 12),
                  Text('金币', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('${summary.wallet.goldBalance}'),
                  if (summary.ongoingAdventure != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '历险进行中（${summary.ongoingAdventure!.status}）',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '当前为 2D 立绘版骨架页；3D 渲染待正式工程资产（重拓扑+绑定+动画）'
            '就绪后按三层开关矩阵灰度开放。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text('$value', textAlign: TextAlign.end, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
