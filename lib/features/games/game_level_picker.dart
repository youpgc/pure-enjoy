import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'game_play_helpers.dart';
import 'services/game_score_service.dart';
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
  final ScrollController _scroll = ScrollController();

  /// 关卡清单与初始定位项（frontier）在 initState 一次算定
  late final List<GameLevelModel> _list;
  late int _frontierIdx;

  /// 已通关关卡集合：以调用方传入集合为初值，**弹窗打开时强制重拉**——
  /// 对局完成返回后主界面虽会 force 刷新，但结算上报与刷新可能竞态，
  /// 选关打开时再拉一次保证已通关/锁状态数据最新（2026-09-10 用户反馈）。
  late Set<String> _cleared;

  /// ListTile 默认高度（56）；用于打开时滚动定位的偏移估算
  static const double _itemExtent = 56.0;

  @override
  void initState() {
    super.initState();
    _cleared = {...widget.clearedIds};
    _list = widget.mode != null
        ? _levelsOfModeId(widget.mode!.id)
        : widget.levels;
    _frontierIdx = _frontierIdxOf(_list);
    // 打开弹窗后把滚动条定位到最新关卡（居中显示，钳制在可滚动范围内）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target =
          _frontierIdx * _itemExtent - _scroll.position.viewportDimension / 2 + _itemExtent / 2;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
    _refreshCleared();
  }

  /// 强制重拉已通关集合；合并成功后重算 frontier 并重新居中定位
  Future<void> _refreshCleared() async {
    try {
      final fresh =
          await GameScoreService.instance.fetchClearedLevelIds(widget.game.id);
      if (!mounted || fresh.isEmpty) return;
      setState(() {
        _cleared.addAll(fresh);
        _frontierIdx = _frontierIdxOf(_list);
      });
      // frontier 前移时重新居中
      if (_scroll.hasClients) {
        final target = _frontierIdx * _itemExtent -
            _scroll.position.viewportDimension / 2 +
            _itemExtent / 2;
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    } catch (_) {
      // 刷新失败保持调用方传入的集合（不影响弹窗展示）
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    return _cleared.where(ids.contains).length;
  }

  /// 列表中「最新可挑战关卡(frontier)」索引（gated 用）
  int _frontierIdxOf(List<GameLevelModel> list) {
    int maxCleared = -1;
    for (int i = 0; i < list.length; i++) {
      if (_cleared.contains(list[i].id)) maxCleared = i;
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
    final list = _list;
    final frontierIdx = _frontierIdx;

    bool canSelect(int i) {
      if (widget.game.levelSelectMode == 'free') return true; // 直接选关
      if (_cleared.contains(list[i].id)) return true; // 已通关可重挑战
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
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: list.asMap().entries.map((entry) {
                final i = entry.key;
                final lv = entry.value;
                final selectable = canSelect(i);
                final cleared = _cleared.contains(lv.id);
                return ListTile(
                  leading: !selectable
                      ? const Icon(Icons.lock_outline, color: AppTheme.neutral500)
                      : (cleared
                          ? const Icon(Icons.check_circle, color: AppTheme.success)
                          : null),
                  // 关卡名种子自带「游戏·模式」前缀（如「2048·经典模式 L001」），
                  // 弹窗标题已含归属（模式深链=「选择关卡·模式名」，否则=游戏名），
                  // 行内剥掉已展示的前缀避免重复：模式深链剩「L001」，无模式深链剩「经典模式 L001」。
                  title: Text(_levelItemTitle(lv)),
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

  /// 关卡行标题：剥掉关卡名里已在弹窗标题展示过的前缀，避免重复。
  /// 种子格式「游戏·模式 L001」：模式深链（标题含模式名）→「L001」；
  /// 无模式深链（标题仅游戏名）→「模式 L001」；非标准前缀原样返回。
  String _levelItemTitle(GameLevelModel lv) {
    var name = lv.name;
    final gamePrefix = '${widget.game.name}·';
    if (name.startsWith(gamePrefix)) name = name.substring(gamePrefix.length);
    final mode = widget.mode;
    if (mode != null) {
      final modePrefix = '${mode.name} ';
      if (name.startsWith(modePrefix)) name = name.substring(modePrefix.length);
    }
    return name;
  }

  /// 模式顶部条（由主界面模式网格深链进入时已指定模式）
  Widget _modeHeaderGeneric() {
    final mode = widget.mode!;    final cleared = _modeClearedById(mode.id);
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
