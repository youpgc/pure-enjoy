import 'package:flutter/material.dart';
import '../models/novel_model.dart';

/// 聚合来源合规提示横幅（详情页）。
///
/// 明确告知用户：内容来自原平台、纯享不存储正文、点击阅读将跳转原平台。
/// 仅对聚合小说展示。这是聚合阅读版权合规的关键声明。
class NovelAggregationNotice extends StatelessWidget {
  final NovelModel novel;

  const NovelAggregationNotice({super.key, required this.novel});

  @override
  Widget build(BuildContext context) {
    if (!novel.isAggregated) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bg = theme.colorScheme.tertiaryContainer;
    final fg = theme.colorScheme.onTertiaryContainer;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '本书由${novel.sourceDisplayName}提供，点击阅读将跳转至原平台。'
              '纯享仅做聚合，不存储正文。',
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
