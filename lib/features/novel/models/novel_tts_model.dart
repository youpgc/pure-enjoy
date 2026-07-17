/// TTS播放模式枚举
enum TtsPlaybackMode { sentence, paragraph, chapter }

/// TTS播放日志模型 — 对应 tts_playback_logs 表
class TtsPlaybackLog {
  final String id;
  final String userId;
  final String novelId;
  final String chapterId;
  final int startSentenceIndex;
  final int? endSentenceIndex;
  final int? durationSeconds;
  final double speechRate;
  final TtsPlaybackMode playbackMode;
  final DateTime createdAt;

  TtsPlaybackLog({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.chapterId,
    this.startSentenceIndex = 0,
    this.endSentenceIndex,
    this.durationSeconds,
    this.speechRate = 1.0,
    this.playbackMode = TtsPlaybackMode.sentence,
    required this.createdAt,
  });

  factory TtsPlaybackLog.fromJson(Map<String, dynamic> json) {
    return TtsPlaybackLog(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      novelId: json['novel_id'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      startSentenceIndex: json['start_sentence_index'] as int? ?? 0,
      endSentenceIndex: json['end_sentence_index'] as int?,
      durationSeconds: json['duration_seconds'] as int?,
      speechRate: json['speech_rate'] != null ? (json['speech_rate'] as num).toDouble() : 1.0,
      playbackMode: TtsPlaybackMode.values.firstWhere(
        (e) => e.name == (json['playback_mode'] as String? ?? 'sentence'),
        orElse: () => TtsPlaybackMode.sentence,
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'novel_id': novelId,
      'chapter_id': chapterId,
      'start_sentence_index': startSentenceIndex,
      'end_sentence_index': endSentenceIndex,
      'duration_seconds': durationSeconds,
      'speech_rate': speechRate,
      'playback_mode': playbackMode.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
    if (id.isNotEmpty) json['id'] = id;
    return json;
  }
}
