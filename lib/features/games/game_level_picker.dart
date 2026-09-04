import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'game_play_helpers.dart';
import 'game_play_screen.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'models/game_mode_model.dart';

/// 选关底部弹窗（抽出自 GameHallPage，统一复用）。
///
/// 交互（三游戏一致，模式为主）：
/// - 指定 [mode]（主界面模式网格深链进入）：直接列出该模式下的关卡（按 mode_id 过滤）。
/// - 无 [mode]（无后台模式游戏的「选择关卡」入口）：平铺全部关卡。
///
/// 锁逻辑沿用 [GameModel.levelSelectMode]：
/// - free：全部关卡直接可挑战。
/// - gated：模式内关卡按关序解锁——已通关可重挑战，最新未通关关卡(frontier)可解锁，其余上锁。
class GameLevelPicker {
  const GameLevelPicker._();

  /// 弹出选关弹窗；选中关卡后跳转 [GamePlayScreen]。
  ///
  /// [mode] 通用模式深链（2048/sheep/match3 等）：进入时直接列出该模式下的关卡。
  static Future<void> show({
    required BuildContext context,
    required GameModel game,
    required List<GameLevelModel> levels,
    required Set<String> clearedIds,
    GameModeModel? mode,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PickerBody(
        game: game,
        levels: levels,
        clearedIds: clearedIds,
        mode: mode,
      ),
    );
  }
}

class _PickerBody extends StatefulWidget {
  final GameModel game;
  final List<GameLevelModel> levels;
  final Set<String> clearedIds;
  final GameModeModel? mode;

  const _PickerBody({
    required this.game,
    required this.levels,
    required this.clearedIds,
    this.mode,
  });

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  /// 指定模式下的关卡（按 level_no 升序）
  List<GameLevelModel> _levelsOfModeId(String modeId) {
    final list = widget.levels
        .where((l) => l.modeId == modeId)
        .toList()
      ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
    return list;
  }

  /// 指定模式已通关数量
  int _modeClearedById(String modeId) {
    final ids = _levelsOfModeId(modeId).map((l) => l.id).toSet();
    return widget.clearedIds.where(ids.contains).length;
  }

  /// 列表中「最新可挑战关卡(frontier)」索引（gated 用）
  int _frontierIdx(List<GameLevelModel> list) {
    int maxCleared = -1;
    for (int i = 0; i < list.length; i++) {
      if (widget.clearedIds.contains(list[i].id)) maxCleared = i;
    }
    return maxCleared < 0 ? 0 : maxCleared + 1;
  }

  void _openLevel(GameLevelModel lv) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePlayScreen(game: widget.game, level: lv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.mode != null
        ? _levelsOfModeId(widget.mode!.id)
        : widget.levels;
    final frontierIdx = _frontierIdx(list);

    bool canSelect(int i) {
      if (widget.game.levelSelectMode == 'free') return true; // 直接选关
      if (widget.clearedIds.contains(list[i].id)) return true; // 已通关可重挑战
      return i == frontierIdx; // 最新可挑战关卡
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              widget.mode != null
                  ? '选择关卡 · ${widget.mode!.name}'
                  : '选择关卡 · ${widget.game.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.mode != null) _modeHeaderGeneric(),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: list.asMap().entries.map((entry) {
                final i = entry.key;
                final lv = entry.value;
                final selectable = canSelect(i);
                final cleared = widget.clearedIds.contains(lv.id);
                return ListTile(
                  leading: !selectable
                      ? const Icon(Icons.lock_outline, color: AppTheme.neutral500)
                      : (cleared
                          ? const Icon(Icons.check_circle, color: AppTheme.success)
                          : null),
                  title: Text(lv.name),
                  subtitle: cleared
                      ? const Text('已通关 · 可重挑战')
                      : (selectable
                          ? const Text('可选择挑战')
                          : const Text('未解锁 · 需先通关前置关卡')),
                  trailing: Icon(selectable ? Icons.chevron_right : Icons.lock),
                  enabled: selectable,
                  onTap: selectable ? () => _openLevel(lv) : null,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 模式顶部条（由主界面模式网格深链进入时已指定模式）
  Widget _modeHeaderGeneric() {
    final mode = widget.mode!;
    final cleared = _modeClearedById(mode.id);
    final total = _levelsOfModeId(mode.id).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: <Widget>[
          SvgPicture.asset(modeIconAsset(mode.icon),
              width: 22, height: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mode.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '已通关 $cleared/$total',
            style: const TextStyle(fontSize: 12, color: AppTheme.neutral500),
          ),
        ],
      ),
    );
  }
}
