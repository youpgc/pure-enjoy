import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../services/horoscope_service.dart';

/// 欢迎区块组件
///
/// 按条件渲染：
///   - 无生日 / 加载中：展示原欢迎卡（欢迎回来 + 用户名 + 今天想做些什么）；
///   - 有星座运势：展示完整星座运势卡片（替换原欢迎文案）。
class WelcomeSection extends StatefulWidget {
  const WelcomeSection({super.key});

  @override
  State<WelcomeSection> createState() => _WelcomeSectionState();
}

class _WelcomeSectionState extends State<WelcomeSection> {
  String? _signName;
  HoroscopeResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 生日存在 public.users 表，不在 Auth 用户对象里，必须从 users 表查询
    final userId = AuthService.instance.currentUserId;
    String? birthday;
    if (userId != null) {
      try {
        final result = await ApiClient.get(
          'users',
          filters: {
            ApiClient.userKey(userId): 'eq.$userId',
            'is_deleted': 'eq.false',
          },
          limit: 1,
        );
        if (result.isSuccess &&
            result.data != null &&
            result.data!.isNotEmpty) {
          birthday = result.data!.first['birthday'] as String?;
        }
      } catch (_) {
        // 查询失败：静默降级
      }
    }

    if (kDebugMode && birthday == null) {
      debugPrint('[星座运势] 未取到生日（users 表无 birthday 或查询失败），展示原欢迎卡');
    }

    final sign = zodiacSignFromBirthday(birthday);
    if (sign == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = await HoroscopeService.getDailyHoroscope(sign.name);
    if (mounted) {
      setState(() {
        _signName = sign.name;
        _result = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userName = AuthService.instance.currentUserName ?? '用户';

    // 有星座运势：展示完整运势卡片（替换原欢迎文案）
    if (!_loading && _signName != null && _result != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoroscopeCard(signName: _signName!, data: _result!),
          const SizedBox(height: 16),
        ],
      );
    }

    // 无星座运势 / 加载中：沿用原欢迎卡
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '欢迎回来',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  '今天想做些什么？',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 14,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 完整星座运势卡片
///
/// 头部：星座符号 + 「今日 {星座} 运势」标题；
/// 主体：当日运势文案（完整展示）；
/// 底部：幸运数字 / 幸运颜色胶囊。
class HoroscopeCard extends StatelessWidget {
  final String signName;
  final HoroscopeResult data;

  const HoroscopeCard({
    super.key,
    required this.signName,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = zodiacSymbol[signName] ?? '✨';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 24,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日 $signName 运势',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '每日星座指南',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _LuckyChip(
                  label: '幸运数字',
                  value: data.luckyNumber,
                  colorScheme: colorScheme,
                ),
                _LuckyChip(
                  label: '幸运颜色',
                  value: data.luckyColor,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 幸运信息胶囊（标签 + 加粗值）
class _LuckyChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _LuckyChip({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSecondaryContainer),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
