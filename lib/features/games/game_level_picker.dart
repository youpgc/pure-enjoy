import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'game_play_screen.dart';
import 'models/game_level_model.dart';
import 'models/game_model.dart';
import 'models/match3_mode.dart';

/// 选关底部弹窗（抽出自 GameHallPage，统一复用）。
///
/// 交互遵循用户拍板：**模式为主，先选模式再选关**。
/// - 消消乐（match3）：顶部先列出 6 个模式（每个带「已通关数/5」进度徽标），
///   点选某模式后下方列出该模式的 5 个关卡；模式之间互不锁定，可自由切换。
/// - 其它游戏：直接平铺关卡列表。
///
/// 锁逻辑沿用既有规则（[GameModel.levelSelectMode]）：
/// - free：全部关卡直接可挑战。
/// - gated：模式内的关卡按关序解锁——已通关可重挑战，最新未通关关卡(frontier)
///   可解锁，其余上锁。
class GameLevelPicker {
  const GameLevelPicker._();

  /// 弹出选关弹窗；选中关卡后跳转 [GamePlayScreen]。
  ///
  /// [initialMode] 仅 match3 生效：进入时预选指定模式（主界面模式网格深链用）。
  static Future<void> show({
    required BuildContext context,
    required GameModel game,
    required List<GameLevelModel> levels,
    required Set<String> clearedIds,
    Match3Mode? initialMode,
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
        initialMode: initialMode,
      ),
    );
  }
}

class _PickerBody extends StatefulWidget {
  final GameModel game;
  final List<GameLevelModel> levels;
  final Set<String> clearedIds;
  final Match3Mode? initialMode;

  const _PickerBody({
    required this.game,
    required this.levels,
    required this.clearedIds,
    this.initialMode,
  });

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  /// 仅 match3 使用：当前选中的模式（进入时默认停在第一个还没全通的模式）
  Match3Mode? _selectedMode;

  @override
  void initState() {
    super.initState();
    if (widget.game.code == 'match3') {
      // 「还没全通」= 该模式已通关数 < 该模式实际关卡数（不写死每模式关卡数，
      // 后台增删关卡后自动跟随；无关卡的模式自然被跳过）。
      _selectedMode = widget.initialMode ??
          Match3Mode.values
              .where((m) => _modeCleared(m) < _levelsOfMode(m).length)
              .firstOrNull ??
          Match3Mode.values.first;
    }
  }

  /// match3 该模式下的关卡（按 level_no 升序）
  List<GameLevelModel> _levelsOfMode(Match3Mode mode) {
    final list = widget.levels
        .where((l) => parseMatch3Mode(l.config, l.levelNo) == mode)
        .toList()
      ..sort((a, b) => a.levelNo.compareTo(b.levelNo));
    return list;
  }

  /// 某模式已通关数量
  int _modeCleared(Match3Mode mode) {
    final ids = _levelsOfMode(mode).map((l) => l.id).toSet();
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
    final isMatch3 = widget.game.code == 'match3';
    final list = isMatch3 && _selectedMode != null
        ? _levelsOfMode(_selectedMode!)
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
              '选择关卡 · ${widget.game.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (isMatch3 && _selectedMode != null) _modeHeader(),
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

  /// 模式顶部条（静态，仅展示当前所选模式，不提供模式切换交互）：
  /// 由主界面模式网格深链进入时已指定模式，选关弹窗内无需再切模式。
  Widget _modeHeader() {
    final mode = _selectedMode!;
    final cleared = _modeCleared(mode);
    final total = _levelsOfMode(mode).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: <Widget>[
          Icon(mode.icon, color: mode.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mode.label,
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
