import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../services/api_client.dart';
import '../../../services/session_manager.dart';
import '../models/novel_model.dart';

/// TTS/听书服务
///
/// 使用 flutter_tts 插件实现语音合成
/// 后台播放和通知功能暂未实现（需要 audio_service + just_audio）
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  String? get _userId => SessionManager.instance.currentUserId;

  // TTS 状态
  bool _isPlaying = false;
  bool _isInitialized = false;
  double _speechRate = 1.0;
  int? _timerMinutes;
  TtsPlaybackMode _playbackMode = TtsPlaybackMode.sentence;
  String? _currentSentence;
  int _currentSentenceIndex = 0;
  DateTime? _playbackStartTime;
  Timer? _timer;
  String _currentNovelId = '';
  String _currentChapterId = '';
  List<String> _sentences = [];
  int _currentPlaybackIndex = 0;

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  int? get timerMinutes => _timerMinutes;
  TtsPlaybackMode get playbackMode => _playbackMode;
  String? get currentSentence => _currentSentence;
  int get currentSentenceIndex => _currentSentenceIndex;

  // 状态监听器
  final List<void Function()> _stateListeners = [];

  void addStateListener(void Function() listener) {
    _stateListeners.add(listener);
  }

  void removeStateListener(void Function() listener) {
    _stateListeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _stateListeners) {
      listener();
    }
  }

  /// 初始化 TTS
  /// 返回是否成功，如果设备不支持中文 TTS 则返回 false
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      // 检测可用的语言
      final languages = await _flutterTts.getLanguages;
      if (kDebugMode) debugPrint('TTS 可用语言: $languages');

      // 尝试设置中文，如果失败尝试其他中文变体
      var langSet = await _flutterTts.setLanguage('zh-CN');
      if (langSet != 1 && langSet != true) {
        langSet = await _flutterTts.setLanguage('zh-CN');
      }
      if (langSet != 1 && langSet != true) {
        langSet = await _flutterTts.setLanguage('cmn');
      }
      if (langSet != 1 && langSet != true) {
        if (kDebugMode) debugPrint('TTS 不支持中文语音');
        return false;
      }

      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      // 使用 false 避免 speak() 阻塞，通过 completion handler 驱动下一句
      await _flutterTts.awaitSpeakCompletion(false);

      _flutterTts.setCompletionHandler(() {
        if (kDebugMode) debugPrint('TTS 播放完成，触发下一句');
        _onSpeakComplete();
      });

      _flutterTts.setErrorHandler((msg) {
        if (kDebugMode) debugPrint('TTS Error: $msg');
        _isPlaying = false;
        _notifyListeners();
      });

      _isInitialized = true;
      _notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS 初始化失败: $e');
      return false;
    }
  }

  /// 播放文本
  Future<bool> speak(String text) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        if (kDebugMode) debugPrint('TTS 初始化失败，无法播放');
        return false;
      }
    }

    try {
      _currentSentence = text;
      _isPlaying = true;
      _playbackStartTime = DateTime.now();
      _notifyListeners();

      final result = await _flutterTts.speak(text);
      if (result != 1 && result != true) {
        if (kDebugMode) debugPrint('TTS speak() 返回失败: $result');
        _isPlaying = false;
        _notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS 播放失败: $e');
      _isPlaying = false;
      _notifyListeners();
      return false;
    }
  }

  /// 暂停播放
  Future<bool> pause() async {
    try {
      await _flutterTts.pause();
      _isPlaying = false;
      _notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 继续播放
  Future<bool> resume() async {
    if (_currentSentence != null && _currentSentence!.isNotEmpty) {
      return speak(_currentSentence!);
    }
    return false;
  }

  /// 停止播放
  Future<bool> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
      _playbackStartTime = null;
      _timer?.cancel();
      _timer = null;
      _notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 3.0);
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
    _notifyListeners();
  }

  /// 设置播放模式
  Future<void> setPlaybackMode(TtsPlaybackMode mode) async {
    _playbackMode = mode;
    _notifyListeners();
  }

  /// 设置定时关闭
  Future<void> setTimer(int? minutes) async {
    _timerMinutes = minutes;
    _notifyListeners();

    _timer?.cancel();
    if (minutes != null && minutes > 0) {
      _timer = Timer(Duration(minutes: minutes), () {
        stop();
      });
    }
  }

  /// 将章节内容分割为句子列表
  List<String> splitSentences(String content) {
    final regExp = RegExp(r'[。！？\n]+');
    return content
        .split(regExp)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 播放整章内容
  Future<void> playChapter(
    String novelId,
    String chapterId,
    String content,
    int startIndex,
  ) async {
    _currentNovelId = novelId;
    _currentChapterId = chapterId;
    _sentences = splitSentences(content);
    if (_sentences.isEmpty || startIndex >= _sentences.length) return;

    _currentPlaybackIndex = startIndex;
    _isPlaying = true;
    _notifyListeners();

    await _playNextSentence();
  }

  /// 播放下一句
  Future<void> _playNextSentence() async {
    if (!_isPlaying || _currentPlaybackIndex >= _sentences.length) {
      await _logPlayback(_currentNovelId, _currentChapterId);
      _isPlaying = false;
      _notifyListeners();
      return;
    }

    _currentSentenceIndex = _currentPlaybackIndex;
    _currentSentence = _sentences[_currentPlaybackIndex];
    _notifyListeners();

    await speak(_currentSentence!);
  }

  /// 播放完成回调
  void _onSpeakComplete() {
    if (!_isPlaying) return;

    _currentPlaybackIndex++;

    if (_currentPlaybackIndex < _sentences.length) {
      _playNextSentence();
    } else {
      _logPlayback(_currentNovelId, _currentChapterId);
      _isPlaying = false;
      _notifyListeners();
    }
  }

  /// 上一句
  Future<void> previousSentence() async {
    if (_currentPlaybackIndex > 0) {
      _currentPlaybackIndex--;
      await _flutterTts.stop();
      await _playNextSentence();
    }
  }

  /// 下一句
  Future<void> nextSentence() async {
    if (_currentPlaybackIndex < _sentences.length - 1) {
      _currentPlaybackIndex++;
      await _flutterTts.stop();
      await _playNextSentence();
    }
  }

  /// 保存用户 TTS 偏好到云端
  Future<bool> savePreferences() async {
    final userId = _userId;
    if (userId == null) return false;

    final result = await ApiClient.patchByFilter(
      'users',
      filters: {'id': 'eq.$userId'},
      body: {
        'tts_speech_rate': _speechRate,
        'tts_timer_minutes': _timerMinutes,
        'tts_playback_mode': _playbackMode.name,
      },
    );
    return result.isSuccess;
  }

  /// 从云端加载用户 TTS 偏好
  Future<void> loadPreferences() async {
    final userId = _userId;
    if (userId == null) return;

    final result = await ApiClient.get(
      'users',
      filters: {
        'id': 'eq.$userId',
        'is_deleted': 'eq.false',
      },
      select: 'tts_speech_rate,tts_timer_minutes,tts_playback_mode',
      limit: 1,
    );

    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      final data = result.data!.first;
      _speechRate = (data['tts_speech_rate'] as num?)?.toDouble() ?? 1.0;
      _timerMinutes = data['tts_timer_minutes'] as int?;
      final modeStr = data['tts_playback_mode'] as String?;
      if (modeStr != null) {
        _playbackMode = TtsPlaybackMode.values.firstWhere(
          (e) => e.name == modeStr,
          orElse: () => TtsPlaybackMode.sentence,
        );
      }

      if (_isInitialized) {
        await _flutterTts.setSpeechRate(_speechRate);
      }
      _notifyListeners();
    }
  }

  /// 记录 TTS 播放日志
  Future<bool> _logPlayback(
    String novelId,
    String chapterId,
  ) async {
    final userId = _userId;
    if (userId == null) return false;

    final duration = _playbackStartTime != null
        ? DateTime.now().difference(_playbackStartTime!).inSeconds
        : 0;

    final log = TtsPlaybackLog(
      id: '',
      userId: userId,
      novelId: novelId,
      chapterId: chapterId,
      startSentenceIndex: _currentSentenceIndex,
      endSentenceIndex: _currentPlaybackIndex < _sentences.length ? _currentPlaybackIndex : null,
      durationSeconds: duration > 0 ? duration : null,
      speechRate: _speechRate,
      playbackMode: _playbackMode,
      createdAt: DateTime.now(),
    );

    final result = await ApiClient.post('tts_playback_logs', log.toJson());
    return result.isSuccess;
  }

  /// 释放资源
  Future<void> dispose() async {
    _timer?.cancel();
    await _flutterTts.stop();
    _stateListeners.clear();
  }
}