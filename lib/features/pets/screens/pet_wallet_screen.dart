import 'package:flutter/material.dart';

import '../../../core/utils/event_bus.dart';
import '../../../core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/date_time_utils.dart';
import '../../profile/services/point_service.dart';
import '../services/pet_rpc.dart';
import '../services/pet_service.dart';
import '../utils/pet_errors.dart';

/// 金币钱包页（我的页「金币钱包」入口的独立落点，不进宠物主页）
///
/// 数据源（均本人 RLS 可读）：
/// - `pet_wallets`：余额行（gold_balance / total_earned / total_spent）；
///   行可能尚未创建（未发生过任何金币变动），按 0 兜底展示。
/// - `pet_wallet_records`：append-only 流水（delta / balance_after /
///   source_type / remark），倒序取最近 50 条。
/// - `pet_config.points_per_gold` + users 统计列 available_points：兑换区块的
///   汇率与可用积分（走轻量 GET，不触发 rpc_pet_summary 的初始包发放副作用）。
///
/// 兑换为**单向**（积分 → 金币，服务端 rpc_pet_exchange 同一事务双账本）；
/// 金币 → 积分禁止，页内不提供反向入口。
class PetWalletScreen extends StatefulWidget {
  const PetWalletScreen({super.key});

  @override
  State<PetWalletScreen> createState() => _PetWalletScreenState();
}

class _PetWalletScreenState extends State<PetWalletScreen> {
  static const int _kRecordLimit = 50;
  static const int _kDefaultPointsPerGold = 10;

  bool _loading = true;
  bool _enabled = true;
  String? _error;

  int _goldBalance = 0;
  int _totalEarned = 0;
  int _totalSpent = 0;
  List<Map<String, dynamic>> _records = const [];

  /// 积分 → 金币兑换（P1 经济闭环：服务端 rpc_pet_exchange 早已部署，
  /// 此前 App 无入口，用户只能攒积分换不到金币）
  final TextEditingController _goldCtrl = TextEditingController();
  int _availablePoints = 0;
  int _pointsPerGold = _kDefaultPointsPerGold;
  bool _exchanging = false;

  /// 流水来源中文映射（与 pet_wallet_records.source_type check 值域对齐）
  static const Map<String, String> _sourceLabels = {
    'pet_shop_buy': '商城消费',
    'pet_system_reward': '系统发放',
    'pet_adventure_penalty': '历险惩罚',
    'pet_achievement': '成就发放',
    'pet_exchange': '积分兑换',
    'pet_admin_grant': '客服调整',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goldCtrl.dispose();
    super.dispose();
  }

  /// 兑换成功后积分账本已由服务端改写（point_records + users 统计列），
  /// 广播 pointsUpdated 让积分页/我的页同步刷新（与游戏发奖同一套路）
  Future<void> _exchange() async {
    if (_exchanging) return;
    final gold = int.tryParse(_goldCtrl.text.trim()) ?? 0;
    if (gold <= 0) {
      _toast('请输入要兑换的金币数量');
      return;
    }
    final cost = gold * _pointsPerGold;
    if (cost > _availablePoints) {
      _toast('积分不足：需 $cost 积分，当前可用 $_availablePoints');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '积分兑换金币',
      content: '将消耗 $cost 积分，兑换 $gold 金币'
          '（1 金币 = $_pointsPerGold 积分）。兑换不可撤销。',
      confirmText: '确认兑换',
    );
    if (!confirmed || !mounted) return;

    setState(() => _exchanging = true);
    final err = await PetRpc.exchange(gold);
    if (!mounted) return;
    setState(() => _exchanging = false);
    if (err != null) {
      _toast(petRpcErrorText(err));
      return;
    }
    _goldCtrl.clear();
    EventBus.instance.fire(EventType.pointsUpdated);
    _toast('兑换成功：$gold 金币（-$cost 积分）');
    await _load(force: true);
  }

  void _toast(String msg) => showSnackBar(context, msg);

