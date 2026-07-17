import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import 'reader_chapter_loader_mixin.dart';

/// 小说阅读器页面
class NovelReaderScreen extends StatefulWidget {
  final NovelModel novel;
  final int startChapter;

  const NovelReaderScreen({
    super.key,
    required this.novel,
    this.startChapter = 1,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin<NovelReaderScreen>, ReaderChapterLoaderMixin {}
