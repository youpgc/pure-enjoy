import 'package:flutter/material.dart';
import '../../models/novel_model.dart';
import '../reader_enums.dart';
import '../../../../core/widgets/widgets.dart';

/// 小说阅读器目录抽屉组件
class ReaderChapterDrawer extends StatefulWidget {
  final List<NovelChapterModel> chapters;
  final int currentChapterIndex;
  final ReaderBackground background;
  final int catalogPageSize;
  final void Function(int globalIndex, NovelChapterModel chapter) onChapterTap;
  final VoidCallback? onCloseDrawer;

  const ReaderChapterDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.background,
    required this.catalogPageSize,
    required this.onChapterTap,
    this.onCloseDrawer,
  });

  @override
  State<ReaderChapterDrawer> createState() => _ReaderChapterDrawerState();
}

class _ReaderChapterDrawerState extends State<ReaderChapterDrawer> {
  int _catalogPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return const Drawer(child: Center(child: LoadingWidget()));
    }

    final totalPages = (widget.chapters.length / widget.catalogPageSize).ceil();
    final startIndex = _catalogPage * widget.catalogPageSize;
    final endIndex = (startIndex + widget.catalogPageSize).clamp(0, widget.chapters.length);
    final pageChapters = widget.chapters.sublist(startIndex, endIndex);

    return Drawer(
      backgroundColor: widget.background.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '目录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.background.textColor,
                      ),
                    ),
                  ),
                  Text(
                    '共 ${widget.chapters.length} 章',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.background.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 页码控制
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: widget.background.textColor),
                    onPressed: _catalogPage > 0
                        ? () {
                            setState(() => _catalogPage--);
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  Text(
                    '${_catalogPage + 1} / $totalPages',
                    style: TextStyle(fontSize: 13, color: widget.background.textColor),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: widget.background.textColor),
                    onPressed: _catalogPage < totalPages - 1
                        ? () {
                            setState(() => _catalogPage++);
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: pageChapters.length,
                itemBuilder: (context, i) {
                  final chapter = pageChapters[i];
                  final globalIndex = startIndex + i;
                  final isCurrent = globalIndex == widget.currentChapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : widget.background.textColor,
                        fontWeight: isCurrent ? FontWeight.bold : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      widget.onCloseDrawer?.call();
                      widget.onChapterTap(globalIndex, chapter);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
