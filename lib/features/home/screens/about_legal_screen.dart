import 'package:flutter/material.dart';
import 'rich_text_page.dart';
import '../../life/screens/feedback_list_screen.dart';

/// 关于与法律
///
/// 从系统设置迁移而来的二级入口页：展示「关于纯享 / 隐私政策 / 用户协议 /
/// 帮助中心 / 问题反馈」菜单项，点击后跳转到各自的内容页。
/// 版本信息已在「我的」页独立展示，故不在此重复。
class AboutLegalScreen extends StatelessWidget {
  const AboutLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于与法律'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于纯享'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RichTextPage(
                    configKey: 'about',
                    title: '关于纯享',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RichTextPage(
                    configKey: 'privacy_policy',
                    title: '隐私政策',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RichTextPage(
                    configKey: 'user_agreement',
                    title: '用户协议',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('帮助中心'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RichTextPage(
                    configKey: 'help_center',
                    title: '帮助中心',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('问题反馈'),
            subtitle: const Text('提交问题与建议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FeedbackListScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
