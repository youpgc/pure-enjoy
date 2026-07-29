import 'package:flutter/material.dart';
import '../models/novel_tts_model.dart';
import '../services/tts_service.dart';

/// {@template tts_panel_content}
/// [TtsPanel] 的主体内容（从超长 build 抽取，便于维护）。
/// 仅读取传入字段与回调，不持有状态。各控制区拆为独立子组件。
/// {@endtemplate}
class TtsPanelContent extends StatelessWidget {
  /// {@macro tts_panel_content}
  const TtsPanelContent({
    super.key,
    required this.isPlaying,
    required this.speechRate,
    required this.timerMinutes,
    required this.playbackMode,
    required this.currentSentence,
    required this.onTogglePlay,
    required this.onSpeechRateChanged,
    required this.onSpeechRateEnd,
    required this.onTimerSelected,
    required this.onPlaybackModeChanged,
  });

  final bool isPlaying;
  final double speechRate;
  final int? timerMinutes;
  final TtsPlaybackMode playbackMode;
  final String? currentSentence;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSpeechRateChanged;
  final ValueChanged<double> onSpeechRateEnd;
  final ValueChanged<int?> onTimerSelected;
  final ValueChanged<TtsPlaybackMode> onPlaybackModeChanged;

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
            TtsPlaybackControls(
              isPlaying: isPlaying,
              onTogglePlay: onTogglePlay,
            ),
            const SizedBox(height: 8),
            if (currentSentence != null)
              TtsCurrentSentence(sentence: currentSentence!),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            TtsSpeedSlider(
              speechRate: speechRate,
              onChanged: onSpeechRateChanged,
              onEnd: onSpeechRateEnd,
            ),
            const SizedBox(height: 12),
            TtsTimerRow(
              timerMinutes: timerMinutes,
              onSelected: onTimerSelected,
            ),
            const SizedBox(height: 12),
            TtsPlaybackModeRow(
              playbackMode: playbackMode,
              onChanged: onPlaybackModeChanged,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// 听书播放控制行（上一句 / 播放暂停 / 下一句）
class TtsPlaybackControls extends StatelessWidget {
  const TtsPlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  final bool isPlaying;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          tooltip: '上一句',
          onPressed: () => TtsService().previousSentence(),
        ),
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle : Icons.play_circle,
          ),
          iconSize: 56,
          tooltip: isPlaying ? '暂停' : '播放',
          onPressed: onTogglePlay,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          tooltip: '下一句',
          onPressed: () => TtsService().nextSentence(),
        ),
      ],
    );
  }
}

/// 当前朗读句子预览
class TtsCurrentSentence extends StatelessWidget {
  const TtsCurrentSentence({super.key, required this.sentence});

  final String sentence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        sentence,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 语速调节滑块
class TtsSpeedSlider extends StatelessWidget {
  const TtsSpeedSlider({
    super.key,
    required this.speechRate,
    required this.onChanged,
    required this.onEnd,
  });

  final double speechRate;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.speed, size: 20),
        const SizedBox(width: 8),
        Text('语速: ${speechRate.toStringAsFixed(1)}x'),
        Expanded(
          child: Slider(
            value: speechRate,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: '${speechRate.toStringAsFixed(1)}x',
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ),
      ],
    );
  }
}

/// 定时关闭选项行
class TtsTimerRow extends StatelessWidget {
  const TtsTimerRow({
    super.key,
    required this.timerMinutes,
    required this.onSelected,
  });

  final int? timerMinutes;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                final isSelected = timerMinutes == minutes ||
                    (minutes == -1 && timerMinutes == -1);
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onSelected(minutes);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 播放模式选择（逐句 / 逐段 / 整章）
class TtsPlaybackModeRow extends StatelessWidget {
  const TtsPlaybackModeRow({
    super.key,
    required this.playbackMode,
    required this.onChanged,
  });

  final TtsPlaybackMode playbackMode;
  final ValueChanged<TtsPlaybackMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            selected: {playbackMode},
            onSelectionChanged: (selected) => onChanged(selected.first),
          ),
        ),
      ],
    );
  }
}
