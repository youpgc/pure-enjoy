import 'package:flutter/material.dart';
import '../models/novel_model.dart';
import './reader_controller.dart';

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
    with SingleTickerProviderStateMixin<NovelReaderScreen> {
  late ReaderController _controller;
  late AnimationController _toolbarAnimationController;

  @override
  void initState() {
    super.initState();
    _toolbarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controller = ReaderController(
      novel: widget.novel,
      startChapter: widget.startChapter,
      toolbarAnimationController: _toolbarAnimationController,
    );
    _controller.bindState((fn) {
      if (mounted) setState(fn);
    }, context);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _controller.unbind();
    _toolbarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller.build(context);
}
