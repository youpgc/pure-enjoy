import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/api_client.dart';
import '../../services/horoscope_service.dart';

/// 欢迎区块组件
///
/// 展示用户欢迎语、用户名，并在卡片内追加一行「今日星座运势」（按生日推算星座，
/// 调用免费公开接口获取，失败/无生日时静默不展示）。
class WelcomeSection extends StatelessWidget {
  const WelcomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  AuthService.instance.currentUserName ?? '用户',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '今天想做些什么？',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const HoroscopeLine(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 欢迎卡内的「今日星座运势」单行组件
///
/// 自包含：initState 时读取生日 → 推算星座 → 拉取运势，不污染 DashboardPage 聚合逻辑。
/// 加载中显示细进度条；无生日 / 获取失败 / 空文案时静默折叠（SizedBox.shrink），
/// 绝不抛异常或影响首页其它区块。
class HoroscopeLine extends StatefulWidget {
  const HoroscopeLine({super.key});

  @override
  State<HoroscopeLine> createState() => _HoroscopeLineState();
}

class _HoroscopeLineState extends State<HoroscopeLine> {
  String? _signName;
  String? _text;
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
      debugPrint('[星座运势] 未取到生日（users 表无 birthday 或查询失败），不展示');
    }

    final sign = zodiacSignFromBirthday(birthday);
    if (sign == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final text = await HoroscopeService.getDailyHoroscope(sign.name);
    if (mounted) {
      setState(() {
        _signName = sign.name;
        _text = text;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const SizedBox(
        height: 14,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    // 无生日 / 获取失败 / 空文案：静默不展示
    if (_signName == null || _text == null || _text!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // 取首句作为「一行」概要，过长再省略，保持欢迎卡内轻量展示
    final firstSentence = _text!.split(RegExp(r'(?<=[.!?])\s')).first;
    final summary =
        firstSentence.trim().isNotEmpty ? firstSentence.trim() : _text!;

    return Text(
      '今日 $_signName 运势：$summary',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
