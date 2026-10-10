import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../../../services/error_reporter.dart';

/// 游戏音效 + 触感反馈统一封装。
///
/// 所有音效为程序合成 WAV（assets/audio/），无版权、体积小、不含 BGM。
/// 单例复用：全局可静音；同一时刻仅播一个音效（短促 SFX，无需叠加）。
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  /// 播放器池（2026-10-10 音效断播修复）：单实例连续 stop→play 存在竞态
  /// （上一个 play 未完成即被 stop 截断，表现为时有时无/断播），改为多实例
  /// 轮询——短音效各自独立播放互不打断；池大小 4 可覆盖最高连发密度。
  final List<AudioPlayer> _pool =
      List.generate(4, (_) => AudioPlayer());
  int _nextSlot = 0;
  bool _muted = false;
  // 播放失败只上报一次：资源缺失属全局性问题，逐次上报会刷屏
  bool _playFailureReported = false;

  /// 是否静音（UI 开关写回）
  bool get muted => _muted;

  /// 设置静音。开启静音后不播任何音效与触感。
  void setMuted(bool value) => _muted = value;

  Future<void> _play(String file) async {
    if (_muted) return;
    final player = _pool[_nextSlot];
    _nextSlot = (_nextSlot + 1) % _pool.length;
    try {
      await player.stop();
      await player.play(AssetSource('audio/$file'));
    } catch (e, st) {
      // 资源缺失或播放失败时静默降级，不影响游戏逻辑；仅首次上报便于发现打包遗漏
      if (!_playFailureReported) {
        _playFailureReported = true;
        ErrorReporter.report(e, st, module: 'games', level: 'warning');
      }
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

  /// 俄罗斯方块：旋转（复用 select 音，轻短；缺资源时静默降级）
  void rotate() => _play('tetris_rotate.wav');

  /// 俄罗斯方块：移动（轻 tap 音）
  void move() => _play('tap.wav');

  /// 俄罗斯方块：锁定落定（非消行锁定）
  void lock() => _play('select.wav');

  /// 俄罗斯方块：消行（1-3 行轻快音，4 行 TETRIS 重音；缺资源回退 match）
  void lineClear(int lines) =>
      _play(lines >= 4 ? 'tetris_tetris.wav' : 'tetris_clear.wav');

  /// 俄罗斯方块：升级（marathon/blitz 等级跃迁；缺资源回退 merge）
  void levelUp() => _play('tetris_levelup.wav');

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
