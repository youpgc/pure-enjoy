import 'package:flutter/material.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';

import '../models/game_dimension_model.dart';
import '../models/game_model.dart';
import '../services/game_reward_service.dart';
import '../services/game_service.dart';
import '../shared/game_local_loading.dart';

/// 结算页（底部弹窗）：**成绩区立即渲染**，「积分结算」部分局部 loading，
/// 完成后原地渲染奖励明细（规范：禁止整页 loading）。
///
/// 弹窗不可点遮罩关闭、不可拖拽；加载期间无任何可点击操作 → 禁其他操作。
/// 结算（成绩上报 + 奖励发放）由 [settleFuture] 在弹窗内异步驱动。
///
/// [scoreOnly] 为 true 时（默认流程：配置关闭/异常），奖励区展示「仅记录成绩」
/// 说明而非奖励明细（参考文档 §16.2）。
class GameSettlementSheet extends StatefulWidget {
  final GameModel game;
  final bool cleared;
  final Map<String, num> scoreValuesByCode;
  final Future<GameSettlementResult> settleFuture;

  /// 默认流程标记：true = 隐藏奖励明细，仅展示成绩。
  final bool scoreOnly;

  /// 无尽模式会话结算：标题显示「无尽模式 · 结算」（无通关/失败语义），
  /// 成绩区不显示「未达成通关条件」提示。
  final bool endless;
  final VoidCallback? onReplay;
  final VoidCallback? onNext;
  final bool canNext;
  final VoidCallback? onExit;
  final void Function(GameSettlementResult? result) onDismiss;

  const GameSettlementSheet({
    super.key,
    required this.game,
    required this.cleared,
    required this.scoreValuesByCode,
    required this.settleFuture,
    this.scoreOnly = false,
    this.endless = false,
    this.onReplay,
    this.onNext,
    this.canNext = false,
    this.onExit,
    required this.onDismiss,
  });

  @override
  State<GameSettlementSheet> createState() => _GameSettlementSheetState();
}

