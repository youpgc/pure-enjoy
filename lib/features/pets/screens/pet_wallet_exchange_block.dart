part of 'pet_wallet_screen.dart';

// ignore_for_file: unused_element, invalid_use_of_protected_member
// 注：part + extension 下分析器对跨文件隐式调用的私有成员引用计数有漏计（误报）。

extension _PetWalletExchangeViews on _PetWalletScreenState {
  Widget _exchangeBlock(ColorScheme colorScheme) {
    final gold = int.tryParse(_goldCtrl.text.trim()) ?? 0;
    final rate = _pointsPerGold;
    final cost = (gold > 0 && rate != null) ? gold * rate : 0;
    final canSubmit =
        !_exchanging && rate != null && cost > 0 && cost <= _availablePoints;
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
          rate == null
              ? '兑换汇率未加载，请下拉刷新；只支持积分 → 金币，金币不可换回积分。'
              : '1 金币 = $rate 积分；只支持积分 → 金币，金币不可换回积分。',
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
}
