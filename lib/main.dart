import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'services/dict_service.dart';
import 'services/notification_service.dart';

/// 全局 NavigatorKey，用于通知点击跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  runApp(const PureEnjoyApp());
}

class PureEnjoyApp extends StatefulWidget {
  const PureEnjoyApp({super.key});

  @override
  State<PureEnjoyApp> createState() => _PureEnjoyAppState();
}

class _PureEnjoyAppState extends State<PureEnjoyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 初始化认证服务（从本地存储恢复会话）
    await AuthService.instance.initialize();
    // 初始化字典服务（预加载字典数据）
    await DictService.instance.initialize();
    // 初始化通知服务
    await NotificationService.instance.initialize();

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // 初始化完成前显示闪屏
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppTheme.warmWhite,
        ),
        home: Scaffold(
          backgroundColor: AppTheme.warmWhite,
          body: Center(
            child: Image.asset(
              'assets/images/splash_icon.png',
              width: 120,
              height: 120,
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: '纯享',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeProvider.colorScheme.seedColor),
            darkTheme: AppTheme.darkTheme(themeProvider.colorScheme.seedColor),
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
            ],
            locale: const Locale('zh', 'CN'),
          );
        },
      ),
    );
  }
}

/// 认证状态包装器
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 检查是否已登录（AuthService.initialize() 已在 main() 中完成）
    if (AuthService.instance.isAuthenticated) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
