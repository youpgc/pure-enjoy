import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import './tts_panel_content.dart';

/// TTS（听书）控制面板
///
/// 以底部弹窗形式展示，提供语速调节、定时关闭、播放模式切换
/// 以及播放/暂停/上一句/下一句等控制功能。
class TtsPanel extends StatefulWidget {
  /// 当前是否正在播放
  final bool isPlaying;

  /// 播放状态变化回调
  final ValueChanged<bool> onPlayStateChanged;

  /// 小说 ID，用于 TTS 播放定位
  final String novelId;

  /// 章节 ID，用于 TTS 播放定位
  final String chapterId;

  /// 章节正文内容
  final String chapterContent;

  const TtsPanel({
    super.key,
    required this.isPlaying,
    required this.onPlayStateChanged,
    required this.novelId,
    required this.chapterId,
    required this.chapterContent,
  });

  @override
  State<TtsPanel> createState() => _TtsPanelState();
}

class _TtsPanelState extends State<TtsPanel> {
  /// 临时语速值（未确认时仅本地展示）
  late double _tempSpeechRate;

  /// 临时定时关闭分钟数（null=关闭，-1=本章结束）
  late int? _tempTimerMinutes;

  /// 本地播放状态，用于在面板内即时响应用户点击
  late bool _localIsPlaying;

  @override
  void initState() {
    super.initState();
    _tempSpeechRate = TtsService().speechRate;
    _tempTimerMinutes = TtsService().timerMinutes;
    _localIsPlaying = widget.isPlaying;
  }

  @override
  void didUpdateWidget(covariant TtsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _localIsPlaying = widget.isPlaying;
    }
  }

  /// 切换播放/暂停状态
  void _togglePlay() {
    final newPlaying = !_localIsPlaying;
    setState(() => _localIsPlaying = newPlaying);
    widget.onPlayStateChanged(newPlaying);
    if (newPlaying) {
      TtsService().playChapter(
        widget.novelId,
        widget.chapterId,
        widget.chapterContent,
        0,
      );
    } else {
      TtsService().stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TtsPanelContent(
      isPlaying: _localIsPlaying,
      speechRate: _tempSpeechRate,
      timerMinutes: _tempTimerMinutes,
      playbackMode: TtsService().playbackMode,
      currentSentence: TtsService().currentSentence,
      onTogglePlay: _togglePlay,
      onSpeechRateChanged: (value) => setState(() => _tempSpeechRate = value),
      onSpeechRateEnd: (value) {
        TtsService().setSpeechRate(value);
        TtsService().savePreferences();
      },
      onTimerSelected: (minutes) {
        setState(() => _tempTimerMinutes = minutes);
        TtsService().setTimer(minutes);
        TtsService().savePreferences();
      },
      onPlaybackModeChanged: (mode) {
        TtsService().setPlaybackMode(mode);
        TtsService().savePreferences();
        setState(() {});
      },
    );
  }
}
