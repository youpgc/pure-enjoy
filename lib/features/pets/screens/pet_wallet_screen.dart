import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/widgets.dart';
import '../../../services/api_client.dart';
import '../../../services/supabase_service.dart';
import '../services/pet_service.dart';

/// 金币钱包页（我的页「金币钱包」入口的独立落点，不进宠物主页）
///
/// 数据源（均本人 RLS 可读）：
/// - `pet_wallets`：余额行（gold_balance / total_earned / total_spent）；
///   行可能尚未创建（未发生过任何金币变动），按 0 兜底展示。
/// - `pet_wallet_records`：append-only 流水（delta / balance_after /
///   source_type / remark），倒序取最近 50 条。
class PetWalletScreen extends StatefulWidget {
  const PetWalletScreen({super.key});

  @override
  State<PetWalletScreen> createState() => _PetWalletScreenState();
}

class _PetWalletScreenState extends State<PetWalletScreen> {
  static const int _kRecordLimit = 50;

  bool _loading = true;
  bool _enabled = true;
  String? _error;

  int _goldBalance = 0;
  int _totalEarned = 0;
  int _totalSpent = 0;
  List<Map<String, dynamic>> _records = const [];

  /// 流水来源中文映射（与 pet_wallet_records.source_type check 值域对齐）
  static const Map<String, String> _sourceLabels = {
    'pet_shop_buy': '商城消费',
    'pet_system_reward': '系统发放',
    'pet_achievement': '成就发放',
    'pet_exchange': '积分兑换',
    'pet_admin_grant': '客服调整',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      final walletRows = walletRes.data ?? const [];
      final wallet = walletRows.isNotEmpty ? walletRows.first : null;
      if (!mounted) return;
      setState(() {
        _goldBalance = (wallet?['gold_balance'] as num?)?.toInt() ?? 0;
        _totalEarned = (wallet?['total_earned'] as num?)?.toInt() ?? 0;
        _totalSpent = (wallet?['total_spent'] as num?)?.toInt() ?? 0;
        _records = (recordsRes.data ?? const []).cast<Map<String, dynamic>>();
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

    final df = DateFormat('MM-dd HH:mm');
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
                    ..._records.map((r) => _recordTile(r, df, colorScheme)),
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
    DateFormat df,
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
                    if (createdAt != null) df.format(createdAt.toLocal()),
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
