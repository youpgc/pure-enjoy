import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 游戏音效 + 触感反馈统一封装。
///
/// 所有音效为程序合成 WAV（assets/audio/），无版权、体积小、不含 BGM。
/// 单例复用：全局可静音；同一时刻仅播一个音效（短促 SFX，无需叠加）。
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;

  /// 是否静音（UI 开关写回）
  bool get muted => _muted;

  /// 设置静音。开启静音后不播任何音效与触感。
  void setMuted(bool value) => _muted = value;

  Future<void> _play(String file) async {
    if (_muted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/$file'));
    } catch (_) {
      // 资源缺失或播放失败时静默降级，不影响游戏逻辑
    }
  }

  /// 点击方块
  void tap() => _play('tap.wav');

  /// 选中/放入槽位
  void select() => _play('select.wav');

  /// 三连消除
  void match() => _play('match.wav');

  /// 2048 合并
  void merge() => _play('merge.wav');

  /// 使用道具
  void prop() => _play('prop.wav');

  /// 通关
  void win() => _play('win.wav');

  /// 失败
  void fail() => _play('fail.wav');

  /// 触感反馈（静音时同样抑制）
  void haptic(GameHaptic type) {
    if (_muted) return;
    switch (type) {
      case GameHaptic.light:
        HapticFeedback.lightImpact();
        break;
      case GameHaptic.medium:
        HapticFeedback.mediumImpact();
        break;
      case GameHaptic.heavy:
        HapticFeedback.heavyImpact();
        break;
      case GameHaptic.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }
}

/// 触感强度
enum GameHaptic { light, medium, heavy, selection }
