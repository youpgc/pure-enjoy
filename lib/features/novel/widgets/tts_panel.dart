import 'package:flutter/material.dart';
import '../services/tts_service.dart';

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '听书模式',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 播放控制
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  tooltip: '上一句',
                  onPressed: () => TtsService().previousSentence(),
                ),
                IconButton(
                  icon: Icon(
                    _localIsPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                  iconSize: 56,
                  tooltip: _localIsPlaying ? '暂停' : '播放',
                  onPressed: _togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  tooltip: '下一句',
                  onPressed: () => TtsService().nextSentence(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 当前朗读句子预览
            if (TtsService().currentSentence != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  TtsService().currentSentence!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // 语速滑块
            Row(
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                Text('语速: ${_tempSpeechRate.toStringAsFixed(1)}x'),
                Expanded(
                  child: Slider(
                    value: _tempSpeechRate,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${_tempSpeechRate.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setState(() => _tempSpeechRate = value);
                    },
                    onChangeEnd: (value) {
                      TtsService().setSpeechRate(value);
                      TtsService().savePreferences();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 定时关闭
            Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                const Text('定时关闭'),
                const Spacer(),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        (null, '关闭'),
                        (15, '15分'),
                        (30, '30分'),
                        (60, '60分'),
                        (-1, '本章'),
                      ].map((option) {
                        final (minutes, label) = option;
                        final isSelected = _tempTimerMinutes == minutes ||
                            (minutes == -1 && _tempTimerMinutes == -1);
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _tempTimerMinutes = minutes);
                              TtsService().setTimer(minutes);
                              TtsService().savePreferences();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 播放模式
            Row(
              children: [
                const Icon(Icons.playlist_play, size: 20),
                const SizedBox(width: 8),
                const Text('播放模式'),
                const Spacer(),
                Flexible(
                  child: SegmentedButton<TtsPlaybackMode>(
                    segments: const [
                      ButtonSegment(
                        value: TtsPlaybackMode.sentence,
                        label: Text('逐句'),
                      ),
                      ButtonSegment(
                        value: TtsPlaybackMode.paragraph,
                        label: Text('逐段'),
                      ),
                      ButtonSegment(
                        value: TtsPlaybackMode.chapter,
                        label: Text('整章'),
                      ),
                    ],
                    selected: {TtsService().playbackMode},
                    onSelectionChanged: (selected) {
                      final mode = selected.first;
                      TtsService().setPlaybackMode(mode);
                      TtsService().savePreferences();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