  Future<void> _load({bool force = false}) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
      return;
    }
    // 门控兜底：与三入口同一开关（直进本页的路径也受控）
    final enabled = await PetService.instance.isPetEnabled(forceRefresh: force);
    if (!enabled) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _loading = false;
        });
      }
      return;
    }

    try {
      final walletRes = await ApiClient.get(
        'pet_wallets',
        filters: {'user_id': 'eq.$userId'},
        select: 'gold_balance,total_earned,total_spent',
        limit: 1,
        note: 'pet_wallets 余额查询',
      );
      final recordsRes = await ApiClient.get(
        'pet_wallet_records',
        filters: {'user_id': 'eq.$userId'},
        select: 'delta,balance_after,source_type,remark,created_at',
        order: 'created_at.desc',
        limit: _kRecordLimit,
        note: 'pet_wallet_records 金币流水',
      );
      if (!walletRes.isSuccess || !recordsRes.isSuccess) {
        throw Exception(walletRes.errorMessage ?? recordsRes.errorMessage ?? '请求失败');
      }
      // 汇率与可用积分：任一失败都不阻塞钱包主内容（兑换按钮自会因积分为 0 而禁用）
      final configRes = await ApiClient.get(
        'pet_config',
        filters: {'id': 'eq.1'},
        select: 'points_per_gold',
        limit: 1,
        note: 'pet_config 积分兑金币汇率',
      );
      final configRows = configRes.data ?? const [];
      final pointsPerGold =
          (configRows.isNotEmpty
                  ? (configRows.first['points_per_gold'] as num?)
                  : null) ??
              _kDefaultPointsPerGold;
      final availablePoints =
          await PointService.instance.getAvailablePoints();
      final walletRows = walletRes.data ?? const [];
      final wallet = walletRows.isNotEmpty ? walletRows.first : null;
      if (!mounted) return;
      setState(() {
        _goldBalance = (wallet?['gold_balance'] as num?)?.toInt() ?? 0;
        _totalEarned = (wallet?['total_earned'] as num?)?.toInt() ?? 0;
        _totalSpent = (wallet?['total_spent'] as num?)?.toInt() ?? 0;
        _records = (recordsRes.data ?? const []).cast<Map<String, dynamic>>();
        _pointsPerGold = pointsPerGold.toInt();
        _availablePoints = availablePoints;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('金币钱包')),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) return const Center(child: LoadingWidget());
    if (!_enabled) {
      return const EmptyWidget(message: '宠物功能暂未开放');
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('数据加载失败，请稍后重试'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _loading = true);
                _load(force: true);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 余额卡
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '金币余额',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Icon(Icons.paid_outlined,
                          size: 28, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$_goldBalance',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _summaryItem('累计获得', _totalEarned, colorScheme),
                      _summaryItem('累计消费', _totalSpent, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 24),
                  _exchangeBlock(colorScheme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 流水列表
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('金币流水', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  if (_records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          '暂无金币流水',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    ..._records.map((r) => _recordTile(r, colorScheme)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          '仅展示最近 $_kRecordLimit 条',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 积分兑换金币区块（单向；服务端 rpc_pet_exchange 同事务双账本）
  Widget _exchangeBlock(ColorScheme colorScheme) {
    final gold = int.tryParse(_goldCtrl.text.trim()) ?? 0;
    final cost = gold > 0 ? gold * _pointsPerGold : 0;
    final canSubmit = !_exchanging && cost > 0 && cost <= _availablePoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.autorenew_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text('积分兑换金币', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(
              '可用积分 $_availablePoints',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _goldCtrl,
                keyboardType: TextInputType.number,
                enabled: !_exchanging,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '输入金币数',
                  suffixText: '金币',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: canSubmit ? _exchange : null,
              child: _exchanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('兑换${cost > 0 ? '（-$cost）' : ''}',
                      style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '1 金币 = $_pointsPerGold 积分；只支持积分 → 金币，金币不可换回积分。',
          style: TextStyle(
            fontSize: 12,
            color: cost > _availablePoints
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String label, int value, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _recordTile(
    Map<String, dynamic> r,
    ColorScheme colorScheme,
  ) {
    final delta = (r['delta'] as num?)?.toInt() ?? 0;
    final income = delta >= 0;
    final sourceType = r['source_type'] as String? ?? '';
    final remark = r['remark'] as String? ?? '';
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceLabels[sourceType] ?? (sourceType.isEmpty ? '其他' : sourceType),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (createdAt != null) DateTimeUtils.formatMonthDayTime(createdAt),
                    if (remark.isNotEmpty) remark,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                income ? '+$delta' : '$delta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: income ? colorScheme.primary : colorScheme.error,
                ),
              ),
              Text(
                '余额 ${(r['balance_after'] as num?)?.toInt() ?? 0}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
