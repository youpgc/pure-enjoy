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
  HoroscopeDetail? _detail;
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
    final data = await HoroscopeService.getHoroscope(sign.name);
    if (mounted) {
      setState(() {
        _signName = sign.name;
        _detail = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userName = AuthService.instance.currentUserName ?? '用户';

    // 有星座运势：展示完整运势卡片（替换原欢迎文案）
    if (!_loading && _signName != null && _detail != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HoroscopeCard(signName: _signName!, data: _detail!),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 14,
                      child: LinearProgressIndicator(
                        // 弧度拉满：细胶囊，圆角给极大值让 Flutter 自动钳成半高→两端全圆
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(100),
                      ),
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
/// 底部：左右两栏——左「运势指数」(分项星级) / 右「今日幸运」(幸运信息)，各纵向展示。
class HoroscopeCard extends StatelessWidget {
  final String signName;
  final HoroscopeDetail data;

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
        padding: const EdgeInsets.all(16),
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
                        '${zodiacDateRange[signName] ?? ''} · 每日星座指南',
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
            const SizedBox(height: 12),
            if (!data.fromRemote)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '当前为内置解读（接口不可用）',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            Text(
              data.overview,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // 左右两栏：左=分项指数，右=今日幸运，各纵向展示
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '运势指数',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ..._horoscopeIndexOrder.map((k) {
                        return _RatingRow(
                          label: k,
                          starText: _horoscopeStarString(data, k),
                          colorScheme: colorScheme,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日幸运',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _LuckyRow(label: '幸运颜色', value: data.luckyColor, colorScheme: colorScheme),
                      _LuckyRow(label: '幸运数字', value: data.luckyNumber, colorScheme: colorScheme),
                      if (data.extraSign != null && data.extraSignLabel != null)
                        _LuckyRow(
                          label: data.extraSignLabel!,
                          value: data.extraSign!,
                          colorScheme: colorScheme,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分项运势星级一行（维度名左 + 星标右）
class _RatingRow extends StatelessWidget {
  final String label;
  final String starText;
  final ColorScheme colorScheme;

  const _RatingRow({
    required this.label,
    required this.starText,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            starText,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.tertiary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页运势卡各维度展示顺序（与详情页一致）
const List<String> _horoscopeIndexOrder = ['综合', '爱情', '事业', '财运', '健康'];

/// 将 [HoroscopeDetail.indices] 中某维度的值统一渲染为「★☆」星级文本
/// （远程为百分比，四舍五入按 20% 一星换算；内置回退已为星级文本，原样返回）。
String _horoscopeStarString(HoroscopeDetail d, String key) {
  final v = d.indices[key] ?? '';
  if (d.indicesArePercent) {
    final p = int.tryParse(v.replaceAll('%', '').trim()) ?? 0;
    final s = ((p + 9) ~/ 20).clamp(1, 5);
    return '${'★' * s}${'☆' * (5 - s)}';
  }
  return v;
}

/// 幸运信息一行（标签左 + 加粗值右）
class _LuckyRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _LuckyRow({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
