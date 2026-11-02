import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pure_enjoy/core/theme/app_theme.dart';
import 'package:pure_enjoy/core/widgets/widgets.dart';

import '../models/game_mode_model.dart';

/// 自由模式选档弹窗（常驻经典）。
///
/// 表单式配置：玩法/难度单选 + 开始按钮，
/// 不再点击即进游戏；match3 另有方块类型（4/5/6 色）单选。
/// 记住上次选择：按「游戏 + 模式」维度持久化上次选中的
/// 玩法与色数（SharedPreferences），再次打开默认回填；无记录时回落
/// 首个档位 + 5 色。通关条件阈值存后台 `game_modes.config.tiers[].config.random`
/// （match3 按色数分支 {"4":[..],"5":[..],"6":[..]}，其余游戏纯 [min,max]），
/// 点「开始游戏」时由 App 在对应区间内随机产出实际条件——阈值不在代码硬编码；
/// 方块类型由玩家选择（引擎钳制 3..6，可选 4/5/6）。
/// 选中返回 {...tier, config: <随机后的最终关卡 config>}，取消返回 null。
class GameFreeModeSheet {
  const GameFreeModeSheet._();

  /// 方块类型可选项（引擎 clamp 3..6；可选 4/5/6，仅 match3 展示）。
  static const List<int> _typeOptions = <int>[4, 5, 6];

  /// 上次选择持久化键前缀（按「游戏 + 模式」维度隔离——乱斗与自由
  /// 是两个拆开的模式，各自记忆）：`{prefix}{gameCode}_{modeCode}`。
  static const String _prefTierKey = 'game_free_mode_last_tier_';
  static const String _prefTypesKey = 'game_free_mode_last_types_';

