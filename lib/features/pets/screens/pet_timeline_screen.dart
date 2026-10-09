import 'package:flutter/material.dart';

import '../services/pet_rpc.dart';
import '../utils/pet_errors.dart';

/// 宠物成长回忆（需求 §3.3 时间线的 App 呈现，2026-10-09 实装）
///
/// 纪念卡列表：系统自动写入的成长编年史（升级/进化/改名/送别等），
/// 用户不可编辑；倒序展示，单次最多拉取 100 条（服务端上限 200）。
class PetTimelineScreen extends StatefulWidget {
  const PetTimelineScreen({super.key, required this.petId, required this.petName});

  final String petId;
  final String petName;

  @override
  State<PetTimelineScreen> createState() => _PetTimelineScreenState();
}

class _Item {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime at;
  _Item(this.type, this.payload, this.at);
}

class _PetTimelineScreenState extends State<PetTimelineScreen> {
  List<_Item>? _items;
  int _total = 0;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (data, err) = await PetRpc.fetchTimeline(widget.petId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err != null || data == null) {
        _error = err;
        _items = null;
        return;
      }
      _total = (data['total'] as num?)?.toInt() ?? 0;
      final raw = data['items'];
      _items = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => _Item(
                  e['type']?.toString() ?? 'unknown',
                  (e['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
                  DateTime.tryParse(e['at']?.toString() ?? '') ?? DateTime.now()))
              .toList()
          : <_Item>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.petName}的成长回忆')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('回忆加载失败',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(petRpcErrorText(_error),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : (_items == null || _items!.isEmpty)
                  ? Center(
                      child: Text('还没有留下回忆，多陪陪它吧',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('成长编年史 · 共 $_total 条',
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: _items!.length,
                                itemBuilder: (ctx, i) =>
                                    _card(cs, _items![i], i == _items!.length - 1),
                              ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  (IconData, String, String) _decor(_Item item) {
    final p = item.payload;
    switch (item.type) {
      case 'levelup':
        return (Icons.trending_up, '升级',
            '成长到 Lv.${p['level'] ?? '?'}，变得更加强大了');
      case 'evolve':
        return (Icons.auto_awesome, '进化', '完成了进化，蜕变成新的形态');
      case 'rename':
        return (Icons.badge_outlined,
            '改名', '从「${p['from'] ?? '?'}」改名为「${p['to'] ?? '?'}」');
      case 'release':
        return (Icons.spa_outlined, '送别',
            '被送归自然（Lv.${p['level'] ?? '?'}），图鉴会永远记得它');
      default:
        return (Icons.circle_outlined, item.type, p.toString());
    }
  }

  Widget _card(ColorScheme cs, _Item item, bool isLast) {
    final (icon, title, desc) = _decor(item);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间轴轨（圆点 + 竖线）
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: cs.primary.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600))),
                        Text(
                          '${item.at.year}.${item.at.month}.${item.at.day}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(desc,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
