import 'package:flutter/material.dart';
import '../../../services/version_check_service.dart';
import '../../life/screens/life_screen.dart';
import '../../novel/screens/book_shelf_screen.dart';
import 'dashboard_page.dart';
import 'profile_page.dart';

/// 首页 - 主导航页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    LifeScreen(),
    BookShelfScreen(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 应用启动时检查更新
    _checkForUpdate();
  }

  /// 检查应用更新
  void _checkForUpdate() async {
    final versionInfo = await VersionCheckService.instance.checkUpdate();
    if (versionInfo != null && mounted) {
      VersionCheckService.instance.showUpdateDialog(context, versionInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '生活',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
