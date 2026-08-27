import 'package:flutter/material.dart';
import '../services/horoscope_service.dart';

/// 星座运势详情页
///
/// 从首页运势卡点击进入。优先拉取真实第三方「详细今日解读」（天行数据 star 接口，
/// 含今日概述大段文字 + 分项百分比指数 + 幸运信息）；未配置密钥或请求失败时自动
/// 回退到内置离线数据集（概述=当日文案，指数=分项星级），保证页面始终有内容。
class HoroscopeDetailPage extends StatefulWidget {
  final String signName;

  const HoroscopeDetailPage({super.key, required this.signName});

  @override
  State<HoroscopeDetailPage> createState() => _HoroscopeDetailPageState();
}

class _HoroscopeDetailPageState extends State<HoroscopeDetailPage> {
  HoroscopeDetail? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 优先真实接口，失败/无数据自动回退内置（getHoroscope 内部处理）
    final data = await HoroscopeService.getHoroscope(widget.signName);
    if (mounted) {
      setState(() {
        _detail = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = zodiacSymbol[widget.signName] ?? '✨';
    final dateRange = zodiacDateRange[widget.signName] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.signName}今日运势'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('暂无运势数据'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头部
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    symbol,
                                    style: TextStyle(
                                      fontSize: 26,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.signName,
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateRange,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_detail!.fromRemote)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '当前为内置解读（接口不可用）',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 今日概述
                      _SectionCard(
                        title: '今日概述',
                        child: Text(
                          _detail!.overview,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 分项指数
                      if (_detail!.indices.isNotEmpty)
                        _SectionCard(
                          title: '运势指数',
                          child: Column(
                            children: _detail!.indices.entries.map((e) {
                              return _IndexRow(
                                label: e.key,
                                value: e.value,
                                isPercent: _detail!.indicesArePercent,
                                colorScheme: colorScheme,
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 幸运信息
                      _SectionCard(
                        title: '幸运信息',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _LuckyChip(
                              label: '幸运颜色',
                              value: _detail!.luckyColor,
                              colorScheme: colorScheme,
                            ),
                            _LuckyChip(
                              label: '幸运数字',
                              value: _detail!.luckyNumber,
                              colorScheme: colorScheme,
                            ),
                            if (_detail!.extraSign != null &&
                                _detail!.extraSignLabel != null)
                              _LuckyChip(
                                label: _detail!.extraSignLabel!,
                                value: _detail!.extraSign!,
                                colorScheme: colorScheme,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }
}

/// 详情区块卡片（标题 + 内容）
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// 分项指数一行（百分比→进度条；星级→文本）
class _IndexRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPercent;
  final ColorScheme colorScheme;

  const _IndexRow({
    required this.label,
    required this.value,
    required this.isPercent,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPercent) {
      // 内置回退：星级文本
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.tertiary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }
    final pct = int.tryParse(value.replaceAll('%', '').trim()) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// 幸运信息胶囊
class _LuckyChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _LuckyChip({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSecondaryContainer),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
