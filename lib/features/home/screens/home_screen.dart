import 'package:flutter/material.dart';
import '../../../services/version_check_service.dart';
import '../../games/hall/game_hall_page.dart';
import '../../life/screens/life/life_screen.dart';
import './dashboard/dashboard_page.dart';
import './profile/profile_page.dart';

/// 首页 - 主导航页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  /// 懒加载容器：默认只构建首页(索引0)，其余 tab 首次点击时才构建并常驻。
  /// 这样开屏仅触发当前展示页的请求，切到其它 tab 时才发起对应接口（按需加载）。
  final List<Widget> _pages = <Widget>[
    const DashboardPage(), // 首页为默认 landing，开屏即构建
    const SizedBox.shrink(),
    const SizedBox.shrink(),
    const SizedBox.shrink(),
  ];

  /// 按索引创建对应 tab 页（仅首次进入时调用，构造即触发该页 initState 发起请求）
  Widget _createPage(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const LifeScreen();
      case 2:
        return const GameHallPage();
      case 3:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

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

  /// tab 切换：未构建过的页首次进入才构建（按需加载），已构建的保留状态
  void _onDestinationSelected(int index) {
    if (_pages[index] is SizedBox) {
      _pages[index] = _createPage(index);
    }
    setState(() => _currentIndex = index);
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
        onDestinationSelected: _onDestinationSelected,
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
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: '游戏',
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
