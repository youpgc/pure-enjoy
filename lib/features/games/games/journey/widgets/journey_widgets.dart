import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'journey_theme.dart';

/// 西行·通用组件集（面板/按钮/货币栏/卡片/横幅/区块标题）。
///
/// 游戏内全部页面共用，保证画风一致；颜色/字号一律引用 JourneyTheme。

/// 深墨页面骨架：统一背景渐变 + 安全区
class JourneyPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const JourneyPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: JourneyTheme.pageDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: JourneyTheme.textPrimary,
          elevation: 0,
          title: Text(title, style: JourneyTheme.title),
          actions: actions,
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

/// 鎏金面板容器
class JourneyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const JourneyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: JourneyTheme.panelDecoration(color: color),
      child: child,
    );
  }
}

/// 区块标题（金色小竖条 + 文案）
class JourneySectionTitle extends StatelessWidget {
  final String text;

  const JourneySectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: JourneyTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: JourneyTheme.title),
        ],
      ),
    );
  }
}

/// 主按钮（鎏金）与次按钮（描边）
class JourneyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool secondary;
  final bool enabled;

  const JourneyButton({
    super.key,
    required this.text,
    required this.onTap,
    this.secondary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (secondary) {
      return _build(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(JourneyTheme.radiusButton),
          border: Border.all(color: JourneyTheme.panelStroke),
        ),
        textStyle: JourneyTheme.body,
      );
    }
    return _build(
      decoration: JourneyTheme.goldButton(),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3A2A12),
      ),
    );
  }

  Widget _build({
    required BoxDecoration decoration,
    required TextStyle textStyle,
  }) {
    final effective = enabled ? textStyle : textStyle.copyWith(
        color: JourneyTheme.textFaint);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(JourneyTheme.radiusButton),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: decoration,
          child: Text(text, style: effective),
        ),
      ),
    );
  }
}

/// 功德货币栏（金色小圆 + 余额）
class JourneyCurrencyBar extends StatelessWidget {
  final int merit;

  const JourneyCurrencyBar({super.key, required this.merit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: JourneyTheme.panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: JourneyTheme.goldDeep, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(
            'assets/games/journey/coin_merit.svg',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$merit',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: JourneyTheme.goldSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// 关卡/法宝/角色通用卡片骨架
class JourneyCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool locked;
  final Color? qualityColor;

  const JourneyCard({
    super.key,
    required this.child,
    this.onTap,
    this.locked = false,
    this.qualityColor,
  });

  @override
  Widget build(BuildContext context) {
    final stroke = locked
        ? JourneyTheme.locked
        : (qualityColor ?? JourneyTheme.panelStroke);
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JourneyTheme.panel,
              borderRadius: BorderRadius.circular(JourneyTheme.radiusCard),
              border: Border.all(color: stroke, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 横幅（关卡开场/妖王降临，进关后浮层用）
class JourneyBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;

  const JourneyBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.color = JourneyTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: JourneyTheme.bgDeep.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(JourneyTheme.radiusPanel),
        border: Border.all(color: color, width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: JourneyTheme.titleLg.copyWith(color: color),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle!, style: JourneyTheme.caption),
          ],
        ],
      ),
    );
  }
}
