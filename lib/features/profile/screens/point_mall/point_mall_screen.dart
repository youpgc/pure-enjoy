import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/point_service.dart';

/// 积分商城页面
///
/// 当前仅上架「补签卡」一种道具：消耗 [PointService.makeupCardCost] 积分兑换 1 张，
/// 持有后可在积分页日历补签漏签日。结构设计为列表，后续可横向扩展其它道具。
class PointMallScreen extends StatefulWidget {
  const PointMallScreen({super.key});

  @override
  State<PointMallScreen> createState() => _PointMallScreenState();
}

class _PointMallScreenState extends State<PointMallScreen> {
  int _availablePoints = 0;
  int _makeupCardCount = 0;
  bool _isExchanging = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final points = await PointService.instance.getAvailablePoints();
    final count = await PointService.instance.getMakeupCardCount();
    if (mounted) {
      setState(() {
        _availablePoints = points;
        _makeupCardCount = count;
      });
    }
  }

  Future<void> _exchange() async {
    if (_isExchanging) return;
    if (_availablePoints < PointService.makeupCardCost) {
      showSnackBar(context, '积分不足，需 ${PointService.makeupCardCost} 积分');
      return;
    }
    setState(() => _isExchanging = true);
    final result = await PointService.instance.exchangeMakeupCard();
    if (mounted) {
      setState(() => _isExchanging = false);
      showSnackBar(context, result['message'] ?? '兑换完成');
      if (result['success'] == true) {
        final points = await PointService.instance.getAvailablePoints();
        final count = await PointService.instance.getMakeupCardCount();
        if (mounted) {
          setState(() {
            _availablePoints = points;
            _makeupCardCount = count;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const cost = PointService.makeupCardCost;
    final canExchange = _availablePoints >= cost && !_isExchanging;

    return Scaffold(
      appBar: AppBar(title: const Text('积分商城')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 可用积分概览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '可用积分',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_availablePoints',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 补签卡道具
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.event_repeat,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '补签卡',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '补回漏签的日期，维持连续签到天数',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '消耗 $cost 积分',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '持有 $_makeupCardCount 张',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canExchange ? _exchange : null,
                      child: _isExchanging
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _availablePoints < cost ? '积分不足' : '兑换',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '说明：补签仅填补漏签日期以维持连续天数，不额外发放积分。',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