class _GameSettlementSheetState extends State<GameSettlementSheet> {
  bool _loading = true;
  GameSettlementResult? _result;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    widget.settleFuture.then((r) {
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    }).catchError((Object e) {
      if (!mounted) return;
      debugPrint('[SettlementSheet] 结算失败：$e');
      setState(() {
        _errored = true;
        _loading = false;
      });
    });
  }

  void _dismiss() {
    widget.onDismiss(_result);
    if (mounted) Navigator.of(context).pop();
  }

  String _fmtDim(List<GameDimensionModel> dims, String code, num value) {
    if (code == 'duration_ms') {
      final sec = (value / 1000).floor();
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final dim = dims.where((d) => d.code == code).firstOrNull;
    return '${value.toInt()}${dim?.unit ?? ''}';
  }

  /// 标题行：cleared 立即可知，无需等结算完成
  Widget _buildTitle() {
    final result = _result;
    final settled = !_loading && !_errored && result != null;
    // 无尽模式会话结算：无通关/失败语义，固定绿色「无尽模式 · 结算」
    if (widget.endless) {
      return Row(
        children: <Widget>[
          const Icon(Icons.check_circle, color: AppTheme.success),
          const SizedBox(width: 8),
          Text('无尽模式 · 结算',
              style: Theme.of(context).textTheme.titleLarge),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Icon(
          !widget.cleared
              ? Icons.cancel
              : (!settled
                  ? Icons.check_circle
                  : (result.hasGranted ? Icons.emoji_events : Icons.check_circle)),
          color: !widget.cleared ? AppTheme.error : AppTheme.success,
        ),
        const SizedBox(width: 8),
        Text(
          !widget.cleared ? '挑战失败' : '通关',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  /// 成绩区：立即渲染（不等待结算）
  Widget _buildScoreSection(List<GameDimensionModel> dims) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('本次成绩', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.scoreValuesByCode.entries
              .map((e) => Chip(
                    label: Text(
                        '${_dimName(dims, e.key)}  ${_fmtDim(dims, e.key, e.value)}'),
                  ))
              .toList(),
        ),
        if (!widget.cleared)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '未达成通关条件，本次无奖励',
              style: TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// 积分结算区：加载中局部 loading / 失败局部错误 / 完成渲染明细
  Widget _buildRewardSection(List<GameDimensionModel> dims) {
    // 局部 loading：仅积分结算部分等待
    if (_loading) {
      return const GameLocalLoading(label: '积分结算中…');
    }

    // 结算失败：成绩已记录但奖励发放异常（错误只占奖励区，可重试/退出）
    if (_errored || _result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('奖励结算异常，成绩已记录；可稍后重试或返回大厅。',
                    style: TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            ],
          ),
        ],
      );
    }

    final result = _result!;

    // 默认流程：只展示说明，不展示奖励明细
    if (widget.scoreOnly) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.neutral500.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: AppTheme.neutral500, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '默认流程（配置未开启或异常）：本次仅记录成绩，不发放积分与成就',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // 单日游戏奖励是否已达上限（命中上限的奖励项 reason 含「上限」）
    final hitCap = result.items.any(
      (i) => i.reason != null && i.reason!.contains('上限'),
    );

    // 仅展示「实际获得的明细」；通关奖励不论是否获得都展示（kind=level_clear），
    // 其余未获得的（已领取 / 不相关）不展示，避免结算页堆砌无效行。
    final shown = result.items
        .where((i) => i.granted || i.kind == 'level_clear')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('奖励明细', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Text('本次无奖励获得',
              style: TextStyle(fontSize: 13, color: AppTheme.neutral500))
        else
          ...shown.map((item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.granted ? Icons.check : Icons.close,
                  color:
                      item.granted ? AppTheme.success : AppTheme.neutral500,
                  size: 18,
                ),
                title: Text(item.label),
                subtitle: item.granted ? null : Text(item.reason ?? ''),
                trailing: Text(
                  item.granted ? '+${item.points}' : '0',
                  style: TextStyle(
                    color: item.granted
                        ? AppTheme.success
                        : AppTheme.neutral500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
        if (hitCap) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '今日游戏奖励已达上限，本次积分暂未发放；明日上限刷新后，重新通关即可获得',
                    style: TextStyle(color: AppTheme.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text('本局获得积分', style: TextStyle(fontSize: 16)),
            Text(
              '+${result.totalPoints}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = GameService.instance.cachedConfig.dimensionsOf(widget.game.id);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTitle(),
          const SizedBox(height: 16),
          // 成绩区：立即渲染（不等结算）
          _buildScoreSection(dims),
          const SizedBox(height: 16),
          // 积分结算区：局部 loading / 局部错误 / 明细（scoreOnly 也在本区收敛）
          _buildRewardSection(dims),
          const SizedBox(height: 16),
          // 操作按钮：结算完成/失败后才可点（加载期间禁其他操作）
          if (!_loading)
            Row(
              children: <Widget>[
                if (widget.onReplay != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _dismiss();
                        widget.onReplay!();
                      },
                      child: const Text('再玩一次'),
                    ),
                  ),
                if (widget.canNext && widget.onNext != null) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _dismiss();
                        widget.onNext!();
                      },
                      child: const Text('下一关'),
                    ),
                  ),
                ],
              ],
            ),
          if (!_loading && widget.onExit != null)
            TextButton(
              onPressed: () {
                _dismiss();
                widget.onExit!();
              },
              child: const Text('返回大厅'),
            ),
        ],
      ),
    );
  }
}

String _dimName(List<GameDimensionModel> dims, String code) {
  for (final d in dims) {
    if (d.code == code) return d.name;
  }
  // 维度未配置时的中文兜底（如 match3 结算注入的 level 关序维度）
  const fallback = <String, String>{
    'level': '关卡',
    'score': '得分',
    'moves': '步数',
    'duration_ms': '用时',
  };
  return fallback[code] ?? code;
}
