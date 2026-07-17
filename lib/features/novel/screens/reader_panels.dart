import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import '../widgets/reader/reader_widgets.dart';
import '../widgets/tts_panel.dart';

/// 显示书签列表
void showReaderBookmarkList(
  BuildContext context, {
  required List<NovelBookmark> bookmarks,
  required NovelChapterModel? currentChapter,
  required void Function(NovelBookmark) onBookmarkTap,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => ReaderBookmarkPanel(
      bookmarks: bookmarks,
      currentChapter: currentChapter,
      onClose: () => Navigator.pop(context),
      onBookmarkTap: (bm) {
        Navigator.pop(context);
        onBookmarkTap(bm);
      },
    ),
  );
}

/// 显示批注输入面板
void showReaderAnnotationInput(
  BuildContext context,
  String selectedText,
  int startOffset,
  int endOffset, {
  required Future<void> Function(String, int, int, String?, String) onSave,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReaderAnnotationPanel(
      selectedText: selectedText,
      startOffset: startOffset,
      endOffset: endOffset,
      onSave: onSave,
    ),
  );
}

/// 显示批注列表
void showReaderAnnotationList(
  BuildContext context, {
  required List<NovelAnnotation> annotations,
  required Future<void> Function(NovelAnnotation) onDelete,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReaderAnnotationListPanel(
      annotations: annotations,
      onClose: () => Navigator.pop(context),
      onDelete: onDelete,
    ),
  );
}

/// 显示 TTS 控制面板
void showReaderTtsPanel(
  BuildContext context, {
  required bool isPlaying,
  required void Function(bool) onPlayStateChanged,
  required String novelId,
  required String chapterId,
  required String chapterContent,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => TtsPanel(
      isPlaying: isPlaying,
      onPlayStateChanged: onPlayStateChanged,
      novelId: novelId,
      chapterId: chapterId,
      chapterContent: chapterContent,
    ),
  );
}