  /// 弹出选档表单；返回选中档位（config 已完成随机化），取消返回 null。
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required GameModeModel mode,
    required String gameCode,
  }) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FreeModeFormBody(mode: mode, gameCode: gameCode),
    );
  }

  /// 解析档位清单（后台可配；解析异常按空清单处理，展示占位提示）。
  static List<Map<String, dynamic>> tiersOf(GameModeModel mode) {
    try {
      final raw = mode.config['tiers'];
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// 在后台配置的阈值区间内随机产出实际通关条件，
  /// 摊平进关卡 config（random 缺失/结构异常时原值透传，不阻塞开局）。
  ///
  /// 阈值区间两种形态：
  /// - `[min,max]`：与色数无关（sheep/g2048/tetris 等沿用）；
  /// - `{"4":[..],"5":[..],"6":[..]}`：match3 按色数分支（产出率随色数量变，
  ///   §20 容量模型），按 [types] 取对应分支；缺该键时回落 '5'，再缺取首项。
  static Map<String, dynamic> resolveTierConfig(
    Map<String, dynamic> tier, {
    int? types,
  }) {
    final src = tier['config'];
    final out = (src is Map<String, dynamic>)
        ? Map<String, dynamic>.from(src)
        : <String, dynamic>{};
    final rng = Random();
    final random = out.remove('random');
    if (random is Map) {
      random.forEach((key, range) {
        // 按色数分支形态：{"4":[..],"5":[..],"6":[..]}
        if (range is Map) {
          dynamic branch;
          if (types != null && range.containsKey('$types')) {
            branch = range['$types'];
          } else if (range.containsKey('5')) {
            branch = range['5'];
          } else if (range.isNotEmpty) {
            branch = range.values.first;
          }
          _rollRange(branch, out, key.toString(), rng);
          return;
        }
        // 纯区间形态：[min,max]
        _rollRange(range, out, key.toString(), rng);
      });
    }
    return out;
  }

  /// 区间内随机取整写入 [out]；非法区间静默跳过（不阻塞开局）。
  static void _rollRange(
      dynamic range, Map<String, dynamic> out, String key, Random rng) {
    if (range is List &&
        range.length == 2 &&
        range[0] is num &&
        range[1] is num) {
      final lo = (range[0] as num).toInt();
      final hi = (range[1] as num).toInt();
      if (hi >= lo) {
        out[key] = lo + rng.nextInt(hi - lo + 1);
      }
    }
  }
}

class _FreeModeFormBody extends StatefulWidget {
  final GameModeModel mode;

  /// 所属游戏 code（上次选择持久化键的隔离维度）。
  final String gameCode;

  const _FreeModeFormBody({required this.mode, required this.gameCode});

  @override
  State<_FreeModeFormBody> createState() => _FreeModeFormBodyState();
}

class _FreeModeFormBodyState extends State<_FreeModeFormBody> {
  late final List<Map<String, dynamic>> _tiers;
  Map<String, dynamic>? _selectedTier;

  /// 持久化键后缀：`{gameCode}_{mode.code}`（乱斗与自由各自记忆）。
  String _prefSuffix(String gameCode) => '${gameCode}_${widget.mode.code}';

  /// 方块类型选择（仅 match3 玩法类档位展示；默认 5 色）。
  int _selectedTypes = 5;

  /// 是否展示方块类型选择：档位 config 携带 `mode` 键 = match3 玩法类档位；
  /// 携带 `types` 键 = 色数由后台固定（乱斗固定 5 色），不展示选择器。
  bool get _showTypes {
    final cfg = _selectedTier?['config'];
    return cfg is Map &&
        cfg.containsKey('mode') &&
        !cfg.containsKey('types');
  }

  @override
  void initState() {
    super.initState();
    _tiers = GameFreeModeSheet.tiersOf(widget.mode);
    // 默认：首个档位 + 5 色；有上次选择记录则回填（异步读取，缺失即保持默认）。
    _selectedTier = _tiers.isNotEmpty ? _tiers.first : null;
    _restoreLastChoice();
  }

  /// 回填上次选择：玩法按 tier key 匹配（后台档位被删/改 key 时安全回落默认）。
  Future<void> _restoreLastChoice() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      final lastTier = sp.getString(
          '${GameFreeModeSheet._prefTierKey}${_prefSuffix(widget.gameCode)}');
      if (lastTier != null) {
        for (final t in _tiers) {
          if (t['key']?.toString() == lastTier) {
            _selectedTier = t;
            break;
          }
        }
      }
      final lastTypes = sp.getInt(
          '${GameFreeModeSheet._prefTypesKey}${_prefSuffix(widget.gameCode)}');
      if (lastTypes != null &&
          GameFreeModeSheet._typeOptions.contains(lastTypes)) {
        _selectedTypes = lastTypes;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // 本地持久化失败不阻塞选档，保持默认值即可。
    }
  }

  void _start() {
    final tier = _selectedTier;
    if (tier == null) return;
    // 随机化须携带所选色数：阈值按 4/5/6 色分支（产出率随色数量变）。
    final config = GameFreeModeSheet.resolveTierConfig(
      tier,
      types: _showTypes ? _selectedTypes : null,
    );
    if (_showTypes) {
      config['types'] = _selectedTypes;
    }
    // 记住本次选择为下次默认（持久化失败不影响开局）。
    unawaited(_saveLastChoice(tier));
    Navigator.of(context).pop(<String, dynamic>{
      ...tier,
      'config': config,
    });
  }

  Future<void> _saveLastChoice(Map<String, dynamic> tier) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          '${GameFreeModeSheet._prefTierKey}${_prefSuffix(widget.gameCode)}',
          tier['key']?.toString() ?? '');
      if (_showTypes) {
        await sp.setInt(
            '${GameFreeModeSheet._prefTypesKey}${_prefSuffix(widget.gameCode)}',
            _selectedTypes);
      }
    } catch (_) {
      // 持久化失败静默：下次回落默认选项。
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      bottomSpacing: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${widget.mode.name} · 选择玩法',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('选定配置后开始游戏，通关按所选内容获得积分',
              style: TextStyle(fontSize: 12, color: AppTheme.neutral500)),
          const SizedBox(height: 14),
          if (_tiers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无可用玩法',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.neutral500)),
              ),
            )
          else ...<Widget>[
            // 玩法单选（按钮组，选中高亮）
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final t in _tiers)
                  _SelectButton(
                    label: _tierLabel(t),
                    selected: identical(t, _selectedTier),
                    onTap: () => setState(() => _selectedTier = t),
                  ),
              ],
            ),
            // 方块类型单选（仅 match3 玩法类档位）
            if (_showTypes) ...<Widget>[
              const SizedBox(height: 14),
              const Text('方块类型',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final n in GameFreeModeSheet._typeOptions)
                    _SelectButton(
                      label: '$n 色',
                      selected: _selectedTypes == n,
                      onTap: () => setState(() => _selectedTypes = n),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            // 开始游戏（表单底部主操作）
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedTier == null ? null : _start,
                child: const Text('开始游戏'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// 玩法按钮文案：仅玩法名称，不展示积分（积分在结算页体现）。
  String _tierLabel(Map<String, dynamic> t) =>
      t['name']?.toString() ?? '玩法';
}

/// 单选按钮（按钮式单选框：选中主题色高亮填充，未选中灰底）。
class _SelectButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : AppTheme.neutral200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? scheme.onPrimary : AppTheme.neutral600,
          ),
        ),
      ),
    );
  }
}
