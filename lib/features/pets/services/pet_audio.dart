import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../../services/error_reporter.dart';

/// 宠物音效 + 触感统一封装（2026-09-24 2D 表现层定版）
///
/// 沿用 `games/shared/game_audio.dart` 的既有范式，**不新增任何依赖**：
/// `audioplayers: ^6.1.0` 已在 pubspec（游戏音效在用），触感来自
/// `flutter/services.dart`（框架自带，游戏模块同款用法）。
///
/// 音效文件为 node 程序合成的 WAV（无版权），落在已声明的 `assets/audio/`
/// 目录内，故 pubspec 不需要任何改动。单例复用、同一时刻只播一个短促 SFX；
/// 播放失败一律静默降级并只上报一次——缺音效绝不能挡住喂食/抚摸主流程。
class PetAudio {
  PetAudio._();

  static final PetAudio instance = PetAudio._();

  final AudioPlayer _player = AudioPlayer();

  /// 资源缺失属全局性问题，逐次上报会刷屏
  bool _failureReported = false;

  Future<void> _play(String file) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$file'));
    } catch (e, st) {
      if (!_failureReported) {
        _failureReported = true;
        ErrorReporter.report(e, st, module: 'pets', level: 'warning');
      }
    }
  }

  /// 进食：三声咀嚼 + 轻触感
  void eat() {
    _play('pet_eat.wav');
    HapticFeedback.lightImpact();
  }

  /// 被抚摸：呼噜 + 轻触感
  void petted() {
    _play('pet_petted.wav');
    HapticFeedback.lightImpact();
  }

  /// 开心：三音上行铃音 + 中触感
  void happy() {
    _play('pet_happy.wav');
    HapticFeedback.mediumImpact();
  }

  /// 进化演出：上升扫频撞钟 + 重触感（本模块唯一的强反馈时刻）
  void evolve() {
    _play('pet_evolve.wav');
    HapticFeedback.heavyImpact();
  }
}
