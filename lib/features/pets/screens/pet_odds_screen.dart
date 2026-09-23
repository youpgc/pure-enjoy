import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../models/pet_p2_models.dart';
import '../services/pet_rpc_p2.dart';
import '../utils/pet_errors.dart';

/// 抽蛋概率公示页（P2）
///
/// 数据源 `pet_egg_pools`（published 且取每个 pool_code 的最高 config_version），
/// **与服务端判定同源**：抽蛋时写入审计流水的 config_version 与这里展示的是同一行，
/// 客户端不参与任何概率推算、也不为未配置项补默认值（铁律 1、2）——
/// 后台没配的行（如性别比）直接不显示，避免把猜测值当成对外承诺。
class PetOddsScreen extends StatefulWidget {
  const PetOddsScreen({super.key});

  @override
  State<PetOddsScreen> createState() => _PetOddsScreenState();
}

class _PetOddsScreenState extends State<PetOddsScreen> {
  bool _loading = true;
  String? _error;
  List<PetEggOddsModel> _pools = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (pools, err) = await PetRpcP2.fetchPublishedEggOdds();
    if (!mounted) return;
    setState(() {
      _pools = pools;
      _error = err == null ? null : petRpcErrorText(err);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('概率公示')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingWidget());
    if (_error != null && _pools.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_pools.isEmpty) {
      return const EmptyWidget(message: '还没有已公示的蛋池');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final p in _pools) ...[
            _poolCard(cs, p),
            const SizedBox(height: 12),
          ],
          Text(
            '以上概率与后台配置同版本，抽取结果由服务端判定并留痕；'
            '每次抽取的随机结果相互独立，短期内不必然按比例出现。',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _poolCard(ColorScheme cs, PetEggOddsModel pool) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(pool.poolCode.isEmpty ? '蛋池' : pool.poolCode,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text('配置版本 v${pool.configVersion}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            _oddsGroup(cs, '评级', pool.rarityLines),
            _oddsGroup(cs, '系别', pool.familyLines),
            _oddsGroup(cs, '性别', pool.genderLine == null
                ? const <String>[]
                : [pool.genderLine!]),
          ],
        ),
      ),
    );
  }

  /// 一组概率行；服务端没配该项就整组不渲染（不显示 0%、不写死文案）
  Widget _oddsGroup(ColorScheme cs, String label, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final line in lines)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(line,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
